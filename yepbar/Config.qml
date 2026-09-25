// Config.qml
pragma Singleton

import QtQuick

QtObject {
  id: root

  // ==========================================
  // 🎨 SECTION 1: COLOR PALETTE & THEMING (Waybar Inspired)
  // ==========================================
  readonly property color glassBg: "#80141414"          // rgba(20, 20, 20, 0.5) Waybar style
  readonly property color glassHoverBg: "#b0141414"     // 70% translucent hover surface
  readonly property color searchBg: "#40141414"         // Input container background
  readonly property color borderColor: "#30ffffff"      // Subtle border stroke
  readonly property color activeBorderColor: "#60e2e8f0"// Active input border
  readonly property color separatorColor: "#40ffffff"   // Subdued divider lines

  // Element State Colors
  readonly property color hoverBg: "#25ffffff"          // Subtle button hover
  readonly property color activeHoverBg: "#40ffffff"    // Highlighted button hover
  readonly property color selectedBg: "#35ffffff"      // Active pill / workspace tint
  readonly property color pressedBg: "#30ffffff"       // Button press feedback

  // Text & Content Palette
  readonly property color textPrimary: "#ffffff"       // Pure white main text
  readonly property color textMuted: "#cbd5e1"         // Subtitle & secondary text
  readonly property color textPlaceholder: "#94a3b8"   // Search placeholder text
  readonly property color textSubtle: "#e2e8f0"        // Inactive item text
  readonly property color textDark: "#64748b"          // Out-of-month calendar dates
  readonly property color textWhite: "#ffffff"         // Pure white highlights

  // Accent & Status Colors
  readonly property color accentGreen: "#50fa7b"       // Charging & Success green
  readonly property color warningAmber: "#f1fa8c"      // Battery warning / Connecting amber
  readonly property color dangerRed: "#ff5555"         // Battery critical / CPU critical red

  // ==========================================
  // 📐 SECTION 2: DIMENSIONS & GEOMETRY (Ultra-Compact 20px Bar)
  // ==========================================
  readonly property int barHeight: 20
  readonly property int barMargin: 0
  readonly property int barPadding: 4

  readonly property int widgetRadius: 8
  readonly property int overlayRadius: 12
  readonly property int cardRadius: 6
  readonly property int innerBorderRadius: 6
  readonly property int innerBorderMargin: 1

  readonly property int buttonHeight: 16
  readonly property int buttonWidth: 16
  readonly property int buttonRadius: 4

  // Overlay Container Dimensions
  readonly property int appDrawerWidth: 320
  readonly property int appDrawerHeight: 460
  readonly property int calendarWidth: 260
  readonly property int brightnessWidth: 250
  readonly property int notifCenterWidth: 350

  // ==========================================
  // 🔤 SECTION 3: TYPOGRAPHY SYSTEM (Waybar 10px-11px Font)
  // ==========================================
  readonly property string fontSans: "JetBrainsMono Nerd Font"
  readonly property string fontMono: "JetBrainsMono Nerd Font"
  readonly property string fontIcon: "JetBrainsMono Nerd Font"

  readonly property int fontSizeSmall: 9
  readonly property int fontSizeNormal: 10
  readonly property int fontSizeMedium: 10
  readonly property int fontSizeLarge: 11
  readonly property int fontSizeTitle: 14
  readonly property int fontSizeIconSmall: 10
  readonly property int fontSizeIconMedium: 11
  readonly property int fontSizeIconLarge: 16

  // ==========================================
  // ⚙️ SECTION 4: COMPONENT CONFIGURATION
  // ==========================================

  // Workspace Switcher Options
  property string workspaceIndicatorStyle: "tint"
  property int defaultMinWorkspaces: 5

  // MPRIS Media Player Options
  property string mprisRightDisplayMode: "progress"
  property int mprisVisualizerBarCount: 6
  property int mprisTargetSideWidth: 160

  // Notification Center Options
  property int notifGroupCollapseAgeHours: 1
  property int notifHistoryRetentionDays: 7

  // Hardware & Hardware Monitoring Options
  property int sysCheckIntervalMs: 3000
  property int netCheckIntervalMs: 5000

  // ==========================================
  // 󰀻 SECTION 5: NERD FONT GLYPH ICONS
  // ==========================================
  readonly property string iconLauncher: "󰀻"
  readonly property string iconSearch: "󰍉"
  readonly property string iconPlay: "󰐊"
  readonly property string iconPause: "󰏤"
  readonly property string iconPrevTrack: "󰒮"
  readonly property string iconNextTrack: "󰒭"
  readonly property string iconCpu: "󰍛"
  readonly property string iconRam: "󰘚"
  readonly property string iconNet: "󰛳"
  readonly property string iconDisk: "󰋊"
  readonly property string iconTemp: "󰔏"
  readonly property string iconBluetooth: "󰂯"
  readonly property string iconEthernet: "󰈀"
  readonly property string iconWifiConnected: "󰤨"
  readonly property string iconWifiConnecting: "󱍸"
  readonly property string iconWifiDisconnected: "󰤭"
  readonly property string iconPower: "󰐥"
  readonly property string iconChevronLeft: "󰅁"
  readonly property string iconChevronRight: "󰅂"
  readonly property string iconChevronDown: "󰅀"
  readonly property string iconBell: "󰂚"
  readonly property string iconBellDot: "󰂞"
  readonly property string iconTrash: "󰩹"
  readonly property string iconClose: "󰅖"

  // Battery Icons (Waybar Battery Icons)
  readonly property string iconBatCharging: "󰂄"
  readonly property string iconBat100: "󰁹"
  readonly property string iconBat90: "󰂂"
  readonly property string iconBat80: "󰂁"
  readonly property string iconBat70: "󰂀"
  readonly property string iconBat60: "󰁿"
  readonly property string iconBat50: "󰁾"
  readonly property string iconBat40: "󰁽"
  readonly property string iconBat30: "󰁼"
  readonly property string iconBat20: "󰁻"
  readonly property string iconBat10: "󰁺"

  // Volume Icons
  readonly property string iconVolHigh: ""
  readonly property string iconVolMedium: ""
  readonly property string iconVolLow: ""
  readonly property string iconVolMuted: "󰝟"

  // Brightness Icons
  readonly property string iconBrightHigh: "󰃠"
  readonly property string iconBrightMedium: "󰃟"
  readonly property string iconBrightLow: "󰃞"
  readonly property string iconBrightOff: "󰃝"

  // ==========================================
  // 🚀 SECTION 6: APPLICATION COMMANDS
  // ==========================================
  readonly property string cmdVolumeControl: "pavucontrol"
  readonly property string cmdBluetoothControl: "blueman-manager"
  readonly property string cmdNetworkControl: "nm-connection-editor"
  readonly property string cmdPowerMenu: "bash -c 'pkill -x wlogout || wlogout'"
}
