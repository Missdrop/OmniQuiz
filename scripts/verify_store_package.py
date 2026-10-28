"""Validate the unsigned Store upload and its staged release payload."""
import json
import pathlib
import sys
import xml.etree.ElementTree as ET
import zipfile


def verify(package, stage):
    """Check Store identity, release payload and privacy assets without installing or publishing the package."""
    identity = json.loads(pathlib.Path('packaging/windows/store.json').read_text())
    ns = {'p': 'http://schemas.microsoft.com/appx/manifest/foundation/windows10',
          'r': 'http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities'}
    with zipfile.ZipFile(package) as archive:
        assert archive.testzip() is None, 'Archive CRC failed'
        names = set(archive.namelist())
        assert 'AppxSignature.p7x' not in names, 'Upload package should be unsigned'
        manifest = ET.fromstring(archive.read('AppxManifest.xml'))
        item = manifest.find('p:Identity', ns)
        assert item.attrib['Name'] == identity['identityName']
        assert item.attrib['Publisher'] == identity['publisher']
        assert item.attrib['ProcessorArchitecture'] == 'x64'
        assert item.attrib['Version'].split('.')[-1] == '0'
        assert manifest.find('p:Properties/p:PublisherDisplayName', ns).text == identity['publisherDisplayName']
        assert manifest.find('p:Dependencies/p:TargetDeviceFamily', ns).attrib['Name'] == 'Windows.Desktop'
        assert manifest.find('p:Applications/p:Application', ns).attrib['EntryPoint'] == 'Windows.FullTrustApplication'
        assert manifest.find('p:Capabilities/r:Capability', ns).attrib['Name'] == 'runFullTrust'
        for required in ['omniquiz.exe', 'flutter_windows.dll', 'sqlite3.dll', 'pdfium.dll',
                         'vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll',
                         'data/app.so', 'data/icudtl.dat', 'resources.pri',
                         'data/flutter_assets/assets/legal/privacy_en.txt',
                         'data/flutter_assets/assets/legal/privacy_zh.txt',
                         'data/flutter_assets/assets/fonts/NotoSansSC.ttf',
                         'data/flutter_assets/assets/fonts/OFL.txt']:
            assert required in names, f'Missing {required}'
        for name in names:
            path = pathlib.PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts
            assert path.suffix.lower() not in {'.pdb', '.pfx', '.jks', '.keystore', '.sqlite', '.db'}
            assert 'kernel_blob.bin' not in name, 'Debug Dart payload in release'
        count = 0
        for file in pathlib.Path(stage).rglob('*'):
            if file.is_file():
                relative = file.relative_to(stage).as_posix()
                assert file.read_bytes() == archive.read(relative), f'Payload mismatch: {relative}'
                count += 1
        for language in ['en', 'zh']:
            value = archive.read(f'data/flutter_assets/assets/legal/privacy_{language}.txt').decode()
            assert 'Missdrop' in value and 'https://github.com/Missdrop/OmniQuiz/issues' in value
    print(f'Verified {count} staged files, Store identity, x64 release, privacy assets and unsigned MSIX.')


if __name__ == '__main__':
    metadata = json.loads(pathlib.Path('.tooling/store-package.json').read_text())
    verify(sys.argv[1] if len(sys.argv) > 1 else metadata['package'], metadata['stage'])
