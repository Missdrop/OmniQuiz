import contextlib
import os
import pathlib
import tempfile
import unittest
import xml.etree.ElementTree as ET
from unittest.mock import patch

from package_release import app_version, windows_manifest, macos_dmg, wix_executable


class PackagingTests(unittest.TestCase):
    def test_legacy_wix_environment_does_not_override_project_executable(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            legacy = pathlib.Path('WiX Toolset v3.14')
            legacy.mkdir()
            tool = pathlib.Path('.tooling/wix/wix.exe')
            tool.parent.mkdir(parents=True)
            tool.write_bytes(b'project tool')
            with patch.dict(os.environ, {'WIX': str(legacy.resolve())}):
                self.assertEqual(wix_executable(), str(tool.resolve()))

    def test_missing_or_directory_wix_path_reports_setup_error(self):
        with tempfile.TemporaryDirectory() as directory, contextlib.chdir(directory):
            tool = pathlib.Path('.tooling/wix/wix.exe')
            for directory_exists in (False, True):
                if directory_exists:
                    tool.mkdir(parents=True)
                with self.assertRaisesRegex(FileNotFoundError, 'Install WiX 5.0.2'):
                    wix_executable()

    def test_manifest_contains_nested_assets_with_stable_component_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            source = root / 'app'
            (source / 'data/flutter_assets').mkdir(parents=True)
            (source / 'omniquiz.exe').write_bytes(b'executable')
            (source / 'data/flutter_assets/logo.png').write_bytes(b'logo')
            manifest = root / 'Files.wxs'
            windows_manifest(source, manifest)
            ns = {'w': 'http://wixtoolset.org/schemas/v4/wxs'}
            first = ET.parse(manifest)
            files = first.findall('.//w:File', ns)
            self.assertEqual({pathlib.Path(f.attrib['Source']).name for f in files}, {'omniquiz.exe', 'logo.png'})
            original_ids = {f.attrib['Source']: f.attrib['Id'] for f in files}
            (source / 'new.dll').write_bytes(b'new')
            windows_manifest(source, manifest)
            updated = {f.attrib['Source']: f.attrib['Id'] for f in ET.parse(manifest).findall('.//w:File', ns)}
            for source_file, identifier in original_ids.items():
                self.assertEqual(updated[source_file], identifier)
            components = first.findall('.//w:Component', ns)
            refs = first.findall('.//w:ComponentRef', ns)
            self.assertEqual({c.attrib['Id'] for c in components}, {r.attrib['Id'] for r in refs})

    def test_version_uses_three_fields_and_enforces_msi_limits(self):
        for text, expected in [('version: 1.2.3+99', '1.2.3'), ('version: 255.255.65535', '255.255.65535')]:
            with patch.object(pathlib.Path, 'read_text', return_value=text):
                self.assertEqual(app_version(), expected)
        for text in ('version: 256.0.0', 'version: 1.2.65536', 'version: invalid'):
            with patch.object(pathlib.Path, 'read_text', return_value=text):
                with self.assertRaises(ValueError):
                    app_version()

    def test_dmg_stages_app_and_applications_link_then_verifies_image(self):
        calls = []
        def run(args, **kwargs):
            calls.append(args)
            if args[:2] == ['hdiutil', 'create']:
                staging = pathlib.Path(args[args.index('-srcfolder') + 1])
                self.assertTrue((staging / 'LICENSE.txt').is_file())
                self.assertTrue((staging / 'Applications').is_symlink())
        with patch('package_release.subprocess.run', side_effect=run):
            with patch.object(pathlib.Path, 'symlink_to') as symlink:
                with patch.object(pathlib.Path, 'is_symlink', return_value=True):
                    macos_dmg('OmniQuiz.app', pathlib.Path('dist'))
            symlink.assert_called_once_with('/Applications')
        self.assertEqual(calls[0][0], 'ditto')
        self.assertEqual(calls[-1], ['hdiutil', 'verify', str(pathlib.Path('dist/OmniQuiz-macos.dmg'))])


if __name__ == '__main__':
    unittest.main()
