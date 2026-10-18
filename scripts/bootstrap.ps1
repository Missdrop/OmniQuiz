. "$PSScriptRoot/environment.ps1"
$sdk = Join-Path $projectRoot '.tooling/flutter'
if (!(Test-Path (Join-Path $sdk 'bin/flutter.bat'))) {
    New-Item -ItemType Directory -Force (Join-Path $projectRoot '.tooling') | Out-Null
    & git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git $sdk
    if ($LASTEXITCODE -ne 0) { throw 'Flutter SDK download failed.' }
}
Push-Location $projectRoot
try {
    & (Join-Path $sdk 'bin/flutter.bat') pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed.' }
} finally { Pop-Location }
