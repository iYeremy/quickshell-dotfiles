#!/usr/bin/env python3
"""
app_scanner.py - Desktop Application Entry Scanner for Quickshell
Scans XDG application directories and generates a sorted JSON list of desktop applications.
"""

import os
import configparser
import json
import re

def scan_desktop_applications():
    """Scans system and user desktop entries and extracts application metadata."""
    apps = []
    search_dirs = [
        '/usr/share/applications',
        os.path.expanduser('~/.local/share/applications')
    ]
    seen_names = set()

    for app_dir in search_dirs:
        if not os.path.exists(app_dir):
            continue

        for filename in os.listdir(app_dir):
            if not filename.endswith('.desktop'):
                continue

            filepath = os.path.join(app_dir, filename)
            config = configparser.ConfigParser(interpolation=None, strict=False)

            try:
                config.read(filepath, encoding='utf-8')
                if 'Desktop Entry' not in config:
                    continue

                entry = config['Desktop Entry']

                # Filter out hidden or non-application desktop entries
                if entry.get('NoDisplay', 'false').lower() == 'true':
                    continue
                if entry.get('Type', 'Application') != 'Application':
                    continue

                name = entry.get('Name', '').strip()
                exec_cmd = entry.get('Exec', '').strip()
                icon = entry.get('Icon', '').strip()

                if name and exec_cmd and name not in seen_names:
                    seen_names.add(name)

                    # Clean standard desktop field codes (%f, %F, %u, %U, %i, %c, %k)
                    clean_exec = re.sub(r'%[fFuUiIcCkKvm%]', '', exec_cmd).strip()
                    clean_exec = re.sub(r'\s+', ' ', clean_exec)

                    apps.append({
                        'name': name,
                        'icon': icon,
                        'execCmd': clean_exec,
                        'desktopId': filename
                    })
            except Exception:
                pass

    apps.sort(key=lambda x: x['name'].lower())
    return apps

def main():
    print(json.dumps(scan_desktop_applications()))

if __name__ == '__main__':
    main()
