// WorkspaceWidget.qml - Left Module (Workspaces, CPU, RAM, Battery, Temp - Waybar Style)
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Rectangle {
  id: root

  implicitWidth: rowLayout.implicitWidth + 12
  implicitHeight: Config.barHeight

  Behavior on implicitWidth {
    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
  }

  // Waybar `.modules-left` background: rgba(20, 20, 20, 0.5)
  color: Config.glassBg
  radius: Config.widgetRadius
  border.color: Config.borderColor
  border.width: 1

  // Target AppDrawer reference to toggle
  property var appDrawer: null

  // System Stats
  property int sysCpuPercent: 0
  property int sysCpuTemp: 0
  property int sysRamPercent: 0
  property bool batExists: false
  property int batCapacity: 100
  property string batStatus: "Unknown"

  function getBatteryIcon() {
    if (batStatus === "Charging" || batStatus === "Full") return Config.iconBatCharging
    if (batCapacity >= 95) return Config.iconBat100
    if (batCapacity >= 85) return Config.iconBat90
    if (batCapacity >= 75) return Config.iconBat80
    if (batCapacity >= 65) return Config.iconBat70
    if (batCapacity >= 55) return Config.iconBat60
    if (batCapacity >= 45) return Config.iconBat50
    if (batCapacity >= 35) return Config.iconBat40
    if (batCapacity >= 25) return Config.iconBat30
    if (batCapacity >= 15) return Config.iconBat20
    return Config.iconBat10
  }

  // Network Stats
  property bool wifiConnected: false
  property bool ethConnected: false
  property bool netConnecting: false

  // Execute external Rust monitor binary
  Process {
    id: fetchSysProc
    command: [Qt.resolvedUrl("scripts/qs_monitor_bin").toString().replace("file://", "")]
    running: true

    stdout: SplitParser {
      onRead: data => {
        try {
          let res = JSON.parse(data)
          if (typeof res.cpu !== "undefined") root.sysCpuPercent = res.cpu
          if (typeof res.cpu_temp !== "undefined") root.sysCpuTemp = res.cpu_temp
          if (typeof res.ram_pct !== "undefined") root.sysRamPercent = res.ram_pct
          if (res.battery) {
            root.batExists = !!res.battery.exists
            root.batCapacity = res.battery.capacity || 0
            root.batStatus = res.battery.status || "Unknown"
          }
          if (res.network) {
            root.wifiConnected = !!res.network.wifi
            root.ethConnected = !!res.network.eth
            root.netConnecting = !!res.network.connecting
          }
        } catch(e) {}
      }
    }
  }

  Timer {
    interval: Config.sysCheckIntervalMs
    running: true
    repeat: true
    onTriggered: fetchSysProc.running = true
  }

  // Indicator style configuration for occupied workspaces
  property string indicatorStyle: Config.workspaceIndicatorStyle

  // Active workspace ID from Hyprland
  readonly property int activeWsId: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) ? Hyprland.focusedWorkspace.id : 1

  // Dynamic max workspace ID
  readonly property int maxWsId: {
    let maxId = Config.defaultMinWorkspaces
    if (activeWsId > maxId) maxId = activeWsId
    if (Hyprland.workspaces && Hyprland.workspaces.values) {
      let list = Hyprland.workspaces.values
      for (let i = 0; i < list.length; i++) {
        if (list[i] && list[i].id > maxId) maxId = list[i].id
      }
    }
    return maxId
  }

  readonly property var workspaceList: {
    let arr = []
    for (let i = 1; i <= maxWsId; i++) arr.push(i)
    return arr
  }

  readonly property var occupiedWsMap: {
    let map = {}
    if (Hyprland.workspaces && Hyprland.workspaces.values) {
      let list = Hyprland.workspaces.values
      for (let i = 0; i < list.length; i++) {
        if (list[i]) {
          let hasWindows = list[i].toplevels ? list[i].toplevels.values.length > 0 : true
          if (hasWindows) map[list[i].id] = true
        }
      }
    }
    return map
  }

  function isWorkspaceOccupied(wsId) {
    return !!occupiedWsMap[wsId]
  }

  function switchToWorkspace(wsId) {
    if (typeof Hyprland !== "undefined" && Hyprland.dispatch) {
      Hyprland.dispatch("workspace " + wsId)
    }
  }

  Row {
    id: rowLayout
    anchors.centerIn: parent
    spacing: 6

    // Workspaces List
    Repeater {
      model: root.workspaceList

      Rectangle {
        id: itemRect
        required property int modelData
        required property int index

        width: 18
        height: Config.buttonHeight
        radius: Config.buttonRadius

        readonly property bool isActive: root.activeWsId === modelData
        readonly property bool isOccupied: root.isWorkspaceOccupied(modelData)
        readonly property bool isHovered: mouseArea.containsMouse

        color: isActive ? Config.selectedBg : (isHovered ? Config.hoverBg : "#00000000")

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text: modelData.toString()
          color: itemRect.isActive ? Config.textWhite : (itemRect.isOccupied ? Config.textPrimary : Config.textPlaceholder)
          font.pixelSize: itemRect.isHovered ? 11 : Config.fontSizeNormal
          font.weight: itemRect.isActive ? Font.Bold : (itemRect.isOccupied ? Font.Medium : Font.Normal)
          font.family: Config.fontMono

          Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.switchToWorkspace(modelData)
        }
      }
    }

    // Separator line
    Rectangle {
      width: 1
      height: 10
      color: Config.separatorColor
      anchors.verticalCenter: parent.verticalCenter
    }

    // CPU Module (Exact Waybar "CPU {usage}%")
    Rectangle {
      height: Config.buttonHeight
      implicitWidth: cpuRow.implicitWidth + 6
      radius: Config.buttonRadius
      color: cpuMouse.containsMouse ? Config.hoverBg : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }

      Row {
        id: cpuRow
        anchors.centerIn: parent
        spacing: 3

        Text {
          text: "CPU " + root.sysCpuPercent + "%"
          color: root.sysCpuPercent > 85 ? Config.dangerRed : (root.sysCpuPercent > 70 ? Config.warningAmber : Config.textPrimary)
          font.pixelSize: cpuMouse.containsMouse ? 11 : Config.fontSizeNormal
          font.weight: Font.Medium
          font.family: Config.fontMono
          anchors.verticalCenter: parent.verticalCenter

          Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
        }
      }

      MouseArea {
        id: cpuMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
      }
    }

    // RAM Module (Exact Waybar "RAM {percentage}%")
    Rectangle {
      height: Config.buttonHeight
      implicitWidth: ramRow.implicitWidth + 6
      radius: Config.buttonRadius
      color: ramMouse.containsMouse ? Config.hoverBg : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }

      Row {
        id: ramRow
        anchors.centerIn: parent
        spacing: 3

        Text {
          text: "RAM " + root.sysRamPercent + "%"
          color: root.sysRamPercent > 85 ? Config.dangerRed : (root.sysRamPercent > 70 ? Config.warningAmber : Config.textPrimary)
          font.pixelSize: ramMouse.containsMouse ? 11 : Config.fontSizeNormal
          font.weight: Font.Medium
          font.family: Config.fontMono
          anchors.verticalCenter: parent.verticalCenter

          Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
        }
      }

      MouseArea {
        id: ramMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
      }
    }

    // Battery Module (Exact Waybar "{icon} {capacity}%")
    Rectangle {
      height: Config.buttonHeight
      implicitWidth: batRow.implicitWidth + 6
      radius: Config.buttonRadius
      visible: root.batExists
      color: batMouse.containsMouse ? Config.hoverBg : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }

      Row {
        id: batRow
        anchors.centerIn: parent
        spacing: 4

        Text {
          text: root.getBatteryIcon()
          color: root.batStatus === "Charging" ? Config.accentGreen : (root.batCapacity <= 15 ? Config.dangerRed : (root.batCapacity <= 30 ? Config.warningAmber : Config.textPrimary))
          font.pixelSize: Config.fontSizeIconSmall
          font.family: Config.fontIcon
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.batCapacity + "%"
          color: root.batStatus === "Charging" ? Config.accentGreen : (root.batCapacity <= 15 ? Config.dangerRed : (root.batCapacity <= 30 ? Config.warningAmber : Config.textPrimary))
          font.pixelSize: batMouse.containsMouse ? 11 : Config.fontSizeNormal
          font.weight: Font.Medium
          font.family: Config.fontMono
          anchors.verticalCenter: parent.verticalCenter

          Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
        }
      }

      MouseArea {
        id: batMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
      }
    }

    // Temperature Module (Exact Waybar "{temperatureC}°C")
    Rectangle {
      height: Config.buttonHeight
      implicitWidth: tempRow.implicitWidth + 6
      radius: Config.buttonRadius
      visible: root.sysCpuTemp > 0
      color: tempMouse.containsMouse ? Config.hoverBg : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }

      Row {
        id: tempRow
        anchors.centerIn: parent
        spacing: 3

        Text {
          text: root.sysCpuTemp + "°C"
          color: root.sysCpuTemp >= 80 ? Config.dangerRed : Config.textPrimary
          font.pixelSize: tempMouse.containsMouse ? 11 : Config.fontSizeNormal
          font.weight: Font.Medium
          font.family: Config.fontMono
          anchors.verticalCenter: parent.verticalCenter

          Behavior on font.pixelSize { NumberAnimation { duration: 100 } }
        }
      }

      MouseArea {
        id: tempMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
      }
    }
  }
}
