#!/usr/bin/env bash
set -euo pipefail

image=${1:?A wallpaper path is required}

awww img "$image" -t random --transition-duration 1
wal -i "$image" -n -q

if [[ -f "$HOME/generate-brave-theme.sh" ]]; then
  bash "$HOME/generate-brave-theme.sh"
fi

if command -v kitty >/dev/null 2>&1; then
  kitty +kitten themes --reload-in=all 2>/dev/null \
    || pkill -SIGUSR1 kitty 2>/dev/null \
    || true
fi
