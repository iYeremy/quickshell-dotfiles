// AppLauncher.qml - Detached Application Spawning Helper
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // Private launcher process handle
  Process {
    id: launcherProcess
  }

  // Unified API for launching applications with session detachment & I/O redirection
  function launch(execCmd, desktopId) {
    let cleanDesktopId = (desktopId || "").trim()
    let cleanCmd = (execCmd || "").trim()

    if (!cleanDesktopId && !cleanCmd) return

    launcherProcess.running = false

    // Prefer gtk-launch when desktopId is available; fallback to raw command
    if (cleanDesktopId) {
      launcherProcess.command = ["setsid", "-f", "sh", "-c", "gtk-launch " + cleanDesktopId + " >/dev/null 2>&1"]
    } else {
      launcherProcess.command = ["setsid", "-f", "sh", "-c", cleanCmd + " >/dev/null 2>&1"]
    }

    launcherProcess.running = true
  }
}
