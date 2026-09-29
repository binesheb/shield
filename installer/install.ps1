# SHIELD PowerShell installer
# Examples:
#   irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1))) -Mode Live
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1))) -Mode Service
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1))) -Mode Application

param(
  [ValidateSet('Live','Service','Application')]
  [string]$Mode = 'Application'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = 'binesheb/shield'
$Version = if ($env:SHIELD_VERSION) { $env:SHIELD_VERSION } else { 'main' }
$InstallDir = if ($env:SHIELD_INSTALL_DIR) { $env:SHIELD_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'SHIELD\bin' }

Write-Host "[SHIELD] Mode: $Mode"
Write-Host "[SHIELD] Installing SHIELD for Windows..."

$TempDir = Join-Path $env:TEMP ('shield-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
  if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'Rust/Cargo is not installed. The current source installer requires Rust. Signed binary installation will be added with release artifacts.'
  }
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is not installed.'
  }

  $SourceDir = Join-Path $TempDir 'source'
  $Branch = if ($Version -eq 'main') { 'main' } else { $Version }

  git clone --depth 1 --branch $Branch ('https://github.com/' + $Repo + '.git') $SourceDir

  Push-Location $SourceDir
  try {
    cargo build --release
  } finally {
    Pop-Location
  }

  $Binary = Join-Path $SourceDir 'target\release\shield.exe'
  if (-not (Test-Path $Binary)) {
    throw 'Build completed but shield.exe was not found.'
  }

  if ($Mode -eq 'Live') {
    Write-Host '[SHIELD] Live mode: binary will run from the temporary build.'
    & $Binary status
    Write-Host ''
    Write-Host '[SHIELD] Live mode does not install a persistent service or application.'
    exit $LASTEXITCODE
  }

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  $InstalledBinary = Join-Path $InstallDir 'shield.exe'
  Copy-Item $Binary $InstalledBinary -Force

  $UserPath = [Environment]::GetEnvironmentVariable('Path','User')
  $Entries = @()
  if ($UserPath) {
    $Entries = $UserPath -split ';' | Where-Object { $_ }
  }
  if ($Entries -notcontains $InstallDir) {
    [Environment]::SetEnvironmentVariable('Path', (($Entries + $InstallDir) -join ';'), 'User')
  }

  if ($Mode -eq 'Service') {
    Write-Host '[SHIELD] Service mode selected.'
    Write-Host '[SHIELD] The service registration layer will be enabled when continuous protection is available.'
    Write-Host '[SHIELD] Binary installed; no Windows service has been registered yet.'
  }

  if ($Mode -eq 'Application') {
    Write-Host '[SHIELD] Application mode selected.'
    Write-Host '[SHIELD] CLI application installed.'
    Write-Host '[SHIELD] Desktop GUI integration will be enabled in a future release.'
  }

  Write-Host ''
  Write-Host '[SHIELD] Installation completed.'
  Write-Host "[SHIELD] Installed to: $InstallDir"
  Write-Host '[SHIELD] Open a new PowerShell window, then run: shield status'
}
finally {
  if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}
