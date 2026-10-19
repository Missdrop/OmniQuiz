"""Manage private Android signing files without printing secrets or committing keys."""
import argparse
import base64
import json
import os
from pathlib import Path
import secrets
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SIGNING = ROOT / '.tooling' / 'android-signing'


def create():
    """Generate once; an existing release identity must never be overwritten."""
    SIGNING.mkdir(parents=True, exist_ok=True, mode=0o700)
    keystore = SIGNING / 'release.p12'
    if keystore.exists() or (ROOT / 'android' / 'key.properties').exists():
        raise SystemExit('Signing key already exists; reuse it instead of generating another.')
    password = secrets.token_urlsafe(36)
    environment = dict(os.environ, OMNIQUIZ_SIGN_PASSWORD=password)
    subprocess.run([
        'keytool', '-genkeypair', '-noprompt', '-storetype', 'PKCS12',
        '-alias', 'omniquiz', '-keyalg', 'RSA', '-keysize', '3072',
        '-validity', '10000', '-dname', 'CN=OmniQuiz, O=OmniQuiz',
        '-keystore', str(keystore), '-storepass:env', 'OMNIQUIZ_SIGN_PASSWORD',
        '-keypass:env', 'OMNIQUIZ_SIGN_PASSWORD',
    ], env=environment, check=True, capture_output=True)
    configuration = {
        'ANDROID_KEYSTORE_BASE64': base64.b64encode(keystore.read_bytes()).decode('ascii'),
        'ANDROID_STORE_PASSWORD': password,
        'ANDROID_KEY_PASSWORD': password,
        'ANDROID_KEY_ALIAS': 'omniquiz',
    }
    private = SIGNING / 'github-secrets.json'
    private.write_text(json.dumps(configuration, indent=2), encoding='utf-8')
    properties = SIGNING / 'key.properties'
    properties.write_text(
        f'storeFile=../.tooling/android-signing/release.p12\nstoreType=PKCS12\n'
        f'storePassword={password}\nkeyPassword={password}\nkeyAlias=omniquiz\n',
        encoding='utf-8')
    (ROOT / 'android' / 'key.properties').write_bytes(properties.read_bytes())
    package = SIGNING / 'OmniQuiz-android-signing-private.zip'
    with zipfile.ZipFile(package, 'w', zipfile.ZIP_DEFLATED) as archive:
        for file in (keystore, private, properties):
            archive.write(file, file.name)
    for file in (keystore, private, properties, package, ROOT / 'android' / 'key.properties'):
        file.chmod(0o600)
    print(f'Private signing package created: {package}')


def prepare_ci():
    """Decode repository secrets only on trusted builds; missing keys fail closed."""
    required = ('ANDROID_KEYSTORE_BASE64', 'ANDROID_STORE_PASSWORD',
                'ANDROID_KEY_PASSWORD', 'ANDROID_KEY_ALIAS')
    if any(not os.environ.get(name) for name in required):
        raise SystemExit('Configure the four Android signing repository secrets before publishing.')
    SIGNING.mkdir(parents=True, exist_ok=True, mode=0o700)
    keystore = SIGNING / 'ci-release.p12'
    keystore.write_bytes(base64.b64decode(os.environ[required[0]], validate=True))
    keystore.chmod(0o600)
    # Only the path is emitted; passwords stay in GitHub's masked secret values.
    with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as output:
        output.write(f'ANDROID_KEYSTORE_PATH={keystore}\n')


def install_secrets():
    """Run from an authenticated maintainer machine; never show secret values."""
    configuration = json.loads((SIGNING / 'github-secrets.json').read_text(encoding='utf-8'))
    for name, value in configuration.items():
        subprocess.run(['gh', 'secret', 'set', name, '--repo', 'Missdrop/OmniQuiz'],
                       input=value, text=True, check=True, capture_output=True)
    print('Android signing repository secrets configured.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('create', 'prepare-ci', 'install-secrets'))
    options = parser.parse_args()
    {'create': create, 'prepare-ci': prepare_ci, 'install-secrets': install_secrets}[options.action]()
