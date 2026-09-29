# SHIELD single-command Windows bootstrap
# Run:
#   irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = 'binesheb/shield'
$Version = if ($env:SHIELD_VERSION) { $env:SHIELD_VERSION } else { 'main' }
$InstallDir = if ($env:SHIELD_INSTALL_DIR) { $env:SHIELD_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'SHIELD\bin' }

function Show-Menu {
    Clear-Host
    Write-Host ''
    Write-Host '  ███████╗██╗  ██╗██╗███████╗██╗     ██████╗ '
    Write-Host '  ██╔════╝██║  ██║██║██╔════╝██║     ██╔══██╗'
    Write-Host '  ███████╗███████║██║█████╗  ██║     ██║  ██║'
    Write-Host '  ╚════██║██╔══██║██║██╔══╝  ██║     ██║  ██║'
    Write-Host '  ███████║██║  ██║██║███████╗███████╗██████╔╝'
    Write-Host '  ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═════╝ '
    Write-Host ''
    Write-Host '  Open-source cross-platform endpoint security'
    Write-Host ''
    Write-Host '  How would you like to run SHIELD?'
    Write-Host ''
    Write-Host '  [1] Live'
    Write-Host '      Build and run without installing'
    Write-Host ''
    Write-Host '  [2] Install as Application'
    Write-Host '      Install the SHIELD CLI/application'
    Write-Host ''
    Write-Host '  [3] Install as Service'
    Write-Host '      Install for continuous endpoint protection'
    Write-Host ''
    Write-Host '  [4] Exit'
    Write-Host ''
}

function Get-Selection {
    do {
        Show-Menu
        $choice = Read-Host '  Select an option (1-4)'
    } while ($choice -notin @('1','2','3','4'))
    return $choice
}

$choice = Get-Selection

if ($choice -eq '4') {
    Write-Host ''
    Write-Host '[SHIELD] Exiting.'
    exit 0
}

Write-Host ''
Write-Host '[SHIELD] Preparing installation...'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is required by the current development bootstrapper.'
}

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'Rust/Cargo is required by the current development bootstrapper.'
}

$TempDir = Join-Path $env:TEMP ('shield-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    $SourceDir = Join-Path $TempDir 'source'
    $Branch = if ($Version -eq 'main') { 'main' } else { $Version }

    Write-Host '[SHIELD] Downloading source...'
    git clone --depth 1 --branch $Branch ('https://github.com/' + $Repo + '.git') $SourceDir

    Write-Host '[SHIELD] Building SHIELD...'
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

    switch ($choice) {
        '1' {
            Write-Host ''
            Write-Host '[SHIELD] Starting LIVE mode...'
            Write-Host '[SHIELD] Nothing will be permanently installed.'
            Write-Host ''
            & $Binary status
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }

        '2' {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            Copy-Item $Binary (Join-Path $InstallDir 'shield.exe') -Force

            $UserPath = [Environment]::GetEnvironmentVariable('Path','User')
            $Entries = @()
            if ($UserPath) {
                $Entries = $UserPath -split ';' | Where-Object { $_ }
            }
            if ($Entries -notcontains $InstallDir) {
                [Environment]::SetEnvironmentVariable('Path', (($Entries + $InstallDir) -join ';'), 'User')
            }

            Write-Host ''
            Write-Host '[SHIELD] Application installed successfully.'
            Write-Host "[SHIELD] Location: $InstallDir"
            Write-Host ''
            Write-Host '[SHIELD] Open a new PowerShell window and run:'
            Write-Host '          shield status'
        }

        '3' {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            Copy-Item $Binary (Join-Path $InstallDir 'shield.exe') -Force

            Write-Host ''
            Write-Host '[SHIELD] Service deployment selected.'
            Write-Host '[SHIELD] Binary installed.'
            Write-Host ''
            Write-Host '[SHIELD] Continuous protection service registration is not yet enabled in this development release.'
            Write-Host '[SHIELD] No incomplete or non-functional Windows service was created.'
            Write-Host ''
            Write-Host '[SHIELD] This option will become the persistent protection mode in the service milestone.'
        }
    }
}
finally {
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
