# Runs the pinned Dart binary under the same isolated caches as Flutter.

. "$PSScriptRoot/environment.ps1"
$sdkCommand = Join-Path $projectRoot '.tooling/flutter/bin/dart.bat'
if (!(Test-Path $sdkCommand)) { throw 'Run scripts/bootstrap.ps1 first.' }
& $sdkCommand @args
exit $LASTEXITCODE
