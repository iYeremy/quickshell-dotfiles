// NotificationCenter.qml - Right-side Sliding Notification Center Overlay
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
  id: root

  property bool isOpen: false
  property int activeCount: 0
  property var rawNotifications: []

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

  // Backdrop: Click outside panel to close
  MouseArea {
    anchors.fill: parent
    onPressed: {
      root.isOpen = false
    }
  }

  // Background Python Notification Daemon Process
  Process {
    id: notifProc
    command: ["python3", Qt.resolvedUrl("scripts/notif_daemon.py").toString().replace("file://", "")]
    running: true

    stdout: SplitParser {
      onRead: data => {
        try {
          let res = JSON.parse(data)
          root.activeCount = res.count || 0
          root.rawNotifications = res.notifications || []
          root.updateGroupedModel()
        } catch (e) {
          console.log("Error parsing notification JSON: " + e)
        }
      }
    }
  }

  // Grouped Notifications List Model
  ListModel {
    id: groupModel
  }

  // Track expanded/collapsed state overrides by group app key
  property var collapsedOverrides: ({})

  function toggleGroupCollapsed(groupId) {
    let copy = Object.assign({}, collapsedOverrides)
    copy[groupId] = !copy[groupId]
    collapsedOverrides = copy
    updateGroupedModel()
  }

  function formatRelativeTime(ts) {
    let now = Math.floor(Date.now() / 1000)
    let diff = Math.max(0, now - ts)
    if (diff < 60) return "Just now"
    if (diff < 3600) return Math.floor(diff / 60) + "m ago"
    if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
    return Math.floor(diff / 86400) + "d ago"
  }

  function updateGroupedModel() {
    groupModel.clear()
    let list = root.rawNotifications
    if (!list || list.length === 0) return

    let now = Math.floor(Date.now() / 1000)
    let collapseThresholdSec = Config.notifGroupCollapseAgeHours * 3600
    let groups = []
    let currentGroup = null

    // Group consecutive notifications from the same app_name
    for (let i = 0; i < list.length; i++) {
      let item = list[i]
      let appName = item.app_name || "System"

      if (!currentGroup || currentGroup.appName !== appName) {
        if (currentGroup) groups.push(currentGroup)

        let groupId = appName + "_" + item.timestamp + "_" + i
        let ageSec = now - item.timestamp
        let isDefaultCollapsed = ageSec > collapseThresholdSec
        let override = collapsedOverrides[groupId]
        let collapsed = (typeof override !== "undefined") ? override : isDefaultCollapsed

        currentGroup = {
          groupId: groupId,
          appName: appName,
          latestTimestamp: item.timestamp,
          isCollapsed: collapsed,
          items: []
        }
      }
      currentGroup.items.push(item)
    }
    if (currentGroup) groups.push(currentGroup)

    // Populate Qt ListModel
    for (let g = 0; g < groups.length; g++) {
      let grp = groups[g]
      groupModel.append({
        groupId: grp.groupId,
        appName: grp.appName,
        latestTimestamp: grp.latestTimestamp,
        isCollapsed: grp.isCollapsed,
        itemCount: grp.items.length,
        items: grp.items
      })
    }
  }

  onIsOpenChanged: {
    if (isOpen) {
      notifProc.write(JSON.stringify({ action: "dismiss_mako" }) + "\n")
    }
  }

  function dismissNotification(id) {
    notifProc.write(JSON.stringify({ action: "dismiss", id: id }) + "\n")
  }

  function focusNotification(appName, id) {
    notifProc.write(JSON.stringify({ action: "focus", app_name: appName }) + "\n")
  }

  function clearAllNotifications() {
    notifProc.write(JSON.stringify({ action: "clear_all" }) + "\n")
  }

  // Sliding Container Box (Right Side Overlay Panel)
  Rectangle {
    id: container
    width: Config.notifCenterWidth
    height: parent.height - 64
    y: root.isOpen ? 8 : -16
    anchors.right: parent.right
    anchors.rightMargin: root.isOpen ? Config.barMargin : -width - 20

    opacity: root.isOpen ? 1.0 : 0.0

    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on anchors.rightMargin { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    color: Config.glassBg
    radius: Config.overlayRadius
    clip: true

    // Intercept clicks inside panel
    MouseArea {
      anchors.fill: parent
      onClicked: (mouse) => { mouse.accepted = true }
    }

    // Inner Translucent Border Ring
    Rectangle {
      anchors.fill: parent
      anchors.margins: Config.innerBorderMargin
      radius: Config.overlayRadius - 2
      color: "#00000000"
      border.color: Config.borderColor
      border.width: 1
    }

    Column {
      anchors.fill: parent
      anchors.margins: 14
      spacing: 12

      // Header Bar
      Item {
        width: parent.width
        height: 32

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          Text {
            text: Config.iconBell
            color: Config.textPrimary
            font.pixelSize: Config.fontSizeIconMedium
            font.family: Config.fontIcon
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: "Notifications"
            color: Config.textPrimary
            font.pixelSize: Config.fontSizeMedium
            font.weight: Font.Bold
            font.family: Config.fontSans
            anchors.verticalCenter: parent.verticalCenter
          }

          // Active Counter Badge
          Rectangle {
            visible: root.activeCount > 0
            height: 20
            width: Math.max(20, countText.implicitWidth + 10)
            radius: 10
            color: Config.selectedBg
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: countText
              anchors.centerIn: parent
              text: root.activeCount.toString()
              color: Config.textPrimary
              font.pixelSize: Config.fontSizeSmall
              font.weight: Font.Bold
              font.family: Config.fontMono
            }
          }
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 6

          // Clear All Button
          Rectangle {
            visible: root.activeCount > 0
            height: 26
            width: clearRow.implicitWidth + 12
            radius: Config.buttonRadius
            color: clearMouse.containsMouse ? Config.pressedBg : Config.hoverBg

            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
              id: clearRow
              anchors.centerIn: parent
              spacing: 4

              Text {
                text: Config.iconTrash
                color: Config.textMuted
                font.pixelSize: Config.fontSizeSmall
                font.family: Config.fontIcon
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "Clear"
                color: Config.textMuted
                font.pixelSize: Config.fontSizeSmall
                font.family: Config.fontSans
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: clearMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.clearAllNotifications()
            }
          }

          // Close Button
          Rectangle {
            height: 26
            width: 26
            radius: Config.buttonRadius
            color: closeMouse.containsMouse ? Config.pressedBg : "#00000000"

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent
              text: Config.iconClose
              color: Config.textMuted
              font.pixelSize: Config.fontSizeSmall
              font.family: Config.fontIcon
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.isOpen = false
            }
          }
        }
      }

      // Separator Line
      Rectangle {
        width: parent.width
        height: 1
        color: Config.separatorColor
      }

      // Empty State View
      Item {
        width: parent.width
        height: parent.height - 60
        visible: groupModel.count === 0

        Column {
          anchors.centerIn: parent
          spacing: 10

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Config.iconBell
            color: Config.textMuted
            opacity: 0.4
            font.pixelSize: 42
            font.family: Config.fontIcon
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No Notifications"
            color: Config.textMuted
            font.pixelSize: Config.fontSizeMedium
            font.weight: Font.Medium
            font.family: Config.fontSans
          }
        }
      }

      // Scrollable Notification Groups List
      Flickable {
        width: parent.width
        height: parent.height - 60
        visible: groupModel.count > 0
        contentHeight: groupColumn.implicitHeight
        clip: true

        Column {
          id: groupColumn
          width: parent.width
          spacing: 10

          Repeater {
            model: groupModel

            delegate: Rectangle {
              width: groupColumn.width
              implicitHeight: groupCardCol.implicitHeight + 16

              color: "#180f1823"
              radius: Config.cardRadius
              border.color: Config.borderColor
              border.width: 1

              Column {
                id: groupCardCol
                width: parent.width - 16
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                // Group Header Bar
                Rectangle {
                  width: parent.width
                  height: 28
                  color: headerMouse.containsMouse ? Config.hoverBg : "#00000000"
                  radius: Config.buttonRadius

                  Behavior on color { ColorAnimation { duration: 150 } }

                  Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                      text: model.appName
                      color: Config.textPrimary
                      font.pixelSize: Config.fontSizeNormal
                      font.weight: Font.Bold
                      font.family: Config.fontSans
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    // Count Badge if multiple notifications
                    Rectangle {
                      visible: model.itemCount > 1
                      height: 16
                      width: Math.max(16, grpBadgeText.implicitWidth + 8)
                      radius: 8
                      color: Config.selectedBg
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        id: grpBadgeText
                        anchors.centerIn: parent
                        text: model.itemCount.toString()
                        color: Config.textPrimary
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: Config.fontMono
                      }
                    }
                  }

                  Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                      text: root.formatRelativeTime(model.latestTimestamp)
                      color: Config.textMuted
                      font.pixelSize: Config.fontSizeSmall
                      font.family: Config.fontSans
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      text: model.isCollapsed ? Config.iconChevronRight : Config.iconChevronDown
                      color: Config.textMuted
                      font.pixelSize: Config.fontSizeSmall
                      font.family: Config.fontIcon
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  MouseArea {
                    id: headerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleGroupCollapsed(model.groupId)
                  }
                }

                // Expanded Group Notifications List
                Column {
                  width: parent.width
                  visible: !model.isCollapsed
                  spacing: 6

                  Repeater {
                    model: (typeof items !== "undefined" && items) ? items : []

                    delegate: Rectangle {
                      id: itemCard
                      width: parent.width
                      implicitHeight: itemCol.implicitHeight + 12
                      radius: Config.buttonRadius
                      color: itemMouse.containsMouse ? Config.hoverBg : "#00000000"

                      Behavior on color { ColorAnimation { duration: 150 } }

                      Column {
                        id: itemCol
                        width: parent.width - 12
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3

                        // Summary / Title
                        Text {
                          width: parent.width
                          text: modelData.summary || "Notification"
                          color: Config.textPrimary
                          font.pixelSize: Config.fontSizeNormal
                          font.weight: Font.DemiBold
                          font.family: Config.fontSans
                          elide: Text.ElideRight
                          maximumLineCount: 1
                        }

                        // Body Text
                        Text {
                          width: parent.width
                          visible: text.length > 0
                          text: modelData.body || ""
                          color: Config.textMuted
                          font.pixelSize: Config.fontSizeSmall
                          font.family: Config.fontSans
                          wrapMode: Text.Wrap
                          maximumLineCount: 3
                          elide: Text.ElideRight
                        }
                      }

                      MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: (mouse) => {
                          if (mouse.button === Qt.RightButton) {
                            // Right click: Remove from Center UI view
                            root.dismissNotification(modelData.id)
                          } else {
                            // Left click: Focus app and remove from Center UI view
                            root.focusNotification(modelData.app_name, modelData.id)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Subtle Bottom Footer Hint Bar
      Item {
        width: parent.width
        height: 18

        Text {
          anchors.centerIn: parent
          text: "Left-click: Focus app  •  Right-click: Dismiss"
          color: Config.textPlaceholder
          font.pixelSize: 11
          font.family: Config.fontSans
          opacity: 0.6
        }
      }
    }
  }
}
