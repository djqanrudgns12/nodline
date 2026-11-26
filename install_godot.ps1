$ErrorActionPreference = "Stop"

$installDir = Join-Path $env:LOCALAPPDATA "Programs\Godot"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

$zipPath = Join-Path $installDir "godot.zip"
$godotExeTarget = Join-Path $installDir "godot.exe"

# If already downloaded and exists, skip
if (Test-Path $godotExeTarget) {
    Write-Host "Godot is already installed at: $godotExeTarget"
    exit 0
}

$url = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip"
Write-Host "1. Downloading Godot 4.3 (approx 60MB)..."
Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

Write-Host "2. Extracting files..."
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
Remove-Item $zipPath -Force

$found = Get-ChildItem -Path $installDir -Filter "Godot*.exe" | Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1
if ($found) {
    Copy-Item -Path $found.FullName -Destination $godotExeTarget -Force
}

# Add to user PATH if not present
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir", "User")
    Write-Host "3. Added Godot to User PATH."
}

Write-Host "SUCCESS: Godot is installed at $godotExeTarget"
