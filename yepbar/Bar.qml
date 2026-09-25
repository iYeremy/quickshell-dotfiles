// Bar.qml - Quickshell Top Bar Window Container (Waybar Ultra-Compact Layout)
import Quickshell
import QtQuick
import Quickshell.Wayland

Scope {
  id: root

  // Public Component References
  property var appDrawer: null
  property var calendarPopup: null
  property var brightnessPopup: null
  property var notificationCenter: null

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window
      required property var modelData
      screen: modelData

      // Wayland LayerShell Integration
      WlrLayershell.namespace: "quickshell-bar"
      WlrLayershell.layer: WlrLayer.Top

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: Config.barHeight + 4
      color: "#00000000" // Entire bar background is transparent, matching Waybar window#waybar

      // Left Module (Waybar .modules-left): Workspaces, CPU, RAM, Battery, Temp
      WorkspaceWidget {
        id: workspaceWidget
        appDrawer: root.appDrawer
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 2
      }

      // Center Module (Waybar .modules-center): Clock & Calendar Toggle
      ClockWidget {
        id: clockWidget
        calendarPopup: root.calendarPopup
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 2
      }

      // Right Module (Waybar .modules-right): MPRIS Marquee, Pulseaudio, Brightness, Network, Power
      StatusWidget {
        id: statusWidget
        wifiConnected: workspaceWidget.wifiConnected
        ethConnected: workspaceWidget.ethConnected
        netConnecting: workspaceWidget.netConnecting
        brightnessPopup: root.brightnessPopup
        notificationCenter: root.notificationCenter
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 2
      }
    }
  }
}