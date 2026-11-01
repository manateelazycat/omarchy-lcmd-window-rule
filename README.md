# Omarchy LCMD Window Rule

English | [简体中文](README.zh-CN.md)

An Omarchy service plugin that manages Lazycat Microserver Desktop (LCMD) and remote WeChat windows together. It combines the last two sections of the [Omarchy installation manual](https://manateelazycat.github.io/2026/09/20/omarchy-installation-manual/) with the Remote WeChat launcher exception and automatic placement on an empty screen.

- Each Lazycat main/app window opens in the next empty workspace (`emptyn`).
- The temporary `Remote WeChat` / `Remote WeChat-…` connecting page is excluded. Its automatic closing therefore does not leave another monitor on a newly selected empty workspace.
- Remote WeChat cannot steal focus or follow activation requests into the workspace you are using.
- With multiple active, independent displays, remote WeChat opens on a display whose **currently visible workspace** has no other application windows. The current display is preferred when already empty; otherwise the lowest monitor ID wins. Placement does not move focus or switch another display's workspace.
- Single-display setups and setups without an empty screen keep normal placement. Displays with an open special workspace, mirrored displays, and powered-off displays are not candidates. Pinned windows count as occupied; the temporary connecting page does not.

Only remote WeChat with class `wechat` and initial title `微信 on cloud.lazycat.catlink.wechat-cde` is managed. Local WeChat is unaffected. Existing windows are not relocated when enabling the plugin.

Windows tagged `omarchy-startup-map` by Startup Map keep their explicitly configured destination instead of being reassigned to an empty screen.

## Install locally

Requires Omarchy's Quickshell plugin system and Hyprland 0.56+ with Lua configuration support. No additional packages or persistent worker processes are needed.

```bash
cd ~/omarchy-lcmd-window-rule
bash install.sh
```

This copies the plugin into `~/.config/omarchy/plugins/io.github.manateelazycat.lcmd-window-rule` and enables it. Use `--no-enable` to copy it without changing activation. Configuration/state locations honor `XDG_CONFIG_HOME` and `XDG_STATE_HOME`.

Reinstalling an existing copy restarts Omarchy's shell to clear Qt's component cache; application windows remain open.

### Migrate the manual configuration

Remove the two manual rules from the article and any earlier `require("hypr.remote-wechat")` include before enabling, or use the optional migration:

```bash
python3 migrate.py                 # preview the exact recognized snippets
bash install.sh --migrate          # back up, migrate, reload, and enable
```

The migration recognizes only the documented snippets and the previous interactive setup; it does not rewrite customized Lua. Review customized or differently formatted versions manually. Private backups are stored under `~/.local/state/omarchy/lcmd-window-rule/backups/`. The previous standalone helper is retired only when its known include and identifying header are present. Disabling/removing this plugin does not restore those legacy rules.

## Manage

```bash
omarchy plugin disable io.github.manateelazycat.lcmd-window-rule
omarchy plugin enable io.github.manateelazycat.lcmd-window-rule
omarchy-shell io.github.manateelazycat.lcmd-window-rule status
omarchy plugin remove io.github.manateelazycat.lcmd-window-rule
```

The service installs two named runtime window rules and one native Lua window-open subscription. Disabling or removing it disables the rules and removes the subscription. Reloading Hyprland reapplies them. A service generation token prevents an old instance's cleanup from disabling its replacement. No permanent include is added to `hyprland.lua`.

## Validate

```bash
omarchy plugin validate .
lua tests/rules.lua
python3 -m unittest discover -s tests -p 'test_*.py'
bash -n install.sh
```

## License

Copyright © 2026 Andy Stewart (ManateeLazyCat).

All source code is licensed under the GNU General Public License version 3 (`GPL-3.0-only`). See [LICENSE](LICENSE) for the full license text.
