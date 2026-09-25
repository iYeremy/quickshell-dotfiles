// Standalone wallpaper carousel launched with Super+Shift+W.
import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
  id: root

  // Presentation settings
  property int speed: 5000
  property int animationDuration: 1000
  property real zoomScale: 0.8
  property real edgeScale: 0.3
  property real skewFactor: 0
  property int baseSpacing: 10
  property int startPosition: 20

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string shellDir: Quickshell.shellDir

  implicitWidth: Screen.width
  implicitHeight: Math.min(500, Screen.height)
  color: "transparent"
  aboveWindows: true
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  WlrLayershell.namespace: "wallpaperselect"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  function resolveHomePath(path) {
    if (!path)
      return ""

    return path.startsWith("/") ? path : root.homeDir + "/" + path
  }

  Component.onCompleted: {
    Quickshell.execDetached([
      "bash",
      Quickshell.shellPath("cache.sh"),
      root.shellDir
    ])

    Qt.callLater(function() {
      list.forceActiveFocus()
    })
  }

  FileView {
    path: Quickshell.shellPath("config.json")
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
      id: configs

      property string wallpaper_path: "Pictures/Wallpapers/"
      property string cache_path: ".cache/quickshell/thumbs/"
      property int number_of_pictures: 10
      property string border_color: "#80FFFFFF"
    }
  }

  FolderListModel {
    id: folderModel

    folder: "file://" + root.resolveHomePath(configs.wallpaper_path)
    showDirs: false
    nameFilters: ["*.png", "*.jpg", "*.jpeg"]
    sortField: FolderListModel.Name
  }

  ListView {
    id: list

    anchors.fill: parent
    focus: true
    model: folderModel
    orientation: ListView.Horizontal
    spacing: root.baseSpacing
    clip: true
    cacheBuffer: 400
    boundsBehavior: Flickable.StopAtBounds

    property int selectedIndex: root.startPosition
    property bool ready: false
    readonly property int columns: Math.max(
      1,
      Math.min(
        Math.max(1, configs.number_of_pictures),
        Math.max(1, count)
      )
    )
    readonly property real tileWidth: Math.max(
      1,
      (width - spacing * columns) / columns
    )
    readonly property real viewportCenterX: width / 2

    // Extend the scrollable area on both ends so every tile can be centered.
    leftMargin: Math.max(0, viewportCenterX - tileWidth / 2)
    rightMargin: leftMargin

    onCountChanged: {
      if (count === 0)
        return

      selectedIndex = clampIndex(selectedIndex)

      if (!ready)
        ready = true

      Qt.callLater(function() {
        list.ensureVisibleAnimated(list.selectedIndex)
        list.forceActiveFocus()
      })
    }

    function clampIndex(index) {
      return Math.max(0, Math.min(index, count - 1))
    }

    function ensureVisibleAnimated(index) {
      const step = tileWidth + spacing
      contentX = index * step + tileWidth / 2 - viewportCenterX
    }

    function moveSelection(delta, speedMultiplier) {
      animation.velocity = root.speed * speedMultiplier
      selectedIndex = clampIndex(selectedIndex + delta)
      ensureVisibleAnimated(selectedIndex)
    }

    function activateCurrent() {
      if (selectedIndex < 0 || selectedIndex >= count)
        return

      const selectedFile = folderModel.get(selectedIndex, "filePath")
      if (!selectedFile)
        return

      Quickshell.execDetached([
        "bash",
        Quickshell.shellPath("commands.sh"),
        selectedFile
      ])

      Qt.quit()
    }

    Behavior on contentX {
      enabled: list.ready

      SmoothedAnimation {
        id: animation
        velocity: root.speed
        duration: root.animationDuration
      }
    }

    delegate: Item {
      id: delegateItem

      required property int index
      required property string fileName

      readonly property real baseWidth: list.tileWidth
      readonly property bool active: index === list.selectedIndex
      readonly property real onScreenX: x - list.contentX + width / 2
      readonly property real scaleFactor: {
        const distance = Math.abs(onScreenX - list.viewportCenterX)
        const fraction = Math.min(1, distance / Math.max(1, list.viewportCenterX))
        const smoothstep = 1 - fraction * fraction * (3 - 2 * fraction)

        return root.edgeScale
          + (root.zoomScale - root.edgeScale) * smoothstep
      }

      width: list.tileWidth
      height: list.height

      Item {
        id: thumbnail

        width: delegateItem.baseWidth * delegateItem.scaleFactor
        height: delegateItem.height * Math.min(1, delegateItem.scaleFactor)
        anchors.centerIn: parent

        Text {
          anchors.centerIn: parent
          text: image.status === Image.Error ? "Caching..." : ""
          color: configs.border_color
          font.pixelSize: 16

          transform: Shear {
            xFactor: root.skewFactor
          }
        }

        Image {
          id: image

          anchors.fill: parent
          opacity: 0.8
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          smooth: true
          source: "file://"
            + root.resolveHomePath(configs.cache_path)
            + "/"
            + fileName

          sourceSize.width: delegateItem.baseWidth * root.zoomScale
          sourceSize.height: delegateItem.height

          transform: Shear {
            xFactor: root.skewFactor
          }

          Timer {
            id: retryTimer

            interval: 1000
            repeat: false

            onTriggered: {
              const previousSource = image.source
              image.source = ""
              image.source = previousSource
            }
          }

          onStatusChanged: {
            if (status === Image.Error)
              retryTimer.start()
          }
        }

        Rectangle {
          z: 10
          anchors.fill: parent
          visible: delegateItem.active
          color: "transparent"
          border.width: 2
          border.color: configs.border_color

          transform: Shear {
            xFactor: root.skewFactor
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: list.selectedIndex = index
        onClicked: {
          list.selectedIndex = index
          list.activateCurrent()
        }
        onWheel: function(wheel) {
          list.flick(-wheel.angleDelta.y * 8, 0)
          wheel.accepted = true
        }
      }
    }

    Keys.onPressed: function(event) {
      const speedMultiplier = event.modifiers & Qt.ShiftModifier ? 3 : 1

      switch (event.key) {
      case Qt.Key_Right:
      case Qt.Key_L:
        moveSelection(1, speedMultiplier)
        break
      case Qt.Key_Left:
      case Qt.Key_H:
        moveSelection(-1, speedMultiplier)
        break
      case Qt.Key_Home:
        selectedIndex = 0
        ensureVisibleAnimated(selectedIndex)
        break
      case Qt.Key_End:
        selectedIndex = clampIndex(count - 1)
        ensureVisibleAnimated(selectedIndex)
        break
      case Qt.Key_Space:
      case Qt.Key_Return:
      case Qt.Key_Enter:
        activateCurrent()
        break
      case Qt.Key_W:
      case Qt.Key_Q:
      case Qt.Key_Escape:
        Qt.quit()
        break
      default:
        return
      }

      event.accepted = true
    }
  }

  Text {
    anchors.centerIn: parent
    visible: folderModel.count === 0
    text: "No wallpapers found in ~/Pictures/Wallpapers"
    color: configs.border_color
    font.pixelSize: 18
  }
}
