$ErrorActionPreference = "Stop"

# Usage from PowerShell: allow scripts for this shell process, then dot-source:
# Set-ExecutionPolicy -Scope Process Bypass -Force
# . .\scripts\dev-env.ps1

$toolchainRoot = "C:\Users\Public\GuideRunToolchains"
$flutterRoot = Join-Path $toolchainRoot "flutter"
$flutterBin = Join-Path $flutterRoot "bin"
$androidHome = Join-Path $toolchainRoot "android-sdk"
$androidCmdlineTools = Join-Path $androidHome "cmdline-tools\latest\bin"
$androidPlatformTools = Join-Path $androidHome "platform-tools"
$cargoHome = Join-Path $toolchainRoot "cargo"
$rustupHome = Join-Path $toolchainRoot "rustup"
$cargoBin = Join-Path $cargoHome "bin"
$pubCache = Join-Path $toolchainRoot "pub-cache"

$env:FLUTTER_ROOT = $flutterRoot
$env:PUB_CACHE = $pubCache
$env:ANDROID_HOME = $androidHome
$env:ANDROID_SDK_ROOT = $androidHome
$env:CARGO_HOME = $cargoHome
$env:RUSTUP_HOME = $rustupHome

$existingPaths = @($env:Path -split ";" | Where-Object { $_ })
$prependPaths = @(
    $flutterBin,
    $androidCmdlineTools,
    $androidPlatformTools,
    $cargoBin
) | Where-Object {
    (Test-Path $_) -and ($existingPaths -notcontains $_)
}

if ($prependPaths.Count -gt 0) {
    $env:Path = (@($prependPaths) + $existingPaths) -join ";"
}

Write-Host "Flutter, Dart, Android SDK, and Cargo paths are configured for this PowerShell session."
