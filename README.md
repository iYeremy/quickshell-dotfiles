# Quickshell Configurations

Monorepo for the local Quickshell and Wayland shell configurations.

## Components

- `yepbar/` — always-running Hyprland bar and overlays.
- `wallpaperselect/` — on-demand wallpaper carousel, bound to `Super+Shift+W`.
- `hyprquickpaper/` — legacy standalone wallpaper carousel.
- `volume-osd/` — volume OSD shell.

## Running configurations

```bash
quickshell -p ~/.config/quickshell/yepbar/shell.qml
quickshell -n -c wallpaperselect
quickshell -n -c hyprquickpaper
quickshell -n -c volume-osd
```

Generated build artifacts, local Quickshell tooling files, logs, Python caches, and local environment files are excluded by `.gitignore`.
