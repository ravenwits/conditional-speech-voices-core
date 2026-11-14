"""Portable entry points and repeatable Workshop metadata."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1] / 'tools'
sys.path.insert(0, str(TOOLS))

class Portability(unittest.TestCase):
    @unittest.skipIf(os.name == 'nt', 'POSIX shell execution runs on Linux and macOS')
    def test_shell_launcher_preserves_paths_and_arguments(self):
        import shutil
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'studio with spaces'
            (root / 'tools').mkdir(parents=True)
            shutil.copy2(TOOLS.parent / 'Start Studio.sh', root)
            (root / 'tools/launch_studio.py').write_text(
                'import json,sys;print(json.dumps(sys.argv[1:]))', encoding='utf-8')
            result = subprocess.run(['sh', str(root / 'Start Studio.sh'),
                '--project', 'voice project/pack.json', '--ffmpeg', '/a path/ffmpeg'],
                cwd=folder, env={**os.environ, 'PYTHON': sys.executable},
                capture_output=True, text=True, check=True)
            import json
            self.assertEqual(json.loads(result.stdout),
                ['--project', 'voice project/pack.json', '--ffmpeg', '/a path/ffmpeg'])

    def test_artwork_uses_us_label_and_one_icon_entry(self):
        import workshop_artwork as art
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); mod = root / 'mod'; (mod / '42').mkdir(parents=True)
            for directory in (mod, mod / '42'):
                (directory / 'mod.info').write_text('name=Test\nicon=old.png\n', encoding='utf-8')
            def render_image(command, **kwargs):
                Path(command[-1]).write_bytes(b'image fixture')
            with patch.object(art.subprocess, 'run', side_effect=render_image) as run:
                art.render(root, mod, 'EN', 'ffmpeg')
                art.render(root, mod, 'EN', 'ffmpeg')
                filters=run.call_args.args[0]
                self.assertIn("text='English (US)'", filters[filters.index('-filter_complex')+1])
            for directory in (mod, mod / '42'):
                self.assertEqual((directory/'mod.info').read_text().count('icon='), 1)
                self.assertIn('icon=icon.png', (directory/'mod.info').read_text())
        self.assertEqual(art.flag_code('EN'), 'us')

    def test_picker_languages_have_real_bundled_flags(self):
        import workshop_artwork as art
        codes = art.available_flag_languages()
        for code in ('UZ', 'TT', 'TK', 'TG'):
            self.assertIn(code, codes)
        neutral = (art.ARTWORK / 'neutral.png').read_bytes()
        for code in codes:
            self.assertNotEqual(art.flag_image(code), neutral, code)
