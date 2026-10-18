$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$env:PUB_CACHE = Join-Path $projectRoot '.tooling/pub-cache'
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.tooling/gradle'
$env:ANDROID_HOME = Join-Path $projectRoot '.tooling/android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = Join-Path $projectRoot '.tooling/android-user'
$env:ANDROID_EMULATOR_HOME = Join-Path $projectRoot '.tooling/android-emulator'
$env:XDG_CONFIG_HOME = Join-Path $projectRoot '.tooling/config'
$env:XDG_CACHE_HOME = Join-Path $projectRoot '.tooling/cache'
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$localJdk = Join-Path $projectRoot '.tooling/jdk'
if (Test-Path (Join-Path $localJdk 'bin/java.exe')) {
    $env:JAVA_HOME = $localJdk
    $env:PATH = "$localJdk\bin;$env:PATH"
}
