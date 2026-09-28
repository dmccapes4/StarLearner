# Ensure Google platform-tools (adb) exist under work\system.
# Run on 245 Windows: powershell -ExecutionPolicy Bypass -File ...
$ErrorActionPreference = "Stop"
$root = "C:\Users\dylan\work\system"
$dest = Join-Path $root "platform-tools"
$adb = Join-Path $dest "adb.exe"
$zip = Join-Path $root "platform-tools-win.zip"
$uri = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

New-Item -ItemType Directory -Force -Path $root | Out-Null
if (Test-Path $adb) {
  Write-Host "OK $adb"
  & $adb version
  exit 0
}

Write-Host "Downloading platform-tools..."
Invoke-WebRequest -Uri $uri -OutFile $zip
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Expand-Archive -Path $zip -DestinationPath $root -Force
if (-not (Test-Path $adb)) { throw "adb missing after extract" }
Write-Host "Installed $adb"
& $adb version
