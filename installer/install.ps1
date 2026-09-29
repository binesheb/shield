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
    Write-Host '  SHIELD - Binesh OS Security'
    Write-Host '  Open-source cross-platform endpoint security'
    Write-Host ''
    Write-Host '  How would you like to run SHIELD?'
    Write-Host ''
    Write-Host '  [1] Live'
    Write-Host '      Run SHIELD without a persistent installation'
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

function Refresh-UserPath {
    $UserPath = [Environment]::GetEnvironmentVariable('Path','User')
    if ($UserPath) {
        $env:Path = $UserPath + ';' + [Environment]::GetEnvironmentVariable('Path','Machine')
    }
}

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'Windows Package Manager (winget) is required to bootstrap missing build tools. Please install App Installer from Microsoft Store, then run this command again.'
    }
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        return
    }

    Write-Host '[SHIELD] Git is not installed. Installing Git automatically...'
    Ensure-Winget
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    Refresh-UserPath

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $GitExe = Join-Path $env:ProgramFiles 'Git\cmd\git.exe'
        if (Test-Path $GitExe) {
            $env:Path = (Split-Path $GitExe) + ';' + $env:Path
        }
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git installation completed but git.exe is not available in this PowerShell session. Close PowerShell, open a new window, and run the SHIELD command again.'
    }
}

function Ensure-Rust {
    $CargoDir = Join-Path $env:USERPROFILE '.cargo\bin'
    $CargoPath = Join-Path $CargoDir 'cargo.exe'

    if (-not (Test-Path $CargoPath)) {
        Write-Host '[SHIELD] Rust/Cargo is not installed. Installing Rust automatically...'
        Ensure-Winget
        winget install --id Rustlang.Rustup -e --source winget --accept-source-agreements --accept-package-agreements
        Refresh-UserPath
    }

    if (Test-Path $CargoPath) {
        $env:Path = $CargoDir + ';' + $env:Path
    }

    if (-not (Test-Path $CargoPath)) {
        throw 'Rust installation completed but cargo.exe is not available. Open a new PowerShell window and run the SHIELD command again.'
    }

    # rustup may be installed without a default toolchain. Bootstrap it automatically.
    $RustupPath = Join-Path $CargoDir 'rustup.exe'
    if (Test-Path $RustupPath) {
        $toolchain = & $RustupPath toolchain list 2>$null
        $hasDefault = $false
        foreach ($line in $toolchain) {
            if ($line -match '\(default\)

function Assert-Command {
    param([Parameter(Mandatory=$true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "[SHIELD] Required command '$Name' is not available."
    }
}

function Get-FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-DownloadedFile {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Description)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "[SHIELD] $Description was not downloaded."
    }
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -le 0) {
        throw "[SHIELD] $Description is empty."
    }
}

function Test-ShieldBinary {
    param([Parameter(Mandatory=$true)][string]$Path)
    Test-DownloadedFile -Path $Path -Description 'SHIELD binary'
    if ([IO.Path]::GetExtension($Path) -ne '.exe') {
        throw '[SHIELD] Invalid SHIELD executable format.'
    }

    # Verify that Windows can inspect the PE executable before it is used.
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 2 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
        throw '[SHIELD] Downloaded SHIELD binary is not a valid Windows executable.'
    }
}

function Test-Build {
    param([Parameter(Mandatory=$true)][string]$SourceDir,[Parameter(Mandatory=$true)][string]$Binary)
    if (-not (Test-Path (Join-Path $SourceDir 'Cargo.toml') -PathType Leaf)) {
        throw '[SHIELD] Source checkout is incomplete: Cargo.toml is missing.'
    }
    if (-not (Test-Path (Join-Path $SourceDir '.git') -PathType Container)) {
        throw '[SHIELD] Source checkout is incomplete: Git metadata is missing.'
    }
    Test-ShieldBinary -Path $Binary
}

$choice = Get-Selection

if ($choice -eq '4') {
    Write-Host ''
    Write-Host '[SHIELD] Exiting.'
    exit 0
}

Write-Host ''
Write-Host '[SHIELD] Preparing SHIELD...'
Write-Host '[SHIELD] Checking required build tools...'

Ensure-Git
Ensure-Rust

$TempDir = Join-Path $env:TEMP ('shield-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    $SourceDir = Join-Path $TempDir 'source'
    $Branch = if ($Version -eq 'main') { 'main' } else { $Version }

    Write-Host '[SHIELD] Downloading source...'
    git clone --depth 1 --branch $Branch ('https://github.com/' + $Repo + '.git') $SourceDir
    if ($LASTEXITCODE -ne 0) {
        throw '[SHIELD] Unable to download the SHIELD source repository.'
    }
    if (-not (Test-Path $SourceDir -PathType Container)) {
        throw '[SHIELD] Source directory was not created.'
    }

    $CargoToml = Join-Path $SourceDir 'Cargo.toml'
    if (-not (Test-Path $CargoToml -PathType Leaf) -or (Get-Item $CargoToml).Length -le 0) {
        throw '[SHIELD] Source checkout is incomplete or Cargo.toml is empty.'
    }

    Write-Host '[SHIELD] Source download verified.'
    Write-Host '[SHIELD] Building SHIELD...'
    Push-Location $SourceDir
    try {
        cargo build --release
        if ($LASTEXITCODE -ne 0) {
            throw '[SHIELD] SHIELD build failed.'
        }
    } finally {
        Pop-Location
    }

    $Binary = Join-Path $SourceDir 'target\release\shield.exe'
    Test-Build -SourceDir $SourceDir -Binary $Binary
    $SourceHash = Get-FileSha256 -Path $Binary
    Write-Host "[SHIELD] Build verified. SHA-256: $SourceHash"

    switch ($choice) {
        '1' {
            Write-Host ''
            Write-Host '[SHIELD] Starting LIVE mode...'
            Write-Host '[SHIELD] Nothing will be permanently installed.'
            Write-Host ''
            & $Binary status
            exit $LASTEXITCODE
        }

        '2' {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            $InstalledBinary = Join-Path $InstallDir 'shield.exe'
            Copy-Item $Binary $InstalledBinary -Force
            Test-ShieldBinary -Path $InstalledBinary

            $InstalledHash = Get-FileSha256 -Path $InstalledBinary
            if ($InstalledHash -ne $SourceHash) {
                throw '[SHIELD] Installed binary failed SHA-256 verification.'
            }
            Write-Host "[SHIELD] Installation verified. SHA-256: $InstalledHash"

            $UserPath = [Environment]::GetEnvironmentVariable('Path','User')
            $Entries = @()
            if ($UserPath) {
                $Entries = $UserPath -split ';' | Where-Object { $_ }
            }
            if ($Entries -notcontains $InstallDir) {
                [Environment]::SetEnvironmentVariable('Path', (($Entries + $InstallDir) -join ';'), 'User')
            }

            $env:Path = $InstallDir + ';' + $env:Path

            Write-Host ''
            Write-Host '[SHIELD] Application installed successfully.'
            Write-Host "[SHIELD] Location: $InstallDir"
            Write-Host ''
            & (Join-Path $InstallDir 'shield.exe') status
        }

        '3' {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            $InstalledBinary = Join-Path $InstallDir 'shield.exe'
            Copy-Item $Binary $InstalledBinary -Force
            Test-ShieldBinary -Path $InstalledBinary

            $InstalledHash = Get-FileSha256 -Path $InstalledBinary
            if ($InstalledHash -ne $SourceHash) {
                throw '[SHIELD] Service installation binary failed SHA-256 verification.'
            }

            Write-Host ''
            Write-Host '[SHIELD] Service deployment selected.'
            Write-Host '[SHIELD] Binary installed.'
            Write-Host ''
            Write-Host '[SHIELD] Continuous protection service registration is not yet enabled in this development release.'
            Write-Host '[SHIELD] No incomplete or non-functional Windows service was created.'
            Write-Host ''
            Write-Host '[SHIELD] The service layer will be enabled when the SHIELD protection daemon and secure service boundary are ready.'
        }
    }
}
finally {
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
) {
                $hasDefault = $true
                break
            }
        }

        if (-not $hasDefault) {
            Write-Host '[SHIELD] No default Rust toolchain is configured. Installing stable...'
            & $RustupPath toolchain install stable
            if ($LASTEXITCODE -ne 0) {
                throw 'Unable to install the stable Rust toolchain.'
            }

            & $RustupPath default stable
            if ($LASTEXITCODE -ne 0) {
                throw 'Unable to configure stable as the default Rust toolchain.'
            }
        }
    }

    $cargoVersion = & $CargoPath --version 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $cargoVersion) {
        throw 'Cargo is installed but no usable Rust toolchain is configured.'
    }

    Write-Host "[SHIELD] $cargoVersion"
}

