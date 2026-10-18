"""Package native builds, preserving app symlinks and including desktop installers."""
import hashlib
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import xml.etree.ElementTree as ET


def app_version():
    match = re.search(r'^version:\s*(\d+)\.(\d+)\.(\d+)',
                      pathlib.Path('pubspec.yaml').read_text(), re.M)
    if not match:
        raise ValueError('pubspec.yaml must contain a numeric app version')
    parts = tuple(map(int, match.groups()))
    if any(value > limit for value, limit in zip(parts, (255, 255, 65535))):
        raise ValueError('App version exceeds Windows Installer limits')
    return '.'.join(map(str, parts))


def windows_runtime(source):
    """Bundle the installed VS redistributable DLLs; never copy system DLLs."""
    vswhere = pathlib.Path(os.environ['ProgramFiles(x86)']) / 'Microsoft Visual Studio/Installer/vswhere.exe'
    installation = subprocess.check_output(
        [str(vswhere), '-latest', '-products', '*', '-requires',
         'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property',
         'installationPath'], text=True).strip()
    candidates = list((pathlib.Path(installation) / 'VC/Redist/MSVC').glob('*/x64/Microsoft.VC*.CRT'))
    if not candidates:
        raise FileNotFoundError('Visual Studio x64 C++ redistributable DLLs are required')
    crt = max(candidates, key=lambda p: tuple(map(int, p.parts[-3].split('.'))))
    for file in crt.glob('*.dll'):
        shutil.copy2(file, source / file.name)
    for name in ('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll'):
        if not (source / name).is_file():
            raise FileNotFoundError(f'Missing runtime: {name}')


def windows_manifest(source, output):
    """Stable IDs let MSI track each installed file across upgrades."""
    root = ET.Element('Wix', xmlns='http://wixtoolset.org/schemas/v4/wxs')
    fragment = ET.SubElement(root, 'Fragment')
    directories = {pathlib.Path('.'): ET.SubElement(fragment, 'DirectoryRef', Id='INSTALLFOLDER')}
    group = ET.SubElement(fragment, 'ComponentGroup', Id='AppFiles')
    for file in sorted(source.rglob('*')):
        if not file.is_file():
            continue
        relative = file.relative_to(source)
        for parent in reversed(relative.parents):
            if parent not in directories:
                identifier = 'D' + hashlib.sha256(parent.as_posix().encode()).hexdigest()[:24]
                directories[parent] = ET.SubElement(directories[parent.parent], 'Directory', Id=identifier, Name=parent.name)
        identifier = hashlib.sha256(relative.as_posix().encode()).hexdigest()[:24]
        component = ET.SubElement(directories[relative.parent], 'Component', Id='C' + identifier, Guid='*')
        ET.SubElement(component, 'File', Id='F' + identifier, Source=str(file.resolve()), KeyPath='yes')
        ET.SubElement(group, 'ComponentRef', Id='C' + identifier)
    ET.indent(root)
    ET.ElementTree(root).write(output, encoding='utf-8', xml_declaration=True)


def windows_package(destination):
    source = pathlib.Path('build/windows/x64/runner/Release')
    if not (source / 'omniquiz.exe').is_file():
        raise FileNotFoundError('Build the Windows release first')
    windows_runtime(source)
    shutil.copy2('LICENSE', source / 'LICENSE.txt')
    shutil.make_archive(str(destination / 'OmniQuiz-windows-x64'), 'zip', source)
    work = pathlib.Path('build/installer')
    work.mkdir(parents=True, exist_ok=True)
    manifest = work / 'Files.wxs'
    windows_manifest(source, manifest)
    license_text = pathlib.Path('LICENSE').read_text(encoding='utf-8')
    escaped = license_text.replace('\\', r'\\').replace('{', r'\{').replace('}', r'\}').replace('\n', '\\par\n')
    license_rtf = work / 'License.rtf'
    license_rtf.write_text('{\\rtf1\\ansi\n' + escaped + '}', encoding='ascii')
    wix = os.environ.get('WIX', str(pathlib.Path('.tooling/wix/wix.exe').resolve()))
    subprocess.run([wix, 'build', 'packaging/windows/OmniQuiz.wxs', str(manifest),
                    '-arch', 'x64', '-ext', 'WixToolset.UI.wixext/5.0.2',
                    '-d', f'AppVersion={app_version()}', '-d', f'LicenseRtf={license_rtf.resolve()}',
                    '-pdbtype', 'none', '-o', str(destination / 'OmniQuiz-windows-x64.msi')], check=True)


def macos_dmg(source, destination):
    with tempfile.TemporaryDirectory(prefix='omniquiz-dmg-') as temporary:
        staging = pathlib.Path(temporary)
        subprocess.run(['ditto', str(source), str(staging / 'OmniQuiz.app')], check=True)
        (staging / 'Applications').symlink_to('/Applications')
        shutil.copy2('LICENSE', staging / 'LICENSE.txt')
        image = destination / 'OmniQuiz-macos.dmg'
        subprocess.run(['hdiutil', 'create', '-volname', 'OmniQuiz', '-srcfolder',
                        str(staging), '-format', 'UDZO', '-ov', str(image)], check=True)
        subprocess.run(['hdiutil', 'verify', str(image)], check=True)


def package(target):
    destination = pathlib.Path('dist')
    destination.mkdir(exist_ok=True)
    if target == 'android':
        shutil.copyfile('build/app/outputs/flutter-apk/app-debug.apk',
                        destination / 'OmniQuiz-android-debug.apk')
    elif target == 'windows':
        windows_package(destination)
    else:
        sources = {
            'linux': ('build/linux/x64/release/bundle', 'OmniQuiz', 'linux-x64'),
            'macos': ('build/macos/Build/Products/Release/OmniQuiz.app',
                      'OmniQuiz.app', 'macos'),
            'ios': ('build/ios/iphoneos/Runner.app', 'Runner.app', 'ios-unsigned'),
        }
        source, name, suffix = sources[target]
        with tarfile.open(destination / f'OmniQuiz-{suffix}.tar.gz', 'w:gz') as archive:
            archive.add(source, arcname=name)
        if target == 'macos':
            macos_dmg(source, destination)


if __name__ == '__main__':
    package(sys.argv[1])
