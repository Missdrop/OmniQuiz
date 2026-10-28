# Runs the pinned Flutter binary under the repository environment and preserves its exit status.

. "$PSScriptRoot/environment.ps1"
$sdkCommand = Join-Path $projectRoot '.tooling/flutter/bin/flutter.bat'
if (!(Test-Path $sdkCommand)) { throw 'Run scripts/bootstrap.ps1 first.' }
& $sdkCommand @args
exit $LASTEXITCODE