$choice = Get-Selection

if ($choice -eq '4') {
    Write-Host ''
    Write-Host '[SHIELD] Exiting.'
    exit 0
}

Write-Host ''
Write-Host '[SHIELD] Preparing SHIELD...'
Write-Host '[SHIELD] Checking required build tools...'

Ensure-Git
Ensure-Rust

$TempDir = Join-Path $env:TEMP ('shield-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    $SourceDir = Join-Path $TempDir 'source'
    $Branch = if ($Version -eq 'main') { 'main' } else { $Version }

    Write-Host '[SHIELD] Downloading source...'
    git clone --depth 1 --branch $Branch ('https://github.com/' + $Repo + '.git') $SourceDir
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to download the SHIELD source repository.'
    }

    if (-not (Test-Path (Join-Path $SourceDir 'Cargo.toml'))) {
        throw 'The selected SHIELD revision does not contain Cargo.toml. The installer expects the Rust application build to be present.'
    }

    Write-Host '[SHIELD] Building SHIELD...'
    Push-Location $SourceDir
    try {
        cargo build --release
        if ($LASTEXITCODE -ne 0) {
            throw 'SHIELD build failed.'
        }
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
            exit $LASTEXITCODE
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

            $env:Path = $InstallDir + ';' + $env:Path

            Write-Host ''
            Write-Host '[SHIELD] Application installed successfully.'
            Write-Host "[SHIELD] Location: $InstallDir"
            Write-Host ''
            & (Join-Path $InstallDir 'shield.exe') status
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
            Write-Host '[SHIELD] The service layer will be enabled when the SHIELD protection daemon and secure service boundary are ready.'
        }
    }
}
finally {
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
