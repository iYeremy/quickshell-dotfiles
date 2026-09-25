// StatusWidget.qml - Right Module (MPRIS Marquee, Pulseaudio, Brightness, Network, Power - Waybar Style)
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
  id: root

  implicitWidth: rowLayout.implicitWidth + 20
  implicitHeight: Config.barHeight

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
  }

  // Waybar `.modules-right` background: rgba(20, 20, 20, 0.5)
  color: Config.glassBg
  radius: Config.widgetRadius
  border.color: Config.borderColor
  border.width: 1

  property var brightnessPopup: null
  property var notificationCenter: null
  readonly property int brightnessPercent: brightnessPopup ? brightnessPopup.brightnessPercent : 100

  // Audio state properties
  property int volumePercent: 0
  property bool isMuted: false
  property bool initialized: false

  // Network connection states
  property bool wifiConnected: false
  property bool ethConnected: false
  property bool netConnecting: false

  // Media Player State Properties
  property bool hasMedia: false
  property bool isPlaying: false
  property string mediaArtist: ""
  property string mediaTitle: ""

  readonly property string trackLabel: {
    if (mediaArtist && mediaTitle) return mediaArtist + " - " + mediaTitle
    if (mediaTitle) return mediaTitle
    if (mediaArtist) return mediaArtist
    return ""
  }

  // Real-time MPRIS metadata subscriber via playerctl
  Process {
    id: mprisProc
    command: ["playerctl", "metadata", "-F", "--format", "{{status}};;{{artist}};;{{title}}"]
    running: true

    stdout: SplitParser {
      onRead: data => {
        let parts = data.trim().split(";;")
        if (parts.length >= 3) {
          let statusStr = parts[0]
          root.isPlaying = (statusStr === "Playing")
          root.hasMedia = (statusStr === "Playing" || statusStr === "Paused")
          root.mediaArtist = parts[1]
          root.mediaTitle = parts[2]
        } else {
          root.hasMedia = false
          root.isPlaying = false
        }
      }
    }
  }

  Process { id: playPauseProc; command: ["playerctl", "play-pause"] }
  Process { id: prevTrackProc; command: ["playerctl", "previous"] }
  Process { id: nextTrackProc; command: ["playerctl", "next"] }

  // Audio Volume subprocesses
  Process {
    id: pactlSub
    command: ["pactl", "subscribe"]
    running: true

    stdout: SplitParser {
      onRead: data => {
        if (data.includes("sink")) fetchVolProc.running = true
      }
    }
  }

  Process {
    id: fetchVolProc
    command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
    running: true

    stdout: SplitParser {
      onRead: data => {
        let isMuted = data.includes("[MUTED]")
        let matches = data.match(/Volume:\s+([0-9.]+)/)
        if (matches && matches[1]) {
          root.isMuted = isMuted
          root.volumePercent = Math.round(parseFloat(matches[1]) * 100)
          root.initialized = true
        }
      }
    }
  }

  Process { id: volumeProc; command: ["setsid", "-f", Config.cmdVolumeControl] }
  Process { id: bluetoothProc; command: ["setsid", "-f", Config.cmdBluetoothControl] }
  Process { id: networkProc; command: ["setsid", "-f", Config.cmdNetworkControl] }
  Process { id: powerProc; command: ["sh", "-c", Config.cmdPowerMenu] }
  Process { id: toggleMuteProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
  Process { id: volUpProc; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"] }
  Process { id: volDownProc; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] }

  Row {
    id: rowLayout
    anchors.centerIn: parent
    spacing: 8

    // MPRIS Marquee Module (Exact Waybar custom/mpris-marquee)
    Rectangle {
      id: mprisContainer
      height: Config.buttonHeight
      implicitWidth: mprisRow.implicitWidth + 8
      radius: Config.buttonRadius
      visible: root.hasMedia && root.trackLabel.length > 0
      color: mprisMouse.containsMouse ? Config.hoverBg : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }

      Row {
        id: mprisRow
        anchors.centerIn: parent
        spacing: 6

        Text {
          text: root.isPlaying ? Config.iconPause : Config.iconPlay
          color: Config.textWhite
          font.pixelSize: Config.fontSizeIconSmall
          font.family: Config.fontIcon
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.trackLabel
          color: Config.textPrimary
          font.pixelSize: mprisMouse.containsMouse ? 12 : Config.fontSizeNormal
          font.weight: Font.Medium
          font.family: Config.fontMono
          elide: Text.ElideRight
          maximumLineCount: 1
          anchors.verticalCenter: parent.verticalCenter

          Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
        }
      }

      MouseArea {
        id: mprisMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: playPauseProc.running = true
        onWheel: (wheel) => {
          if (wheel.angleDelta.y > 0) nextTrackProc.running = true
          else prevTrackProc.running = true
        }
      }
    }

    // Separator line
    Rectangle {
      width: 1
      height: 14
      color: Config.separatorColor
      visible: root.hasMedia && root.trackLabel.length > 0
      anchors.verticalCenter: parent.verticalCenter
    }

    // Pulseaudio Volume Module (Exact Waybar "{icon}  {volume}%")
    Rectangle {
      id: volContainer
      height: Config.buttonHeight
      implicitWidth: volRow.implicitWidth + 8
      radius: Config.buttonRadius
      color: volMouse.containsMouse ? Config.hoverBg : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }

      Row {
        id: volRow
        anchors.centerIn: parent
        spacing: 5

        Text {
          text: root.isMuted ? Config.iconVolMuted : (root.volumePercent >= 70 ? Config.iconVolHigh : (root.volumePercent >= 30 ? Config.iconVolMedium : Config.iconVolLow))
          color: root.isMuted ? Config.dangerRed : Config.textPrimary
          font.pixelSize: Config.fontSizeIconMedium
          font.family: Config.fontIcon
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.isMuted ? "Muted" : (root.volumePercent + "%")
          color: root.isMuted ? Config.dangerRed : Config.textPrimary
          font.pixelSize: volMouse.containsMouse ? 12 : Config.fontSizeNormal
          font.weight: Font.Medium
          font.family: Config.fontMono
          anchors.verticalCenter: parent.verticalCenter

          Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
        }
      }

      MouseArea {
        id: volMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) toggleMuteProc.running = true
          else volumeProc.running = true
        }
        onWheel: (wheel) => {
          if (wheel.angleDelta.y > 0) volUpProc.running = true
          else volDownProc.running = true
        }
      }
    }

    // Brightness Control Button
    Rectangle {
      width: Config.buttonWidth
      height: Config.buttonHeight
      radius: Config.buttonRadius
      readonly property bool isBrightnessActive: (root.brightnessPopup && root.brightnessPopup.isOpen)
      color: (isBrightnessActive || brightHover.hovered) ? Config.activeHoverBg : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }
      HoverHandler { id: brightHover }

      Text {
        anchors.centerIn: parent
        text: root.brightnessPercent >= 75 ? Config.iconBrightHigh : (root.brightnessPercent >= 35 ? Config.iconBrightMedium : (root.brightnessPercent > 0 ? Config.iconBrightLow : Config.iconBrightOff))
        color: (parent.isBrightnessActive || brightHover.hovered) ? Config.textWhite : Config.textPrimary
        font.pixelSize: brightHover.hovered ? 14 : Config.fontSizeIconMedium
        font.family: Config.fontIcon

        Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.brightnessPopup) root.brightnessPopup.isOpen = !root.brightnessPopup.isOpen
        }
      }
    }

    // Network / Wifi Status Icon
    Rectangle {
      width: Config.buttonWidth
      height: Config.buttonHeight
      radius: Config.buttonRadius
      color: wifiMouse.containsMouse ? Config.hoverBg : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }

      Text {
        anchors.centerIn: parent
        text: root.ethConnected ? Config.iconEthernet : (root.wifiConnected ? Config.iconWifiConnected : Config.iconWifiDisconnected)
        color: (!root.wifiConnected && !root.ethConnected) ? Config.dangerRed : Config.textPrimary
        font.pixelSize: wifiMouse.containsMouse ? 14 : Config.fontSizeIconMedium
        font.family: Config.fontIcon

        Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
      }

      MouseArea {
        id: wifiMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: networkProc.running = true
      }
    }

    // Notification Bell Button
    Rectangle {
      width: Config.buttonWidth
      height: Config.buttonHeight
      radius: Config.buttonRadius
      readonly property bool isNotifActive: (root.notificationCenter && root.notificationCenter.isOpen)
      readonly property int unreadCount: root.notificationCenter ? root.notificationCenter.activeCount : 0
      color: (isNotifActive || notifHover.hovered) ? Config.activeHoverBg : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }
      HoverHandler { id: notifHover }

      Text {
        anchors.centerIn: parent
        text: parent.unreadCount > 0 ? Config.iconBellDot : Config.iconBell
        color: (parent.isNotifActive || notifHover.hovered) ? Config.textWhite : Config.textPrimary
        font.pixelSize: notifHover.hovered ? 14 : Config.fontSizeIconMedium
        font.family: Config.fontIcon

        Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.notificationCenter) root.notificationCenter.isOpen = !root.notificationCenter.isOpen
        }
      }
    }

    // Power Button Icon
    Rectangle {
      width: Config.buttonWidth
      height: Config.buttonHeight
      radius: Config.buttonRadius
      color: pwrMouse.containsMouse ? "#45f87171" : "#00000000"

      Behavior on color { ColorAnimation { duration: 120 } }

      Text {
        anchors.centerIn: parent
        text: Config.iconPower
        color: pwrMouse.containsMouse ? Config.dangerRed : Config.textPrimary
        font.pixelSize: pwrMouse.containsMouse ? 14 : Config.fontSizeIconMedium
        font.family: Config.fontIcon

        Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
      }

      MouseArea {
        id: pwrMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: powerProc.running = true
      }
    }
  }
}
