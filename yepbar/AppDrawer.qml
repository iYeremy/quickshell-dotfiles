// AppDrawer.qml - Application Launcher Overlay Window
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
  id: root

  // Window State
  property bool isOpen: false

  // UI Design Constants
  readonly property int containerWidth: Config.appDrawerWidth
  readonly property int containerHeight: Config.appDrawerHeight
  readonly property int containerRadius: Config.overlayRadius
  readonly property int innerBorderRadius: Config.overlayRadius - 2

  // Color Palette Tokens
  readonly property color glassBgColor: Config.glassBg
  readonly property color searchBgColor: Config.searchBg
  readonly property color borderColor: Config.borderColor
  readonly property color activeBorderColor: Config.activeBorderColor
  readonly property color highlightColor: Config.selectedBg
  readonly property color textPrimaryColor: Config.textPrimary
  readonly property color textMutedColor: Config.textMuted
  readonly property color textPlaceholderColor: Config.textPlaceholder

  // IPC Interface
  IpcHandler {
    target: "drawer"

    function toggle() { root.isOpen = !root.isOpen }
    function open() { root.isOpen = true }
    function close() { root.isOpen = false }
  }

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

  // Backdrop: Dismiss when clicking outside container
  MouseArea {
    anchors.fill: parent
    onPressed: root.isOpen = false
  }

  property bool hasScanned: false

  // Reset search input, trigger scanner, and focus on opening
  onIsOpenChanged: {
    if (isOpen) {
      if (!hasScanned) {
        hasScanned = true
        appScanner.scan()
      }
      searchInput.text = ""
      searchInput.forceActiveFocus()
      root.filterModel()
    }
  }

  // Services & Models
  AppLauncher {
    id: appLauncher
  }

  AppScanner {
    id: appScanner
    onAppsDiscovered: appsList => populateModel(appsList)
  }

  // Master model holding all discovered applications
  ListModel {
    id: fullAppModel

    // Default fallback items while scanner populates
    ListElement { name: "Terminal"; icon: "kitty"; execCmd: "kitty"; desktopId: "kitty.desktop" }
    ListElement { name: "Files"; icon: "org.kde.dolphin"; execCmd: "dolphin"; desktopId: "org.kde.dolphin.desktop" }
    ListElement { name: "Firefox"; icon: "firefox"; execCmd: "firefox"; desktopId: "firefox.desktop" }
    ListElement { name: "Spotify"; icon: "spotify"; execCmd: "spotify"; desktopId: "spotify.desktop" }
    ListElement { name: "Discord"; icon: "discord"; execCmd: "discord"; desktopId: "discord.desktop" }
    ListElement { name: "Code"; icon: "com.visualstudio.code.oss"; execCmd: "code"; desktopId: "code.desktop" }
    ListElement { name: "Settings"; icon: "preferences-system"; execCmd: "systemsettings"; desktopId: "systemsettings.desktop" }
    ListElement { name: "Hyprlock"; icon: "system-lock-screen"; execCmd: "hyprlock"; desktopId: "" }
  }

  // Active filtered model bound to ListView display
  ListModel {
    id: filteredAppModel
  }

  Component.onCompleted: {
    root.filterModel()
  }

  function populateModel(appsList) {
    if (!appsList || appsList.length === 0) return
    fullAppModel.clear()
    for (let i = 0; i < appsList.length; i++) {
      fullAppModel.append(appsList[i])
    }
    root.filterModel()
  }

  function filterModel() {
    filteredAppModel.clear()
    let query = searchInput.text.toLowerCase().trim()

    for (let i = 0; i < fullAppModel.count; i++) {
      let item = fullAppModel.get(i)
      if (!query || item.name.toLowerCase().includes(query)) {
        filteredAppModel.append({
          name: item.name,
          icon: item.icon,
          execCmd: item.execCmd,
          desktopId: item.desktopId || ""
        })
      }
    }
    appListView.currentIndex = 0
  }

  function launchApp(execCmd, desktopId) {
    appLauncher.launch(execCmd, desktopId)
    root.isOpen = false
  }

  function launchCurrentItem() {
    if (appListView.currentIndex < 0 || appListView.currentIndex >= filteredAppModel.count) return
    let item = filteredAppModel.get(appListView.currentIndex)
    if (item) {
      root.launchApp(item.execCmd, item.desktopId)
    }
  }

  Rectangle {
    id: container
    width: root.containerWidth
    height: root.containerHeight
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 16

    x: root.isOpen ? 16 : -width - 24
    opacity: root.isOpen ? 1.0 : 0.0

    Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    color: root.glassBgColor
    radius: root.containerRadius

    MouseArea {
      anchors.fill: parent
      onClicked: mouse => { mouse.accepted = true }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: Config.innerBorderMargin
      radius: root.innerBorderRadius
      color: "#00000000"
      border.color: root.borderColor
      border.width: 1
    }

    Column {
      id: columnLayout
      width: parent.width - 32
      height: parent.height - 32
      anchors.centerIn: parent
      spacing: 14

      // Search Input Container
      Rectangle {
        width: parent.width
        height: 50
        radius: 14
        color: root.searchBgColor
        border.color: searchInput.activeFocus ? root.activeBorderColor : root.borderColor
        border.width: 1

        Row {
          anchors.fill: parent
          anchors.leftMargin: 16
          anchors.rightMargin: 16
          spacing: 14

          Text {
            text: Config.iconSearch
            color: root.textMutedColor
            font.pixelSize: Config.fontSizeIconLarge
            font.family: Config.fontIcon
            anchors.verticalCenter: parent.verticalCenter
          }

          TextInput {
            id: searchInput
            width: parent.width - 50
            anchors.verticalCenter: parent.verticalCenter
            color: root.textPrimaryColor
            font.pixelSize: Config.fontSizeTitle
            font.family: Config.fontSans
            clip: true
            focus: root.isOpen

            Text {
              text: "Search apps..."
              color: root.textPlaceholderColor
              font.pixelSize: Config.fontSizeTitle
              font.family: Config.fontSans
              visible: !searchInput.text && !searchInput.activeFocus
              anchors.verticalCenter: parent.verticalCenter
            }

            Keys.onDownPressed: {
              if (appListView.count > 0) {
                appListView.currentIndex = Math.min(appListView.count - 1, appListView.currentIndex + 1)
              }
            }

            Keys.onUpPressed: {
              if (appListView.count > 0) {
                appListView.currentIndex = Math.max(0, appListView.currentIndex - 1)
              }
            }

            Keys.onReturnPressed: root.launchCurrentItem()
            Keys.onEnterPressed: root.launchCurrentItem()
            Keys.onEscapePressed: root.isOpen = false
            onTextChanged: root.filterModel()
          }
        }
      }

      // App List View
      ListView {
        id: appListView
        width: parent.width
        height: parent.height - 64
        clip: true
        spacing: 6
        currentIndex: 0
        highlightFollowsCurrentItem: true

        model: filteredAppModel

        delegate: Rectangle {
          id: delegateRect
          required property int index
          required property string name
          required property string icon
          required property string execCmd
          required property string desktopId

          readonly property bool isSelected: index === appListView.currentIndex

          width: appListView.width
          height: 52
          radius: Config.cardRadius
          color: isSelected ? root.highlightColor : "#00000000"

          Behavior on color { ColorAnimation { duration: 120 } }

          Row {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16

            Item {
              width: 28
              height: 28
              anchors.verticalCenter: parent.verticalCenter

              Image {
                id: appIconImg
                anchors.fill: parent
                source: icon ? ("image://icon/" + icon) : ""
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
              }

              Rectangle {
                anchors.fill: parent
                radius: 6
                color: root.highlightColor
                visible: appIconImg.status !== Image.Ready

                Text {
                  anchors.centerIn: parent
                  text: name ? name.charAt(0).toUpperCase() : "?"
                  color: Config.textWhite
                  font.pixelSize: Config.fontSizeIconSmall
                  font.weight: Font.Bold
                  font.family: Config.fontSans
                }
              }
            }

            Text {
              text: name
              color: delegateRect.isSelected ? Config.textWhite : Config.textSubtle
              font.pixelSize: 17
              font.weight: delegateRect.isSelected ? Font.Bold : Font.Medium
              font.family: Config.fontSans
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              width: parent.width - 60
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              appListView.currentIndex = index
              root.launchCurrentItem()
            }
          }
        }
      }
    }
  }
}
