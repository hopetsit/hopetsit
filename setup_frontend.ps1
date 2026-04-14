# Sprint 6.5 step 5 — one-shot frontend setup + APK build.
# Usage (PowerShell): .\setup_frontend.ps1

$ErrorActionPreference = "Stop"

function Step($label, $cmd) {
    Write-Host "`n============================================================"
    Write-Host "  $label"
    Write-Host "============================================================"
    Invoke-Expression $cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $label" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Push-Location (Join-Path $PSScriptRoot "frontend")

Step "1/3  Check Flutter version"      "flutter --version"
Step "2/3  Fetch dependencies"          "flutter pub get"
Step "3/3  Build release APK"           "flutter build apk --release"

Pop-Location

Write-Host "`nDone. APK available at frontend\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
