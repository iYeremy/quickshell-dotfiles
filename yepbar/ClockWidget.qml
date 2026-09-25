// ClockWidget.qml - Center Module (Clock & Calendar Toggle - Waybar Style)
import QtQuick
import Quickshell

Rectangle {
  id: root

  implicitWidth: clockRow.implicitWidth + 24
  implicitHeight: Config.barHeight

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
  }

  // Waybar `.modules-center` background: rgba(20, 20, 20, 0.5)
  color: (clockMouse.containsMouse || (calendarPopup && calendarPopup.isOpen)) ? Config.glassHoverBg : Config.glassBg
  radius: Config.widgetRadius
  border.color: Config.borderColor
  border.width: 1

  Behavior on color { ColorAnimation { duration: 120 } }

  property var calendarPopup: null

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Row {
    id: clockRow
    anchors.centerIn: parent
    spacing: 8

    Text {
      text: Qt.formatDateTime(clock.date, "hh:mm AP")
      color: Config.textWhite
      font.pixelSize: clockMouse.containsMouse ? 13 : 12
      font.weight: Font.Bold
      font.family: Config.fontMono
      anchors.verticalCenter: parent.verticalCenter

      Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
    }
  }

  MouseArea {
    id: clockMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (root.calendarPopup) {
        root.calendarPopup.isOpen = !root.calendarPopup.isOpen
      }
    }
  }
}