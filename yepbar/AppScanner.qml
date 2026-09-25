// AppScanner.qml - Desktop Entry Scanner Process Wrapper
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // Emitted when application discovery completes successfully
  signal appsDiscovered(var appsList)

  // Scanner process execution
  Process {
    id: scannerProcess
    command: ["python3", Qt.resolvedUrl("scripts/app_scanner.py").toString().replace("file://", "")]
    running: false

    stdout: SplitParser {
      onRead: data => {
        try {
          let list = JSON.parse(data)
          if (list && list.length > 0) {
            root.appsDiscovered(list)
          }
        } catch(e) {}
      }
    }
  }

  // Manually trigger rescan if needed
  function scan() {
    scannerProcess.running = false
    scannerProcess.running = true
  }
}
