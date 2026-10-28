"""Exercise Windows Installer extraction and verify the complete shipped payload."""
import hashlib
import pathlib
import subprocess
import tempfile


def digest(path):
    """Compare extracted installer payloads byte-for-byte using a streaming-independent content hash."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == '__main__':
    msi = pathlib.Path('dist/OmniQuiz-windows-x64.msi').resolve()
    source = pathlib.Path('build/windows/x64/runner/Release')
    with tempfile.TemporaryDirectory(prefix='omniquiz-msi-') as temporary:
        destination = pathlib.Path(temporary)
        subprocess.run(['msiexec.exe', '/a', str(msi), '/qn',
                        f'TARGETDIR={destination}', '/L*v',
                        str(destination / 'extract.log')], check=True)
        executables = list(destination.rglob('omniquiz.exe'))
        if len(executables) != 1:
            raise RuntimeError('MSI must contain exactly one application executable')
        installed = executables[0].parent
        expected = {p.relative_to(source): digest(p) for p in source.rglob('*') if p.is_file()}
        actual = {p.relative_to(installed): digest(p) for p in installed.rglob('*') if p.is_file()}
        if expected != actual:
            raise RuntimeError('Extracted MSI payload differs from the release build')
        print(f'Windows Installer extracted {len(actual)} files; all SHA-256 hashes match.')
