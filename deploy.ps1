# LeaveX Admin – Deploy Script
# Run this script every time you want to deploy a new version.
# It automatically bumps the version in the Service Worker,
# builds the Flutter web app, and (optionally) deploys to Firebase Hosting.

param(
    [switch]$Deploy  # Pass -Deploy flag to also run firebase deploy
)

# ─────────────────────────────────────────────
# 1. BUMP VERSION (date-based: YYYY.MM.DD.BUILD)
# ─────────────────────────────────────────────
$today = Get-Date -Format "yyyy.MM.dd"
$swFile = "web/flutter_service_worker.js"
$content = Get-Content $swFile -Raw

# Find existing build number for today
$pattern = "leavex-admin-v$today\.(\d+)"
if ($content -match $pattern) {
    $buildNum = [int]$Matches[1] + 1
}
else {
    $buildNum = 1
}

$newVersion = "$today.$buildNum"
$newCacheName = "leavex-admin-v$newVersion"

# Replace old cache name
$content = $content -replace "leavex-admin-v[\d.]+", $newCacheName
$content = $content -replace "Version: [\d.]+", "Version: $newVersion"
Set-Content -Path $swFile -Value $content -Encoding UTF8

Write-Host "✅ Service Worker updated to version: $newVersion" -ForegroundColor Green

# ─────────────────────────────────────────────
# 2. BUILD FLUTTER WEB (Release)
# ─────────────────────────────────────────────
Write-Host "`n🏗  Building Flutter Web..." -ForegroundColor Cyan
flutter build web --release --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Build successful!" -ForegroundColor Green

# ─────────────────────────────────────────────
# 3. DEPLOY TO FIREBASE HOSTING (optional)
# ─────────────────────────────────────────────
if ($Deploy) {
    Write-Host "`n🚀 Deploying to Firebase Hosting..." -ForegroundColor Cyan
    firebase deploy --only hosting

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Firebase deploy failed!" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Deployed version $newVersion to Firebase Hosting!" -ForegroundColor Green
}
else {
    Write-Host "`n💡 Tip: Run 'flutter build web --release' and then 'firebase deploy --only hosting'" -ForegroundColor Yellow
    Write-Host "    Or rerun this script with: .\deploy.ps1 -Deploy" -ForegroundColor Yellow
}

Write-Host "`n🎉 Done! Version $newVersion is ready." -ForegroundColor Magenta
