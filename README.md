# Quickshell Configurations

Monorepo for the local Quickshell and Wayland shell configurations.

## Components

- `yepbar/` — always-running Hyprland bar and overlays.
- `wallpaperselect/` — on-demand wallpaper carousel, bound to `Super+Shift+W`.
- `volume-osd/` — volume OSD shell.

The local legacy `hyprquickpaper/` directory is intentionally ignored.

## Running configurations

```bash
quickshell -p ~/.config/quickshell/yepbar/shell.qml
quickshell -n -c wallpaperselect
quickshell -n -c volume-osd
```

Generated build artifacts, local Quickshell tooling files, logs, Python caches, and local environment files are excluded by `.gitignore`.
