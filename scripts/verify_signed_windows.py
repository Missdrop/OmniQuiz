"""Verify returned SignPath packages before replacing unsigned release assets."""
import os
import pathlib
import shutil
import struct
import subprocess
import tempfile
import zipfile


def pe_fields(data):
    if data[:2] != b'MZ' or len(data) < 64:
        raise ValueError('Not a PE executable')
    pe = struct.unpack_from('<I', data, 60)[0]
    if data[pe:pe + 4] != b'PE\0\0':
        raise ValueError('Invalid PE header')
    optional = pe + 24
    magic = struct.unpack_from('<H', data, optional)[0]
    if magic not in (0x10b, 0x20b):
        raise ValueError('Unsupported PE format')
    checksum = optional + 64
    security = optional + (112 if magic == 0x20b else 96) + 32
    if security + 8 > len(data):
        raise ValueError('Truncated PE header')
    return checksum, security


def verify_pe_change(original, signed):
    """Only the checksum, security directory, alignment and certificate may change."""
    checksum, security = pe_fields(original)
    if pe_fields(signed) != (checksum, security):
        raise ValueError('PE layout changed')
    if struct.unpack_from('<II', original, security) != (0, 0):
        raise ValueError('Expected an unsigned build input')
    offset, size = struct.unpack_from('<II', signed, security)
    if (offset != (len(original) + 7) // 8 * 8 or size < 8
            or offset + size != len(signed)
            or any(signed[len(original):offset])):
        raise ValueError('Missing or invalid certificate table')
    expected, actual = bytearray(original), bytearray(signed[:len(original)])
    for start, length in ((checksum, 4), (security, 8)):
        expected[start:start + length] = actual[start:start + length] = b'\0' * length
    if actual != expected:
        raise ValueError('Executable content changed beyond signing fields')


def verify_payload(original, signed):
    if original.keys() != signed.keys():
        raise ValueError('Signed package file list differs from the build')
    for name, data in original.items():
        if name == 'omniquiz.exe':
            verify_pe_change(data, signed[name])
        elif signed[name] != data:
            raise ValueError(f'Unexpected payload change: {name}')


def zip_payload(path):
    with zipfile.ZipFile(path) as archive:
        files = [entry for entry in archive.infolist() if not entry.is_dir()]
        names = [entry.filename for entry in files]
        if len({name.casefold() for name in names}) != len(names):
            raise ValueError('Duplicate archive paths')
        for name in names:
            parts = pathlib.PurePosixPath(name.replace('\\', '/'))
            if parts.is_absolute() or '..' in parts.parts or ':' in name:
                raise ValueError('Unsafe archive path')
        return {entry.filename: archive.read(entry) for entry in files}


def verify_signature(path):
    subprocess.run(['pwsh', '-NoProfile', '-File', 'scripts/verify_authenticode.ps1',
                    '-Path', str(path.resolve())], check=True)


def main():
    signed = pathlib.Path('.tooling/signpath-signed')
    names = {'OmniQuiz-windows-x64.msi', 'OmniQuiz-windows-x64.zip'}
    if {file.name for file in signed.iterdir()} != names:
        raise ValueError('SignPath must return exactly the MSI and portable ZIP')
    source = pathlib.Path('build/windows/x64/runner/Release')
    original = {file.relative_to(source).as_posix(): file.read_bytes()
                for file in source.rglob('*') if file.is_file()}
    portable = zip_payload(signed / 'OmniQuiz-windows-x64.zip')
    verify_payload(original, portable)
    verify_signature(signed / 'OmniQuiz-windows-x64.msi')
    with tempfile.TemporaryDirectory(prefix='omniquiz-signed-') as temporary:
        root = pathlib.Path(temporary)
        portable_exe = root / 'portable.exe'
        portable_exe.write_bytes(portable['omniquiz.exe'])
        verify_signature(portable_exe)
        installed = root / 'installed'
        installed.mkdir()
        subprocess.run(['msiexec.exe', '/a', str((signed / 'OmniQuiz-windows-x64.msi').resolve()),
                        '/qn', f'TARGETDIR={installed}', '/L*v', str(root / 'extract.log')], check=True)
        executables = list(installed.rglob('omniquiz.exe'))
        if len(executables) != 1:
            raise ValueError('MSI must contain exactly one application executable')
        bundle = executables[0].parent
        payload = {file.relative_to(bundle).as_posix(): file.read_bytes()
                   for file in bundle.rglob('*') if file.is_file()}
        verify_payload(original, payload)
        verify_signature(executables[0])
    # No publication asset changes until every verification has succeeded.
    for name in names:
        shutil.copyfile(signed / name, pathlib.Path('dist') / name)
    os.environ['OMNIQUIZ_WINDOWS_SIGNED'] = 'true'
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as output:
        output.write('OMNIQUIZ_WINDOWS_SIGNED=true\n')
    print('Verified signed MSI and portable ZIP, including both embedded applications.')


if __name__ == '__main__':
    main()
