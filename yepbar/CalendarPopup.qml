// CalendarPopup.qml - Interactive Calendar Overlay Window
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
  id: root

  property bool isOpen: false

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
    target: "calendar"

    function toggle() { root.isOpen = !root.isOpen }
    function open() { root.isOpen = true }
    function close() { root.isOpen = false }
  }

  // Today's real-time date
  readonly property date today: new Date()

  // Displayed month and year (interactive)
  property int displayYear: today.getFullYear()
  property int displayMonth: today.getMonth()

  onIsOpenChanged: {
    if (isOpen) {
      displayYear = today.getFullYear()
      displayMonth = today.getMonth()
      updateCalendarGrid()
    }
  }

  // Month Names
  readonly property var monthNames: [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ]

  // Calendar Days Grid Model
  ListModel {
    id: calendarModel
  }

  function updateCalendarGrid() {
    calendarModel.clear()

    let realYear = today.getFullYear()
    let realMonth = today.getMonth()
    let realDate = today.getDate()

    let firstDay = new Date(displayYear, displayMonth, 1).getDay()
    let daysInMonth = new Date(displayYear, displayMonth + 1, 0).getDate()
    let daysInPrevMonth = new Date(displayYear, displayMonth, 0).getDate()

    // 1. Previous month trailing days
    for (let i = firstDay - 1; i >= 0; i--) {
      let dayNum = daysInPrevMonth - i
      calendarModel.append({
        dayNumber: dayNum,
        inMonth: false,
        isToday: false
      })
    }

    // 2. Current month days
    for (let d = 1; d <= daysInMonth; d++) {
      let isToday = (displayYear === realYear && displayMonth === realMonth && d === realDate)
      calendarModel.append({
        dayNumber: d,
        inMonth: true,
        isToday: isToday
      })
    }

    // 3. Next month leading days
    let remaining = 42 - calendarModel.count
    for (let n = 1; n <= remaining; n++) {
      calendarModel.append({
        dayNumber: n,
        inMonth: false,
        isToday: false
      })
    }
  }


  function prevMonth() {
    if (displayMonth === 0) {
      displayMonth = 11
      displayYear--
    } else {
      displayMonth--
    }
    updateCalendarGrid()
  }

  function nextMonth() {
    if (displayMonth === 11) {
      displayMonth = 0
      displayYear++
    } else {
      displayMonth++
    }
    updateCalendarGrid()
  }

  // Floating Compact Container Box
  Rectangle {
    id: container
    width: Config.calendarWidth
    implicitHeight: columnLayout.implicitHeight + 28
    anchors.horizontalCenter: parent.horizontalCenter

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
      width: parent.width - 24
      anchors.top: parent.top
      anchors.topMargin: 14
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 12

      // Month & Year Selector Header
      Row {
        width: parent.width
        height: 28

        // Previous Month Button
        Rectangle {
          width: 28
          height: 28
          radius: 7
          color: prevMouse.containsMouse ? Config.selectedBg : "#00000000"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: Config.iconChevronLeft
            color: Config.textPrimary
            font.pixelSize: Config.fontSizeIconMedium
            font.family: Config.fontIcon
          }

          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.prevMonth()
          }
        }

        // Current Month Year Label
        Text {
          width: parent.width - 56
          text: root.monthNames[root.displayMonth] + " " + root.displayYear
          color: Config.textWhite
          font.pixelSize: Config.fontSizeLarge
          font.weight: Font.Bold
          font.family: Config.fontSans
          horizontalAlignment: Text.AlignHCenter
          anchors.verticalCenter: parent.verticalCenter
        }

        // Next Month Button
        Rectangle {
          width: 28
          height: 28
          radius: 7
          color: nextMouse.containsMouse ? Config.selectedBg : "#00000000"
          anchors.verticalCenter: parent.verticalCenter

          Text {
            anchors.centerIn: parent
            text: Config.iconChevronRight
            color: Config.textPrimary
            font.pixelSize: Config.fontSizeIconMedium
            font.family: Config.fontIcon
          }

          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.nextMonth()
          }
        }
      }

      // Days of Week Header Row
      Row {
        width: parent.width
        spacing: 0

        Repeater {
          model: ["S", "M", "T", "W", "T", "F", "S"]

          Item {
            width: (container.width - 24) / 7
            height: 22

            Text {
              anchors.centerIn: parent
              text: modelData
              color: Config.textMuted
              font.pixelSize: Config.fontSizeSmall
              font.weight: Font.Bold
              font.family: Config.fontSans
            }
          }
        }
      }

      // 7-Column Days Grid
      Grid {
        width: parent.width
        columns: 7
        spacing: 0

        Repeater {
          model: calendarModel

          Item {
            required property int dayNumber
            required property bool inMonth
            required property bool isToday

            width: (container.width - 24) / 7
            height: 30

            // Today Highlight Pill
            Rectangle {
              anchors.centerIn: parent
              width: 26
              height: 26
              radius: 8
              color: isToday ? Config.selectedBg : "#00000000"
              border.color: isToday ? Config.activeBorderColor : "#00000000"
              border.width: isToday ? 1 : 0
            }

            Text {
              anchors.centerIn: parent
              text: dayNumber.toString()
              color: isToday ? Config.textWhite : (inMonth ? Config.textSubtle : Config.textDark)
              font.pixelSize: Config.fontSizeNormal
              font.weight: isToday ? Font.Bold : Font.Normal
              font.family: Config.fontSans
            }
          }
        }
      }
    }
  }
}
