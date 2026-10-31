#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andy Stewart (ManateeLazyCat)
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
plugin_id=io.github.manateelazycat.lcmd-window-rule
config_root=${XDG_CONFIG_HOME:-$HOME/.config}
target_dir=$config_root/omarchy/plugins/$plugin_id
backup_root=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/lcmd-window-rule/backups
enable=true
migrate=false
updating=false
[[ ! -f $target_dir/manifest.json ]] || updating=true
for arg in "$@"; do
  case "$arg" in
    --no-enable) enable=false ;;
    --migrate) migrate=true ;;
    *) printf 'Usage: bash install.sh [--no-enable] [--migrate]\n' >&2; exit 2 ;;
  esac
done
for command in omarchy omarchy-shell hyprctl python3; do
  command -v "$command" >/dev/null || { printf 'Missing command: %s\n' "$command" >&2; exit 1; }
done
omarchy plugin validate "$source_dir"
install -d -m 700 -- "$backup_root"
stamp=$(date +%Y%m%d-%H%M%S-%N)
if [[ -f $config_root/omarchy/shell.json ]]; then
  (umask 077; cp -- "$config_root/omarchy/shell.json" "$backup_root/shell-$stamp.json")
fi
if [[ $(realpath -m -- "$source_dir") != $(realpath -m -- "$target_dir") ]]; then
  if [[ -e $target_dir ]]; then cp -a -- "$target_dir" "$backup_root/plugin-$stamp"; fi
  mkdir -p -- "$target_dir"
  # Load the new service only after its Lua module and metadata are in place.
  for file in rules.lua manifest.json README.md README.zh-CN.md LICENSE migrate.py install.sh; do
    install -m 644 -- "$source_dir/$file" "$target_dir/$file"
  done
  install -m 644 -- "$source_dir/Service.qml" "$target_dir/Service.qml"
fi
if [[ $migrate == true ]]; then
  python3 "$source_dir/migrate.py" --apply
  hyprctl reload >/dev/null
  errors=$(hyprctl configerrors)
  if [[ -n ${errors//[[:space:]]/} ]]; then
    printf 'Hyprland configuration errors after migration:\n%s\n' "$errors" >&2
    exit 1
  fi
fi
omarchy-shell shell rescanPlugins
if [[ $enable == true ]]; then
  discovered=false
  for attempt in {1..50}; do
    if omarchy plugin list --json | python3 -c 'import json,sys; sys.exit(not any(p["id"] == sys.argv[1] for p in json.load(sys.stdin)))' "$plugin_id"; then
      discovered=true
      break
    fi
    sleep 0.1
  done
  [[ $discovered == true ]] || { printf 'Plugin discovery timed out.\n' >&2; exit 1; }
  omarchy plugin enable "$plugin_id"
fi
# Dynamic plugin components can remain in Qt's URL cache after file updates.
# A restart also makes repeated local installs load the new service code.
if [[ $updating == true ]]; then omarchy restart shell; fi
printf 'Installed: %s\n' "$target_dir"
