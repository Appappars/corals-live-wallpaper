# Corals - live wallpaper for Lively Wallpaper
# One-command installer: installs Lively (winget), copies the wallpaper into the
# Lively library and applies it to every screen.
#
# Usage (from README):
#     irm https://raw.githubusercontent.com/Appappars/corals-live-wallpaper/main/install.ps1 | iex
#
# Options:
#     -LibraryPath <dir>   override the Lively wallpapers folder
#     -SkipLively          do not try to install Lively, only the wallpaper
#     -NoApply             install files only, do not set the wallpaper
#     -DryRun              print what would happen, change nothing

[CmdletBinding()]
param(
    [string]$LibraryPath,
    [switch]$SkipLively,
    [switch]$NoApply,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$Repo      = 'Appappars/corals-live-wallpaper'
$ZipUrl    = "https://github.com/$Repo/releases/latest/download/corals.zip"
$LivelyUrl = 'https://www.rocksdanister.com/lively/'
$StoreLib  = Join-Path $env:LOCALAPPDATA 'Packages\12030rocksdanister.LivelyWallpaper_97hta09mmv6hy\LocalCache\Local\Lively Wallpaper\Library\wallpapers'
$UserLib   = Join-Path $env:LOCALAPPDATA 'Lively Wallpaper\Library\wallpapers'

function Write-Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "    $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "    $text" -ForegroundColor Yellow }

function Find-Lively {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Lively Wallpaper\Lively.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Lively Wallpaper\Lively.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Lively Wallpaper\Lively.exe'),
        (Join-Path $env:LOCALAPPDATA 'Lively Wallpaper\Lively.exe')
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($candidates) { return @($candidates)[0] }

    foreach ($hive in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                      'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*') {
        $app = Get-ItemProperty $hive -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -match 'Lively' -and $_.InstallLocation } |
               Select-Object -First 1
        if ($app) {
            $exe = Join-Path $app.InstallLocation 'Lively.exe'
            if (Test-Path $exe) { return $exe }
        }
    }

    $cmd = Get-Command 'Lively.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Install-LivelyViaWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    Write-Step 'Installing Lively Wallpaper via winget (a UAC prompt may appear)'
    & winget install --id rocksdanister.LivelyWallpaper --exact --source winget `
        --accept-package-agreements --accept-source-agreements --silent
    # 0 = ok, -1978335189 = already installed
    return $true
}

Write-Host ''
Write-Host '   ____                 _' -ForegroundColor DarkGray
Write-Host '  / ___|___  _ __ __ _| |___' -ForegroundColor DarkGray
Write-Host ' | |   / _ \| ''__/ _` | / __|' -ForegroundColor DarkGray
Write-Host ' | |__| (_) | | | (_| | \__ \' -ForegroundColor DarkGray
Write-Host '  \____\___/|_|  \__,_|_|___/' -ForegroundColor DarkGray
Write-Host ''
Write-Host ' Corals - live wallpaper for Lively Wallpaper' -ForegroundColor Gray
Write-Host ''

# ---- 1. Lively itself -------------------------------------------------------
$lively = Find-Lively
if (-not $lively -and -not $SkipLively) {
    Install-LivelyViaWinget | Out-Null
    $lively = Find-Lively
}
if (-not $lively -and -not $SkipLively) {
    Write-Warn 'Lively Wallpaper was not found and could not be installed automatically.'
    Write-Warn "Please install it manually: $LivelyUrl"
    Write-Warn 'Then run this script again.'
    if (-not $DryRun) { exit 1 }
}
if ($lively) { Write-Step "Lively: $lively" } else { Write-Warn 'Lively not found - installing wallpaper files only.' }

# ---- 2. Library path --------------------------------------------------------
if (-not $LibraryPath) {
    if (Test-Path $StoreLib) {
        $LibraryPath = $StoreLib
        Write-Warn 'Microsoft Store edition detected - using its library folder.'
    } else {
        $LibraryPath = $UserLib
    }
}
$dest = Join-Path $LibraryPath 'corals'
Write-Step "Library folder: $dest"

# ---- 3. Download ------------------------------------------------------------
$tmpZip = Join-Path $env:TEMP ("corals-" + [guid]::NewGuid().ToString('n') + ".zip")
Write-Step 'Downloading the wallpaper from GitHub'
Write-Ok $ZipUrl
if ($DryRun) { Write-Warn '[dry-run] skipping download and extraction'; exit 0 }

Invoke-WebRequest -Uri $ZipUrl -OutFile $tmpZip -UseBasicParsing
Write-Ok ("downloaded {0:N1} MB" -f ((Get-Item $tmpZip).Length / 1MB))

# ---- 4. Install into the library -------------------------------------------
Write-Step 'Unpacking into the Lively library'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$tmpDir = Join-Path $env:TEMP ("corals-" + [guid]::NewGuid().ToString('n'))
Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force
Copy-Item (Join-Path $tmpDir '*') $dest -Recurse -Force
Remove-Item $tmpZip, $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

foreach ($need in 'corals.html', 'LivelyInfo.json') {
    if (-not (Test-Path (Join-Path $dest $need))) { throw "Missing $need in $dest after unpacking" }
}
Write-Ok "done: $dest"

# ---- 5. Apply ---------------------------------------------------------------
if ($NoApply) {
    Write-Step 'Done. Open Lively and click the "Corals - live wallpaper" tile.'
    exit 0
}

if ($lively) {
    Write-Step 'Applying the wallpaper'
    $running = Get-Process -Name 'Lively' -ErrorAction SilentlyContinue
    if (-not $running) {
        Start-Process -FilePath $lively
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Milliseconds 500
            if (Get-Process -Name 'Lively' -ErrorAction SilentlyContinue) { break }
        }
        Start-Sleep -Seconds 3
    }

    & $lively setwp --file $dest     2>$null | Out-Null
    & $lively --layout duplicate     2>$null | Out-Null

    Write-Ok 'Wallpaper is now running on every screen.'
} else {
    Write-Ok 'Files are in place: open Lively and click the "Corals - live wallpaper" tile.'
}

Write-Host ''
Write-Host ' What next:' -ForegroundColor Gray
Write-Host '   * settings panel - the sliders icon in the top-right corner, Esc closes it;' -ForegroundColor Gray
Write-Host '   * mouse wheel changes the recipe, R reseeds, click gives a growth burst.' -ForegroundColor Gray