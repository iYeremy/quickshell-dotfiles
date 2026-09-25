# Yepbar — Quickshell Dotfiles

This is the Quickshell evolution of my old [Waybar](https://github.com/Alexays/Waybar)
setup: a tiny always-on bar that
quickly grew into a small desktop UI with overlays, an app drawer, notifications,
a calendar and system controls.

The main piece is `yepbar`. The wallpaper selector and volume OSD are separate
Quickshell configurations, because there is zero reason to keep heavyweight stuff
alive just to render a 20 px bar, ngl.

## TL;DR

- `yepbar/` is the always-running bar and its overlays.
- `wallpaperselect/` only runs when I press `Super+Shift+W`.
- `volume-osd/` is a small persistent PipeWire OSD.
- The whole thing is configured with QML through Quickshell.
- Rust and Python are used where they make more sense than forcing QML to do
  everything.

Nothing here is trying to replace every bar on the planet. It is simply the shell
I actually use.

## Why did I move from Waybar to Quickshell?

Look, Waybar is still excellent. It is fast, predictable and does one thing very
well: being a bar. My old config is still around at `~/.config/waybar` because
Waybar remains a completely valid choice if that is all you need.

The switch happened because this project stopped being “just a bar”:

- I wanted a real application drawer instead of launching Rofi.
- The calendar and brightness controls needed shared state and custom animation.
- The notification center needed history, grouping and actions.
- Bar modules needed to coordinate with those overlays.
- At that point, rebuilding everything as one small reactive UI made more sense
  than forcing increasingly complex behavior into JSON, CSS and helper scripts.

Waybar modules are great for reading values and showing text. QML is better when
the UI has state, transitions, nested components and several windows that need to
talk to each other. Quickshell also gives us direct access to Hyprland, PipeWire,
MPRIS, processes, files and IPC without making the project explode into a pile of
fragile polling scripts.

BTW, Quickshell is not magically lighter than Waybar. The reason for moving was
**fit**, not some fake “Waybar bad” manifesto. If you only want modules, use
Waybar. If the bar is becoming a tiny desktop shell, Quickshell is ngl a much
better fit.

## What is in the box?

### Always-running `yepbar`

- Compact translucent top bar, one window per monitor.
- Hyprland workspaces and system state on the left.
- Clock and calendar toggle in the center.
- MPRIS controls, audio, brightness, network and power actions on the right.
- Application drawer with XDG `.desktop` scanning.
- Notification center with grouping and local history.
- Brightness popup and calendar popup.
- Small IPC targets for controlling important surfaces from keybinds or scripts.

### On-demand `wallpaperselect`

A dock-style wallpaper carousel with thumbnails, mouse/keyboard navigation and
automatic thumbnail generation.

It is **not** loaded by `yepbar`. The bar stays alive, and the selector is created
only when the shortcut asks for it. That is the whole point.

### Persistent `volume-osd`

A tiny PipeWire-backed volume overlay. It listens to the default audio sink and
shows a short OSD when the volume or mute state changes.

## Repository layout

```text
~/.config/quickshell/
├── yepbar/
│   ├── shell.qml                 → main always-running Quickshell entry point
│   ├── qmldir                    → local QML module declarations
│   ├── Config.qml                → dimensions, colors, fonts, icons and commands
│   ├── Bar.qml                   → panel layout and per-screen windows
│   ├── *Widget.qml               → bar modules
│   ├── *Popup.qml                → calendar, brightness and notifications
│   ├── App*.qml                  → drawer, scanner and launcher
│   ├── scripts/                  → Python/Rust helpers used by the UI
│   └── archive/                  → old prototypes; kept for history, not runtime
├── wallpaperselect/
│   ├── shell.qml                 → standalone wallpaper carousel
│   ├── config.json               → paths and carousel settings
│   ├── cache.sh                  → thumbnail generation
│   └── commands.sh               → wallpaper, palette and terminal theme updates
├── volume-osd/
│   └── shell.qml                 → standalone PipeWire volume OSD
└── README.md
```

The old local `hyprquickpaper/` directory is intentionally ignored;
`wallpaperselect/` is the maintained version.

I am deliberately not documenting every QML property like it is a textbook. The
important entry points are listed below; the rest is regular Qt/QML code and
should be read when touching the actual UI.

## How the shell is put together

```text
Hyprland
├── yepbar (always running)
│   ├── Bar
│   │   ├── WorkspaceWidget
│   │   ├── ClockWidget
│   │   └── StatusWidget
│   ├── AppDrawer
│   ├── CalendarPopup
│   ├── BrightnessPopup
│   └── NotificationCenter
├── volume-osd (background process)
└── wallpaperselect (only on Super+Shift+W)
```

`yepbar/shell.qml` is the root `Scope`. It creates the bar and passes references
to the overlays, so the clock can open the calendar, the status module can open
brightness, and so on. `Bar.qml` uses `Variants` to create one `PanelWindow` per
Quickshell screen.

Most live data comes from event-driven sources:

- Quickshell's Hyprland service for workspaces and windows.
- PipeWire events for audio state.
- `playerctl` MPRIS events for media metadata.
- DBus notifications for the notification history.
- A tiny Rust monitor for the values that are easier to collect in one process.
- Python only where the helper is clearer than fighting QML abstractions.

The wallpaper carousel is intentionally outside this graph. It has its own
process, its own lifecycle and its own cache. No lazy `Loader` nonsense inside
the always-on bar.

## Requirements

The core desktop needs:

| Dependency | Why it is needed |
| --- | --- |
| `quickshell` | Runs the QML configurations. Tested with Quickshell 0.3.1. |
| Hyprland / Wayland LayerShell | Bar, overlays and screen management. |
| A Nerd Font | Otherwise the icons become the classic tofu boxes. |
| `playerctl` | MPRIS metadata and media controls. |
| `wpctl` and `pactl` | Volume, mute and PipeWire/PulseAudio events. |
| `pavucontrol` | Full mixer opened from the audio UI. |
| `brightnessctl` | Reads and changes display brightness. |
| `nmcli` | NetworkManager state for Wi-Fi/Ethernet. |
| `gtk-launch` and `setsid` | Launches XDG applications from the drawer. |
| `python3` and `dbus-monitor` | App scanning and notification history. |
| `makoctl` | Optional, dismisses visible Mako notifications. |
| Rust and Cargo | Builds the small hardware monitor helper. |

The wallpaper selector additionally uses:

| Dependency | Why it is needed |
| --- | --- |
| `jq` | Reads `config.json` in the cache script. |
| ImageMagick (`magick` or `convert`) | Generates thumbnails. |
| `awww` | Applies the wallpaper transition. |
| `wal` | Generates the matching color palette. |
| `kitty` | Optional terminal theme reload after the wallpaper changes. |

The font currently used by `yepbar` is `JetBrainsMono Nerd Font`, with
`Symbols Nerd Font` for a few status icons.

## Installation

Back up the current config first if you already have one. Obviously.

Clone this repository directly into the Quickshell config directory:

```sh
git clone https://github.com/iYeremy/quickshell-dotfiles.git ~/.config/quickshell
cd ~/.config/quickshell
```

Build the native hardware monitor helper:

```sh
./yepbar/scripts/build_qs_monitor.sh
```

That script compiles `yepbar/scripts/qs_monitor/` with the committed `Cargo.lock`
and installs `qs_monitor_bin` where `WorkspaceWidget.qml` expects it. The binary
is generated, so it is ignored by Git instead of being committed as an opaque
machine-specific blob.

If you are setting this up somewhere else, also make sure the helper scripts are
executable:

```sh
chmod +x yepbar/scripts/*.sh yepbar/scripts/*.py
chmod +x wallpaperselect/*.sh
```

## Running the configurations

Run the always-on bar by config name:

```sh
quickshell -c yepbar
```

Or point Quickshell directly at the entry point:

```sh
quickshell -p ~/.config/quickshell/yepbar/shell.qml
```

Run the wallpaper selector manually:

```sh
quickshell -n -c wallpaperselect
```

Run the volume OSD:

```sh
quickshell -n -c volume-osd
```

`-n` means “do not start a duplicate instance”. It is especially useful for the
wallpaper selector because pressing the shortcut twice should not stack two
carousels on top of each other.

A bare `quickshell` command expects a `shell.qml` directly inside
`~/.config/quickshell`. This repository uses named configurations, so use
`-c yepbar`, `-c wallpaperselect`, etc.

## Hyprland integration

The shell is already set up to launch on my machine, but the important parts are
easy to copy:

```lua
-- ~/.config/hypr/hyprland.lua
hl.execOnce("qs -p ~/.config/quickshell/yepbar/shell.qml")
hl.exec_cmd("qs -d -c volume-osd")
```

The wallpaper selector is intentionally on demand:

```lua
-- ~/.config/hypr/keybinds.lua
hl.bind(
  mainMod .. " + SHIFT + W",
  hl.dsp.exec_cmd("quickshell -n -c wallpaperselect")
)
```

So the lifecycle is simple:

1. Hyprland starts `yepbar`.
2. Hyprland starts the small volume OSD daemon.
3. The bar stays alive all session.
4. `Super+Shift+W` starts `wallpaperselect`.
5. Selecting a wallpaper or pressing `Esc` closes the selector process.

## Using the wallpaper selector

The selector reads `wallpaperselect/config.json`:

```json
{
  "wallpaper_path": "Pictures/Wallpapers/",
  "cache_path": ".cache/quickshell/thumbs/",
  "number_of_pictures": 10,
  "border_color": "#80FFFFFF",
  "cache_batch_size": 20
}
```

Controls:

- `Left` / `Right` or `H` / `L` → move selection.
- `Shift+Left` / `Shift+Right` → move faster.
- `Home` / `End` → jump to the first or last wallpaper.
- `Enter`, `Space` or `Return` → apply the selected wallpaper.
- `Esc`, `Q` or `W` → close without selecting anything.
- Mouse wheel → scroll the carousel.
- Click → apply that wallpaper.

Thumbnails are generated under `~/.cache/quickshell/thumbs/`, not inside the
repository. The selected wallpaper is applied through `awww`, then `wal` updates
the palette and the terminal theme is reloaded when possible.

## Where should I change things?

| I want to change... | Open this |
| --- | --- |
| Bar colors, dimensions, fonts or icons | `yepbar/Config.qml` |
| Left/center/right bar layout | `yepbar/Bar.qml` |
| Workspaces and hardware status | `yepbar/WorkspaceWidget.qml` |
| Media, volume, network or power UI | `yepbar/StatusWidget.qml` |
| App drawer behavior | `yepbar/AppDrawer.qml` |
| Notification behavior/history | `yepbar/NotificationCenter.qml` |
| Hardware polling process | `yepbar/scripts/qs_monitor/src/main.rs` |
| Wallpaper directory or carousel settings | `wallpaperselect/config.json` |
| Wallpaper application commands | `wallpaperselect/commands.sh` |
| Bar/selector startup | `~/.config/hypr/hyprland.lua` |
| `Super+Shift+W` | `~/.config/hypr/keybinds.lua` |

`yepbar/AUDIT_REPORT.md`, `yepbar/DESIGN_PHILOSOPHY.md` and `yepbar/archive/`
are historical notes and old experiments. They are useful context, but this
README plus the current source is the source of truth.

## Reloads and debugging

Quickshell watches the QML configuration and reloads it when files change. That
usually makes iteration instant. If the UI looks stuck or a helper process is
holding onto old state, inspect the running instances:

```sh
quickshell list --all
quickshell log --pid <PID> --follow
```

For a noisy foreground launch:

```sh
quickshell -c yepbar --no-color --verbose
```

Python and Rust helper changes may need the relevant process to be restarted.
The monitor binary also needs to be rebuilt with:

```sh
./yepbar/scripts/build_qs_monitor.sh
```

## Common gotchas

### `Could not find "default" config`

Use a named config:

```sh
quickshell -c yepbar
```

or pass the path with `-p`. A bare `quickshell` is not enough because
`~/.config/quickshell/shell.qml` does not exist.

### The config says “Loaded” but no bar appears

Check the Quickshell log first, then verify that you are on a Wayland session and
that the Hyprland LayerShell support is available. Also make sure another old
Waybar/Quickshell process is not fighting for the same layer.

### Icons are boxes

Install a Nerd Font and make sure `JetBrainsMono Nerd Font` and
`Symbols Nerd Font` are available to Qt. This is the eternal desktop ritual.

### Hardware values are missing

Build the monitor helper:

```sh
./yepbar/scripts/build_qs_monitor.sh
```

The Rust helper also has a few machine-specific assumptions (`BAT0`/`BAT1` and
`/mnt/storage`). If the numbers look wrong, check
`yepbar/scripts/qs_monitor/src/main.rs`.

### The wallpaper selector opens but thumbnails are missing

Check:

- `wallpaperselect/config.json` points at the real wallpaper directory.
- `jq` and ImageMagick are installed.
- `~/.cache/quickshell/thumbs/` is writable.
- The source images are PNG, JPG or JPEG files.

The selector retries failed thumbnails while `cache.sh` is generating them, so
give it a second instead of spamming the shortcut.

### The wallpaper shortcut does nothing

Check the active Hyprland config and reload it:

```sh
hyprctl reload
```

Then test the command directly:

```sh
quickshell -n -c wallpaperselect
```

If that works, the problem is the keybind. If it does not, the problem is
Quickshell or the config itself.

## Design rules

A few rules keep this project from turning into an unreadable QML blob:

- Keep `yepbar` alive and lightweight.
- Load heavy, temporary interfaces in their own process.
- Prefer event-driven updates over “run it every 200 ms and hope”.
- Keep shared visual constants in `Config.qml`.
- Use Rust/Python only when they make the helper simpler.
- Do not integrate the wallpaper carousel into the bar again. Seriously lol.

The whole point of moving to Quickshell was to make a more capable UI without
pretending every problem is a module problem. Waybar remains the simple path;
this repo is the “I want a tiny desktop shell” path.
