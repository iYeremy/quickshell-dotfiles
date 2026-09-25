// shell.qml - Quickshell Main Entry Point
import Quickshell
import QtQuick

Scope {
  id: root

  // Main Top Bar Panel
  Bar {
    appDrawer: drawer
    calendarPopup: calendar
    brightnessPopup: brightness
    notificationCenter: notifCenter
  }

  // Application Drawer Overlay
  AppDrawer {
    id: drawer
  }

  // Calendar Overlay
  CalendarPopup {
    id: calendar
  }

  // Display Brightness Control Overlay
  BrightnessPopup {
    id: brightness
  }

  // Notification Center Overlay
  NotificationCenter {
    id: notifCenter
  }
}
