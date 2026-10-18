"""Package native builds without losing Unix permissions or app symlinks."""
import pathlib
import shutil
import sys
import tarfile


def package(target):
    destination = pathlib.Path('dist')
    destination.mkdir(exist_ok=True)
    if target == 'android':
        shutil.copyfile('build/app/outputs/flutter-apk/app-debug.apk',
                        destination / 'OmniQuiz-android-debug.apk')
    elif target == 'windows':
        shutil.make_archive(str(destination / 'OmniQuiz-windows-x64'), 'zip',
                            'build/windows/x64/runner/Release')
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


if __name__ == '__main__':
    package(sys.argv[1])
