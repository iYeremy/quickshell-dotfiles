#!/usr/bin/env bash
set -uo pipefail

shell_dir="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
config_file="$shell_dir/config.json"

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "wallpaperselect: jq is required" >&2
  exit 1
fi

wallpaper_path=$(jq -er '.wallpaper_path' "$config_file") || exit 1
cache_path=$(jq -er '.cache_path' "$config_file") || exit 1
cache_batch_size=$(jq -er '.cache_batch_size' "$config_file") || exit 1

if [[ "$wallpaper_path" != /* ]]; then
  wallpaper_path="$HOME/$wallpaper_path"
fi
if [[ "$cache_path" != /* ]]; then
  cache_path="$HOME/$cache_path"
fi

if [[ ! -d "$wallpaper_path" ]]; then
  printf '%s\n' "wallpaperselect: wallpaper directory not found: $wallpaper_path" >&2
  exit 1
fi

mkdir -p "$cache_path"

if command -v magick >/dev/null 2>&1; then
  thumbnail_command=(magick)
elif command -v convert >/dev/null 2>&1; then
  thumbnail_command=(convert)
else
  printf '%s\n' "wallpaperselect: ImageMagick is required" >&2
  exit 1
fi

printf 'Wallpaper path: %s\n' "$wallpaper_path"
printf 'Thumbnail path: %s\n' "$cache_path"

while IFS= read -r -d '' image; do
  filename=$(basename "$image")
  output="$cache_path/$filename"

  if [[ -f "$output" ]]; then
    continue
  fi

  printf 'Generating thumbnail: %s\n' "$filename"
  "${thumbnail_command[@]}" "$image" -thumbnail x500 -strip -quality 85 "$output" &

  if (( cache_batch_size > 0 )); then
    while (( $(jobs -rp | wc -l) >= cache_batch_size )); do
      wait -n || true
    done
  fi
done < <(find "$wallpaper_path" -maxdepth 1 -type f \( \
  -iname '*.jpg' -o \
  -iname '*.jpeg' -o \
  -iname '*.png' \
\) -print0)

wait

printf '%s\n' "Thumbnail generation complete."
