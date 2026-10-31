#!/usr/bin/env python3
"""Remove only the known manual rules superseded by this plugin; preview by default."""
import argparse
from datetime import datetime
import os
from pathlib import Path
import shutil
import tempfile


CLIENT_ORIGINAL = '''o.window("^lzc-client-desktop$", {
  workspace = "emptyn",
})'''
CLIENT_EXCLUDED = '''o.window(
  {
    class = "^lzc-client-desktop$",
    initial_title = "negative:^Remote WeChat(-.*)?$",
  },
  {
    workspace = "emptyn",
  }
)'''
WECHAT = r'''o.window(
  {
    class = "^wechat$",
    initial_title = "^微信 on cloud\\.lazycat\\.catlink\\.wechat-cde$",
  },
  {
    no_initial_focus = true,
    focus_on_activate = false,
    suppress_event = "activate activatefocus",
  }
)'''
COMMENTS = [
    '-- Open each Lazycat Microserver window in the next empty workspace.\n',
    '-- Open Lazycat app windows in the next empty workspace, except the transient\n'
    '-- Remote WeChat launcher: it closes after connecting and must not switch workspaces.\n',
    '-- Prevent remote WeChat from moving to the active workspace on activation.\n',
    '-- Place remote WeChat on a monitor whose visible workspace is empty.\n',
]


def migrate(text):
    removed = []
    for name, block in [('client-workspaces', CLIENT_ORIGINAL),
                        ('client-workspaces-with-exclusion', CLIENT_EXCLUDED),
                        ('wechat-focus', WECHAT),
                        ('wechat-placement', 'require("hypr.remote-wechat")')]:
        # Fail closed on ambiguous duplicates or hand-edited snippets.
        count = text.count(block)
        if count > 1:
            raise ValueError(f'Multiple copies of {name}; review configuration manually.')
        if count == 1:
            text = text.replace(block, '')
            removed.append(name)
    if removed:
        for comment in COMMENTS:
            text = text.replace(comment, '')
        # Leave unrelated configuration and its spacing intact.
    return text, removed


def backup(path, directory):
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, name = tempfile.mkstemp(prefix=path.name + '-', dir=directory)
    with os.fdopen(fd, 'wb') as out, path.open('rb') as source:
        shutil.copyfileobj(source, out)
    return Path(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    config_root = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config'))
    parser.add_argument('--config', type=Path, default=config_root / 'hypr/hyprland.lua')
    parser.add_argument('--apply', action='store_true', help='back up and apply the previewed migration')
    args = parser.parse_args()
    before = args.config.read_text()
    after, removed = migrate(before)
    print('Manual rules to migrate: ' + (', '.join(removed) or 'none'))
    if not removed or not args.apply:
        return
    state_root = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state'))
    backup_dir = state_root / 'omarchy/lcmd-window-rule/backups' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    print('Configuration backup:', backup(args.config, backup_dir))
    legacy = args.config.parent / 'remote-wechat.lua'
    # Only retire the exact helper from the previous interactive setup.
    retire_legacy = ('wechat-placement' in removed and legacy.is_file()
                     and legacy.read_text().startswith('-- Put remote WeChat on an already-visible empty workspace'))
    if retire_legacy:
        print('Legacy helper backup:', backup(legacy, backup_dir))
    args.config.write_text(after)
    if retire_legacy:
        legacy.unlink()


if __name__ == '__main__':
    main()
