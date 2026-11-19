# Verifies the desktop port is buildable on Windows.
#
# Usage:  powershell -ExecutionPolicy Bypass -File tool\verify.ps1 [-Build]
#
# Exit code 0 means: dependencies resolve, analyzer is clean of errors,
# tests pass. With -Build it also produces build\windows\x64\runner\Debug\Echo.exe.

param(
    [switch]$Build
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $candidate = Join-Path $HOME 'flutter\bin'
    if (Test-Path (Join-Path $candidate 'flutter.bat')) {
        $env:PATH = "$candidate;$env:PATH"
    } else {
        throw 'Flutter is not on PATH. Install the SDK or add <flutter>\bin to PATH.'
    }
}

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    Write-Host '== flutter pub get ==' -ForegroundColor Cyan
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'pub get failed' }

    Write-Host '== flutter analyze ==' -ForegroundColor Cyan
    $analyze = flutter analyze 2>&1 | Out-String
    $errors = ($analyze -split "`n") | Where-Object { $_ -match '^\s*error\s+-' }
    if ($errors) {
        $errors | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw "analyzer reported $($errors.Count) error(s)"
    }
    $warnings = ($analyze -split "`n") | Where-Object { $_ -match '^\s*warning\s+-' }
    Write-Host ("analyzer: 0 errors, {0} warnings" -f $warnings.Count) -ForegroundColor Yellow

    Write-Host '== flutter test ==' -ForegroundColor Cyan
    flutter test --reporter compact
    if ($LASTEXITCODE -ne 0) { throw 'tests failed' }

    if ($Build) {
        Write-Host '== flutter build windows --debug ==' -ForegroundColor Cyan
        flutter build windows --debug
        if ($LASTEXITCODE -ne 0) { throw 'windows build failed' }
        Write-Host 'build\windows\x64\runner\Debug\Echo.exe' -ForegroundColor Green
    }

    Write-Host 'OK' -ForegroundColor Green
} finally {
    Pop-Location
}
