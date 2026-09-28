# Install Language APK on fogona via Windows adb.
param(
  [string]$Serial = "ZL8326G8ND",
  [string]$Apk = "C:\Users\dylan\work\star_learner\tmp\com.dylan.language_explorer.apk",
  [string]$Adb = "C:\Users\dylan\work\system\platform-tools\adb.exe",
  [string]$Pkg = "com.dylan.language_explorer"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Adb)) { throw "missing adb: $Adb" }
if (-not (Test-Path $Apk)) { throw "missing apk: $Apk" }

$state = & $Adb -s $Serial get-state
if ($state -ne "device") { throw "fogona not ready: $state (plug USB on 245?)" }

Write-Host "Installing $Apk on $Serial ..."
& $Adb -s $Serial install --no-streaming -r -g $Apk
if ($LASTEXITCODE -ne 0) { throw "adb install failed ($LASTEXITCODE)" }

& $Adb -s $Serial shell pm grant $Pkg android.permission.RECORD_AUDIO 2>$null

$remote = ((& $Adb -s $Serial shell pm path $Pkg | Select-Object -First 1) -replace "package:","" -replace "`r","")
$tmp = Join-Path $env:TEMP "lang_installed.apk"
& $Adb -s $Serial pull $remote $tmp | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($tmp)
try {
  $e = $zip.GetEntry("assets/data/hub_client.json")
  $sr = New-Object System.IO.StreamReader($e.Open())
  Write-Host ($sr.ReadToEnd())
  $sr.Close()
} finally { $zip.Dispose() }
Write-Host "FOGONA LANGUAGE OK serial=$Serial"
