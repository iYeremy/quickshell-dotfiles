#!/usr/bin/env python3
"""
notif_daemon.py - Asynchronous DBus Notification Recorder & History Manager for Quickshell
Captures system notifications, maintains JSON history with configurable retention (default 7 days),
and streams JSON state updates to stdout for Quickshell UI rendering.
"""

import os
import sys
import json
import time
import re
import signal
import subprocess
import threading

CACHE_DIR = os.path.expanduser("~/.cache/quickshell")
HISTORY_FILE = os.path.join(CACHE_DIR, "notification_history.json")
RETENTION_DAYS = 7  # Default retention in days

# Ensure cache directory exists
os.makedirs(CACHE_DIR, exist_ok=True)


def load_history():
    """Loads notification history from JSON file."""
    if os.path.exists(HISTORY_FILE):
        try:
            with open(HISTORY_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            sys.stderr.write(f"Error loading history: {e}\n")
    return []


def save_history(history):
    """Saves notification history to JSON file after applying retention cleanup."""
    now = time.time()
    cutoff = now - (RETENTION_DAYS * 86400)

    # Prune notifications older than retention cutoff (e.g. 7 days)
    pruned_history = [n for n in history if n.get("timestamp", 0) >= cutoff]

    try:
        tmp_file = HISTORY_FILE + ".tmp"
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(pruned_history, f, indent=2)
        os.replace(tmp_file, HISTORY_FILE)
    except Exception as e:
        sys.stderr.write(f"Error saving history: {e}\n")

    return pruned_history


def focus_app(app_name):
    """Attempts to focus an active Hyprland window matching app_name, or launches the app."""
    if not app_name:
        return

    app_clean = app_name.strip().lower()

    # 1. Check active Hyprland windows via hyprctl
    try:
        out = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
        clients = json.loads(out)
        for c in clients:
            c_class = (c.get("class") or "").lower()
            c_title = (c.get("title") or "").lower()
            if app_clean in c_class or app_clean in c_title:
                addr = c.get("address")
                if addr:
                    subprocess.run(
                        ["hyprctl", "dispatch", "focuswindow", f"address:{addr}"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    return
    except Exception:
        pass

    # 2. Fallback: Launch app detached using setsid -f
    try:
        subprocess.Popen(
            ["setsid", "-f", app_name.lower()],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as e:
        sys.stderr.write(f"Error focusing/launching app {app_name}: {e}\n")


class NotificationDaemon:
    def __init__(self):
        self.history = load_history()
        self.lock = threading.Lock()
        self.running = True

    def emit_state(self):
        """Outputs current notification state to stdout as a single JSON line."""
        with self.lock:
            active_items = [
                n for n in self.history if not n.get("dismissed_from_center", False)
            ]

            state = {
                "count": len(active_items),
                "total_history_count": len(self.history),
                "notifications": active_items,
            }

            try:
                print(json.dumps(state), flush=True)
            except Exception as e:
                sys.stderr.write(f"Error emitting state: {e}\n")

    def add_notification(self, app_name, summary, body, app_icon="", urgency=1):
        """Appends a new notification to history and emits state."""
        with self.lock:
            notif_id = f"{int(time.time()*1000)}_{len(self.history)+1}"
            entry = {
                "id": notif_id,
                "app_name": app_name or "System",
                "summary": summary or "",
                "body": body or "",
                "app_icon": app_icon or "",
                "urgency": urgency,
                "timestamp": int(time.time()),
                "dismissed_from_center": False,
            }
            self.history.append(entry)
            self.history = save_history(self.history)

        self.emit_state()

    def dismiss_notification(self, notif_id):
        """Marks a notification as dismissed from center view without deleting from history file."""
        with self.lock:
            modified = False
            for n in self.history:
                if n.get("id") == notif_id:
                    n["dismissed_from_center"] = True
                    modified = True
                    break
            if modified:
                self.history = save_history(self.history)

        self.emit_state()

    def clear_all(self):
        """Marks all active notifications as dismissed from center view."""
        with self.lock:
            for n in self.history:
                n["dismissed_from_center"] = True
            self.history = save_history(self.history)

        self.emit_state()

    def handle_stdin(self):
        """Listens for JSON action commands on standard input."""
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                action = data.get("action")
                if action == "dismiss":
                    notif_id = data.get("id")
                    if notif_id:
                        self.dismiss_notification(notif_id)
                elif action == "clear_all":
                    self.clear_all()
                elif action == "focus":
                    app_name = data.get("app_name")
                    if app_name:
                        focus_app(app_name)
                elif action == "dismiss_mako":
                    try:
                        subprocess.run(["makoctl", "dismiss", "-a"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    except Exception:
                        pass
            except Exception as e:
                sys.stderr.write(f"Error handling stdin command: {e}\n")

    def run_monitor(self):
        """Runs dbus-monitor in a subprocess and parses incoming Notify calls."""
        cmd = [
            "dbus-monitor",
            "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
        ]
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
            )
        except Exception as e:
            sys.stderr.write(f"Failed to start dbus-monitor: {e}\n")
            return

        lines = []
        in_notify = False

        for line in proc.stdout:
            if not self.running:
                break
            if "member=Notify" in line:
                in_notify = True
                lines = []
                continue

            if in_notify:
                lines.append(line)
                # Parse when we have captured full Notify call signature (7+ arguments)
                if len(lines) >= 8:
                    app_name, summary, body, icon = self.parse_notify_lines(lines)
                    if app_name or summary or body:
                        self.add_notification(app_name, summary, body, icon)
                    in_notify = False
                    lines = []

    def parse_notify_lines(self, lines):
        """Extracts app_name, summary, body, icon from dbus-monitor raw output lines."""
        strings = []
        for l in lines:
            match = re.search(r'string\s+"([^"]*)"', l)
            if match:
                strings.append(match.group(1))

        app_name = strings[0] if len(strings) > 0 else "System"
        icon = strings[1] if len(strings) > 1 else ""
        summary = strings[2] if len(strings) > 2 else ""
        body = strings[3] if len(strings) > 3 else ""

        # If summary was index 1 (when icon empty or skipped)
        if not summary and len(strings) >= 2:
            summary = strings[1]
        if not body and len(strings) >= 3:
            body = strings[2]

        return app_name, summary, body, icon


def main():
    daemon = NotificationDaemon()

    # Emit initial state on startup
    daemon.emit_state()

    # Start Stdin command handler thread
    stdin_thread = threading.Thread(target=daemon.handle_stdin, daemon=True)
    stdin_thread.start()

    # Run DBus monitor loop
    daemon.run_monitor()


if __name__ == "__main__":
    main()
