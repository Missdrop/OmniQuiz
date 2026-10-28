# Builds a Store-only flavor, stages runtime/resources, and validates an unsigned upload without publishing it.

param([string]$Version = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $identity = Get-Content 'packaging/windows/store.json' -Raw | ConvertFrom-Json
    if (!$Version) {
        $text = Get-Content 'pubspec.yaml' -Raw
        if ($text -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)') { throw 'Missing application version.' }
        $Version = $Matches[1] + '.0'
    }
    if ($Version -notmatch '^\d+\.\d+\.\d+\.0$' -or @($Version.Split('.') | Where-Object { [int]$_ -gt 65535 }).Count) {
        throw 'Store version must have four numeric parts up to 65535, ending in .0.'
    }
    $sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin'
    $sdk = Get-ChildItem $sdkRoot -Directory | Where-Object { $_.Name -match '^10\.' -and (Test-Path (Join-Path $_.FullName 'x64/makeappx.exe')) } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if (!$sdk) { throw 'Windows 10/11 SDK with MakeAppx and MakePRI is required.' }
    $appVersion = ($Version.Split('.')[0..2] -join '.')
    & "$PSScriptRoot/flutter.ps1" build windows --release --dart-define=OMNIQUIZ_STORE=true --build-number=0 --build-name=$appVersion
    if ($LASTEXITCODE) { throw 'Store build failed.' }
    # A new staging folder for each run prevents accidentally shipping stale files.
    $stage = Join-Path $root ('.tooling/msix-stage-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Copy-Item 'build/windows/x64/runner/Release/*' $stage -Recurse
    # Include the redistributable runtime from Visual Studio, not system DLLs.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    $visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$visualStudio) { throw 'Visual Studio C++ redistributables are required.' }
    $redist = Get-ChildItem (Join-Path $visualStudio 'VC/Redist/MSVC') -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+(\.\d+)?$' } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if (!$redist) { throw 'Missing versioned Visual C++ redistributable directory.' }
    $crt = Get-ChildItem (Join-Path $redist.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' | Select-Object -First 1
    if (!$crt) { throw 'Missing x64 Visual C++ redistributable runtime.' }
    Copy-Item (Join-Path $crt.FullName '*.dll') $stage -Force
    foreach ($file in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        if (!(Test-Path (Join-Path $stage $file))) { throw "Missing $file" }
    }
    Copy-Item 'packaging/windows/Strings' $stage -Recurse
    [xml]$manifest = Get-Content 'packaging/windows/AppxManifest.xml'
    $manifest.Package.Identity.Name = $identity.identityName
    $manifest.Package.Identity.Publisher = $identity.publisher
    $manifest.Package.Identity.Version = $Version
    $manifest.Package.Properties.PublisherDisplayName = $identity.publisherDisplayName
    $manifestPath = Join-Path $stage 'AppxManifest.xml'
    $manifest.Save($manifestPath)
    # Generate package-scale icons from the existing app logo without redesigning it.
    Add-Type -AssemblyName System.Drawing
    $source = [Drawing.Image]::FromFile((Join-Path $root 'assets/branding/logo.png'))
    try {
        $assets = Join-Path $stage 'Assets'
        New-Item -ItemType Directory -Path $assets -Force | Out-Null
        foreach ($item in @(@('StoreLogo',50), @('Square44x44Logo',44), @('Square150x150Logo',150))) {
            $size = [int]$item[1]
            $image = New-Object Drawing.Bitmap($size, $size)
            $canvas = [Drawing.Graphics]::FromImage($image)
            try {
                $canvas.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $canvas.DrawImage($source, 0, 0, $size, $size)
                $image.Save((Join-Path $assets ($item[0] + '.png')), [Drawing.Imaging.ImageFormat]::Png)
            } finally { $canvas.Dispose(); $image.Dispose() }
        }
    } finally { $source.Dispose() }
    $config = Join-Path $stage 'priconfig.xml'
    & (Join-Path $sdk.FullName 'x64/makepri.exe') createconfig /cf $config /dq en-US /o
    if ($LASTEXITCODE) { throw 'MakePRI configuration failed.' }
    & (Join-Path $sdk.FullName 'x64/makepri.exe') new /pr $stage /cf $config /of (Join-Path $stage 'resources.pri') /o
    if ($LASTEXITCODE) { throw 'MakePRI resource indexing failed.' }
    Remove-Item -LiteralPath $config
    $dist = Join-Path $root 'dist'
    New-Item -ItemType Directory -Path $dist -Force | Out-Null
    $output = Join-Path $dist "OmniQuiz-store-x64-$Version.msix"
    & (Join-Path $sdk.FullName 'x64/makeappx.exe') pack /d $stage /p $output /o
    if ($LASTEXITCODE) { throw 'MakeAppx package validation failed.' }
    [IO.File]::WriteAllText((Join-Path $root '.tooling/store-package.json'), (@{
        package = $output; stage = $stage; version = $Version; family = $identity.packageFamilyName
    } | ConvertTo-Json))
    Write-Host "Store upload package: $output"
    Write-Host "Unsigned for Microsoft Store submission; not a sideload installer. Staging: $stage"
} finally { Pop-Location }
