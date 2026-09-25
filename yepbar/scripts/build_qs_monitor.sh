#!/usr/bin/env bash
set -euo pipefail

scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
crate_dir="$scripts_dir/qs_monitor"

if ! command -v cargo >/dev/null 2>&1; then
  printf '%s\n' "yepbar: cargo is required to build qs_monitor" >&2
  exit 1
fi

cargo build --release --locked --manifest-path "$crate_dir/Cargo.toml"
install -m 755 "$crate_dir/target/release/qs_monitor" "$scripts_dir/qs_monitor_bin"

printf 'Installed %s\n' "$scripts_dir/qs_monitor_bin"
