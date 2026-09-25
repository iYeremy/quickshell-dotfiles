// BrightnessPopup.qml - Display Brightness Control Overlay
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
  id: root

  property bool isOpen: false
  property int brightnessPercent: 100

  visible: isOpen

  // Wayland LayerShell Configuration
  WlrLayershell.namespace: "quickshell-bar"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusiveZone: 0
  WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  color: "#00000000"

  // Background dismiss handler
  MouseArea {
    anchors.fill: parent
    onPressed: {
      root.isOpen = false
    }
  }

  // IPC Handler
  IpcHandler {
    target: "brightness"

    function toggle() { root.isOpen = !root.isOpen }
    function open() { root.isOpen = true }
    function close() { root.isOpen = false }
    function set(val: string) {
      let v = Math.max(0, Math.min(100, parseInt(val) || 0))
      root.applyBrightness(v)
    }
  }

  // Fetch initial brightness via brightnessctl
  Process {
    id: fetchBrightnessProc
    command: ["sh", "-c", "brightnessctl -i | grep -oP '\\(\\K[0-9]+(?=%\\)' || echo 100"]
    running: false

    stdout: SplitParser {
      onRead: data => {
        let val = parseInt(data.trim())
        if (!isNaN(val)) {
          root.brightnessPercent = val
        }
      }
    }
  }

  // Set brightness via brightnessctl process
  Process {
    id: setBrightnessProc
  }

  function applyBrightness(val) {
    let target = Math.max(0, Math.min(100, Math.round(val)))
    root.brightnessPercent = target
    setBrightnessProc.running = false
    setBrightnessProc.command = ["brightnessctl", "s", target + "%"]
    setBrightnessProc.running = true
  }

  onIsOpenChanged: {
    if (isOpen) {
      fetchBrightnessProc.running = true
    }
  }

  // Floating Container Box
  Rectangle {
    id: container
    width: Config.brightnessWidth
    implicitHeight: columnLayout.implicitHeight + 28
    anchors.right: parent.right
    anchors.rightMargin: 16

    y: root.isOpen ? 8 : -16
    opacity: root.isOpen ? 1.0 : 0.0

    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    color: Config.glassBg
    radius: Config.overlayRadius

    MouseArea {
      anchors.fill: parent
      onClicked: (mouse) => { mouse.accepted = true }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: Config.innerBorderMargin
      radius: Config.overlayRadius - 2
      color: "#00000000"
      border.color: Config.borderColor
      border.width: 1
    }

    Column {
      id: columnLayout
      width: parent.width - 32
      anchors.top: parent.top
      anchors.topMargin: 14
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 14

      // Header Bar (Left: Icon & Title, Right: Percentage)
      Item {
        width: parent.width
        height: 24

        Row {
          spacing: 8
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter

          Text {
            text: root.brightnessPercent >= 75 ? Config.iconBrightHigh : (root.brightnessPercent >= 35 ? Config.iconBrightMedium : (root.brightnessPercent > 0 ? Config.iconBrightLow : Config.iconBrightOff))
            color: Config.textPrimary
            font.pixelSize: Config.fontSizeTitle
            font.family: Config.fontIcon
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: "Display Brightness"
            color: Config.textWhite
            font.pixelSize: Config.fontSizeLarge
            font.weight: Font.Bold
            font.family: Config.fontSans
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.brightnessPercent + "%"
          color: Config.textMuted
          font.pixelSize: Config.fontSizeMedium
          font.weight: Font.Bold
          font.family: Config.fontMono
        }
      }

      // Slider Control Container
      Item {
        id: sliderBox
        width: parent.width
        height: 24

        Rectangle {
          id: track
          width: parent.width
          height: 6
          radius: 3
          color: Config.searchBg
          border.color: "#40464646"
          border.width: 1
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            height: parent.height
            radius: 3
            width: Math.min(parent.width, Math.max(0, parent.width * (sliderArea.tempValue / 100.0)))
            color: Config.textPrimary
          }
        }

        MouseArea {
          id: sliderArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          property int tempValue: root.brightnessPercent

          Connections {
            target: root
            function onBrightnessPercentChanged() {
              if (!sliderArea.pressed) {
                sliderArea.tempValue = root.brightnessPercent
              }
            }
          }

          function updateTemp(mouse) {
            let posX = Math.max(0, Math.min(width, mouse.x))
            let pct = Math.round((posX / width) * 100)
            tempValue = pct
            root.brightnessPercent = pct
          }

          onPressed: (mouse) => {
            updateTemp(mouse)
          }

          onPositionChanged: (mouse) => {
            if (pressed) {
              updateTemp(mouse)
            }
          }

          onReleased: (mouse) => {
            updateTemp(mouse)
            root.applyBrightness(tempValue)
          }
        }
      }

      // Quick Preset Pills Row (25%, 50%, 75%, 100%)
      Row {
        width: parent.width
        spacing: 8

        Repeater {
          model: [25, 50, 75, 100]

          Rectangle {
            id: presetBtn
            required property int modelData
            width: (columnLayout.width - 24) / 4
            height: 26
            radius: 7
            readonly property bool isSelected: root.brightnessPercent === modelData
            color: isSelected ? Config.selectedBg : (presetMouse.containsMouse ? Config.hoverBg : "#150f1823")
            border.color: isSelected ? Config.activeBorderColor : "#30464646"
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: presetBtn.modelData + "%"
              color: presetBtn.isSelected ? Config.textWhite : Config.textSubtle
              font.pixelSize: Config.fontSizeSmall
              font.weight: presetBtn.isSelected ? Font.Bold : Font.Medium
              font.family: Config.fontMono
            }

            MouseArea {
              id: presetMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.applyBrightness(presetBtn.modelData)
              }
            }
          }
        }
      }
    }
  }
}
