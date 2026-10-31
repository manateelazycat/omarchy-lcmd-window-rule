import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('migration', ROOT / 'migrate.py')
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class MigrationTests(unittest.TestCase):
    def test_article_configuration(self):
        unrelated = 'o.window("foot", { opacity = "1 1 0.999 override" })\n'
        text = unrelated + migration.CLIENT_ORIGINAL + '\n' + migration.WECHAT
        changed, removed = migration.migrate(text)
        self.assertEqual(removed, ['client-workspaces', 'wechat-focus'])
        self.assertEqual(changed, unrelated + '\n')

    def test_current_configuration_and_idempotence(self):
        text = '\n'.join([migration.CLIENT_EXCLUDED, migration.WECHAT, 'require("hypr.remote-wechat")'])
        changed, removed = migration.migrate(text)
        self.assertEqual(len(removed), 3)
        self.assertEqual(migration.migrate(changed), (changed, []))

    def test_custom_rules_remain_untouched(self):
        text = migration.CLIENT_ORIGINAL.replace('emptyn', 'emptyn silent')
        self.assertEqual(migration.migrate(text), (text, []))

    def test_duplicates_fail_before_editing(self):
        with self.assertRaises(ValueError):
            migration.migrate(migration.WECHAT * 2)

    def test_preview_and_private_backup_and_retirement(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / 'hyprland.lua'
            helper = root / 'remote-wechat.lua'
            before = migration.CLIENT_EXCLUDED + '\nrequire("hypr.remote-wechat")\n'
            config.write_text(before)
            helper.write_text('-- Put remote WeChat on an already-visible empty workspace\n')
            env = dict(os.environ, XDG_STATE_HOME=str(root / 'state'))
            command = [sys.executable, str(ROOT / 'migrate.py'), '--config', str(config)]
            subprocess.run(command, env=env, check=True, capture_output=True)
            self.assertEqual(config.read_text(), before)
            self.assertTrue(helper.exists())
            subprocess.run(command + ['--apply'], env=env, check=True, capture_output=True)
            self.assertFalse(helper.exists())
            backups = list((root / 'state').rglob('hyprland.lua-*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), before)
            self.assertEqual(backups[0].stat().st_mode & 0o777, 0o600)
            subprocess.run(command + ['--apply'], env=env, check=True, capture_output=True)
            self.assertEqual(len(list((root / 'state').rglob('hyprland.lua-*'))), 1)


if __name__ == '__main__':
    unittest.main()
