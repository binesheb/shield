# SHIELD single-command Windows bootstrap
# PowerShell 5.1+
# Production goal: zero developer prerequisites for end users.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo = 'binesheb/shield'
$RawInstaller = 'https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1'
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
    Write-Host '      Build and run without persistent installation'
    Write-Host ''
    Write-Host '  [2] Install as Application'
    Write-Host '      Install the GUI + CLI for the current user'
    Write-Host ''
    Write-Host '  [3] Install as Service'
    Write-Host '      Install GUI + CLI + automatic endpoint service'
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
    $MachinePath = [Environment]::GetEnvironmentVariable('Path','Machine')
    $parts = @()
    if ($UserPath) { $parts += $UserPath }
    if ($MachinePath) { $parts += $MachinePath }
    if ($parts.Count -gt 0) { $env:Path = $parts -join ';' }
}

function Ensure-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw '[SHIELD] winget is required to bootstrap missing developer tools. Install Microsoft App Installer and run again.'
    }
}

function Ensure-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) { return }

    Write-Host '[SHIELD] Git is not installed. Installing automatically...'
    Ensure-Winget
    winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw '[SHIELD] Git installation failed.' }
    Refresh-UserPath

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $gitExe = Join-Path $env:ProgramFiles 'Git\cmd\git.exe'
        if (Test-Path $gitExe) { $env:Path = (Split-Path $gitExe) + ';' + $env:Path }
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw '[SHIELD] Git was installed but is not available in this PowerShell session.'
    }
    git --version | Write-Host
}

function Ensure-Rust {
    $cargoDir = Join-Path $env:USERPROFILE '.cargo\bin'
    $cargo = Join-Path $cargoDir 'cargo.exe'
    $rustup = Join-Path $cargoDir 'rustup.exe'

    if (-not (Test-Path $cargo)) {
        Write-Host '[SHIELD] Rust is not installed. Installing Rust automatically...'
        Ensure-Winget
        winget install --id Rustlang.Rustup -e --source winget --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { throw '[SHIELD] Rust installation failed.' }
        Refresh-UserPath
    }

    if (Test-Path $cargoDir) { $env:Path = $cargoDir + ';' + $env:Path }
    if (-not (Test-Path $cargo)) { throw '[SHIELD] cargo.exe is unavailable after Rust installation.' }

    if (Test-Path $rustup) {
        $toolchains = & $rustup toolchain list 2>$null
        if ($LASTEXITCODE -ne 0) { throw '[SHIELD] Unable to inspect Rust toolchains.' }
        $hasDefault = $false
        foreach ($line in $toolchains) {
            if ($line -match '\(default\)$') { $hasDefault = $true; break }
        }
        if (-not $hasDefault) {
            Write-Host '[SHIELD] No default Rust toolchain configured. Installing stable-msvc...'
            & $rustup toolchain install stable-msvc
            if ($LASTEXITCODE -ne 0) { throw '[SHIELD] stable-msvc installation failed.' }
            & $rustup default stable-msvc
            if ($LASTEXITCODE -ne 0) { throw '[SHIELD] stable-msvc configuration failed.' }
        }
    }

    $version = & $cargo --version 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $version) { throw '[SHIELD] Cargo cannot run with the configured toolchain.' }
    Write-Host "[SHIELD] $version"
}

function Ensure-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { return }

    Write-Host '[SHIELD] Administrator permission is required for service installation.'
    $tempInstaller = Join-Path $env:TEMP 'shield-elevated-installer.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri $RawInstaller -OutFile $tempInstaller
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $tempInstaller
    ) | Out-Null
    exit 0
}

function Test-File {
    param([string]$Path,[string]$Description)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "[SHIELD] $Description is missing." }
    if ((Get-Item -LiteralPath $Path).Length -le 0) { throw "[SHIELD] $Description is empty." }
}

function Test-PeBinary {
    param([string]$Path,[string]$Description)
    Test-File $Path $Description
    if ([IO.Path]::GetExtension($Path) -ne '.exe') { throw "[SHIELD] $Description is not an executable." }
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 2 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
        throw "[SHIELD] $Description failed Windows PE validation."
    }
}

function Get-Hash {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Add-UserPath {
    param([string]$Path)
    $current = [Environment]::GetEnvironmentVariable('Path','User')
    $entries = @()
    if ($current) { $entries = $current -split ';' | Where-Object { $_ } }
    if ($entries -notcontains $Path) {
        [Environment]::SetEnvironmentVariable('Path', (($entries + $Path) -join ';'), 'User')
    }
    $env:Path = $Path + ';' + $env:Path
}

function New-StartMenuShortcut {
    param([string]$TargetPath,[bool]$AllUsers)
    $programs = if ($AllUsers) {
        [Environment]::GetFolderPath('CommonPrograms')
    } else {
        [Environment]::GetFolderPath('Programs')
    }
    $folder = Join-Path $programs 'SHIELD'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $shortcutPath = Join-Path $folder 'SHIELD Security Center.lnk'

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = (Join-Path (Split-Path $TargetPath) 'shield-ui.exe')
    $shortcut.WorkingDirectory = Split-Path $TargetPath
    $shortcut.Description = 'SHIELD Endpoint Security'
    $shortcut.Save()
    [Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
    Write-Host "[SHIELD] Start Menu shortcut: $shortcutPath"
}

function Try-GetReleaseBinaries {
    param([string]$Destination)
    try {
        $arch = $env:PROCESSOR_ARCHITECTURE
        if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
        $assetArch = switch ($arch.ToUpperInvariant()) {
            'ARM64' { 'arm64' }
            'AMD64' { 'x64' }
            default { return $false }
        }
        $releaseUrl = if ($Version -eq 'main') { "https://api.github.com/repos/$Repo/releases/latest" } else { "https://api.github.com/repos/$Repo/releases/tags/$Version" }
        $headers = @{ 'User-Agent' = 'SHIELD-Installer' }
        $release = Invoke-RestMethod -UseBasicParsing -Headers $headers -Uri $releaseUrl
        $zipName = "shield-windows-$assetArch.zip"
        $checksumName = "sha256-$assetArch.txt"
        $zipAsset = @($release.assets | Where-Object { $_.name -eq $zipName })[0]
        $checksumAsset = @($release.assets | Where-Object { $_.name -eq $checksumName })[0]
        if (-not $zipAsset -or -not $checksumAsset) { return $false }
        Write-Host "[SHIELD] Release found: $($release.tag_name) ($assetArch)"
        $zipPath = Join-Path $Destination $zipName
        $checksumPath = Join-Path $Destination $checksumName
        Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $zipAsset.browser_download_url -OutFile $zipPath
        Invoke-WebRequest -UseBasicParsing -Headers $headers -Uri $checksumAsset.browser_download_url -OutFile $checksumPath
        Test-File $zipPath 'SHIELD release package'
        Test-File $checksumPath 'SHIELD release checksum'
        $expected = (Get-Content $checksumPath | Select-Object -First 1).Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)[0].ToLowerInvariant()
        $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($expected -ne $actual) { throw '[SHIELD] Release SHA-256 verification failed.' }
        $extract = Join-Path $Destination 'release'
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extract -Force
        $cli = Join-Path $extract 'shield.exe'
        $gui = Join-Path $extract 'shield-ui.exe'
        Test-PeBinary $cli 'released SHIELD CLI'
        Test-PeBinary $gui 'released SHIELD GUI'
        $cliSignature = Get-AuthenticodeSignature -FilePath $cli
        $guiSignature = Get-AuthenticodeSignature -FilePath $gui
        if ($cliSignature.Status -ne 'Valid' -or $guiSignature.Status -ne 'Valid') {
            throw '[SHIELD] Release Authenticode signature verification failed.'
        }
        Write-Host "[SHIELD] Release integrity checkpoint: PASS ($actual)"
        Write-Host "[SHIELD] Publisher: $($cliSignature.SignerCertificate.Subject)"
        $script:ReleaseCliBinary = $cli
        $script:ReleaseGuiBinary = $gui
        return $true
    } catch {
        Write-Host '[SHIELD] No verified release available; using source bootstrap.'
        return $false
    }
}

$choice = Get-Selection
if ($choice -eq '4') {
    Write-Host '[SHIELD] Exiting.'
    exit 0
}

if ($choice -eq '3') { Ensure-Admin }

Write-Host ''
Write-Host '[SHIELD] Preparing SHIELD...'

$tempDir = Join-Path $env:TEMP ('shield-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $releaseReady = Try-GetReleaseBinaries $tempDir
    if ($releaseReady) {
        $cliBinary = $script:ReleaseCliBinary
        $guiBinary = $script:ReleaseGuiBinary
        $cliHash = Get-Hash $cliBinary
        $guiHash = Get-Hash $guiBinary
        Write-Host '[SHIELD] Using verified prebuilt release.'
    } else {
        Write-Host '[SHIELD] Checking required source-build tools...'
        Ensure-Git
        Ensure-Rust
        $sourceDir = Join-Path $tempDir 'source'
        $branch = if ($Version -eq 'main') { 'main' } else { $Version }
        Write-Host '[SHIELD] Downloading source...'
        git clone --depth 1 --branch $branch ('https://github.com/' + $Repo + '.git') $sourceDir
        if ($LASTEXITCODE -ne 0) { throw '[SHIELD] Source download failed.' }
        Test-File (Join-Path $sourceDir 'Cargo.toml') 'SHIELD source manifest'
        if (-not (Test-Path (Join-Path $sourceDir '.git') -PathType Container)) { throw '[SHIELD] Git checkout verification failed.' }
        Write-Host '[SHIELD] Source checkpoint: PASS'
        Push-Location $sourceDir
        try {
            Write-Host '[SHIELD] Building CLI + GUI...'
            cargo build --release --bins
            if ($LASTEXITCODE -ne 0) { throw '[SHIELD] Rust release build failed.' }
        } finally { Pop-Location }
        $cliBinary = Join-Path $sourceDir 'target\release\shield.exe'
        $guiBinary = Join-Path $sourceDir 'target\release\shield-ui.exe'
        Test-PeBinary $cliBinary 'SHIELD CLI'
        Test-PeBinary $guiBinary 'SHIELD GUI'
        $cliHash = Get-Hash $cliBinary
        $guiHash = Get-Hash $guiBinary
        Write-Host "[SHIELD] CLI checkpoint: PASS ($cliHash)"
        Write-Host "[SHIELD] GUI checkpoint: PASS ($guiHash)"
    }

    $rulesSource = Join-Path (Split-Path $cliBinary) 'rules'
    if (-not (Test-Path $rulesSource -PathType Container)) {
        $sourceRules = if ($sourceDir) { Join-Path $sourceDir 'rules' } else { $null }
        if ($sourceRules -and (Test-Path $sourceRules -PathType Container)) {
            Copy-Item $sourceRules $rulesSource -Recurse -Force
        }
    }
    if (-not (Test-Path $rulesSource -PathType Container)) {
        throw '[SHIELD] Bundled YARA rules are missing from the deployment package.'
    }

    if ($choice -eq '1') {
        Write-Host ''
        Write-Host '[SHIELD] LIVE mode'
        Write-Host '[SHIELD] Launching GUI...'
        Start-Process $guiBinary
        Write-Host '[SHIELD] GUI started. No files were installed permanently.'
        exit 0
    }

    if ($choice -eq '2') {
        $installRoot = $InstallDir
        New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
        Copy-Item $cliBinary (Join-Path $installRoot 'shield.exe') -Force
        Copy-Item $guiBinary (Join-Path $installRoot 'shield-ui.exe') -Force
        Copy-Item $rulesSource (Join-Path $installRoot 'rules') -Recurse -Force

        $installedCli = Join-Path $installRoot 'shield.exe'
        $installedGui = Join-Path $installRoot 'shield-ui.exe'
        Test-PeBinary $installedCli 'installed SHIELD CLI'
        Test-PeBinary $installedGui 'installed SHIELD GUI'
        if ((Get-Hash $installedCli) -ne $cliHash) { throw '[SHIELD] CLI installation hash mismatch.' }
        if ((Get-Hash $installedGui) -ne $guiHash) { throw '[SHIELD] GUI installation hash mismatch.' }

        Add-UserPath $installRoot
        New-StartMenuShortcut $installedGui $false
        & $installedCli doctor
        if ($LASTEXITCODE -ne 0) { throw '[SHIELD] Post-install doctor check failed.' }

        Write-Host ''
        Write-Host '[SHIELD] Application installation: PASS'
        Start-Process $installedGui
        exit 0
    }

    if ($choice -eq '3') {
        $installRoot = Join-Path $env:ProgramFiles 'SHIELD'
        New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
        Copy-Item $cliBinary (Join-Path $installRoot 'shield.exe') -Force
        Copy-Item $guiBinary (Join-Path $installRoot 'shield-ui.exe') -Force
        Copy-Item $rulesSource (Join-Path $installRoot 'rules') -Recurse -Force

        $installedCli = Join-Path $installRoot 'shield.exe'
        $installedGui = Join-Path $installRoot 'shield-ui.exe'
        Test-PeBinary $installedCli 'installed SHIELD CLI'
        Test-PeBinary $installedGui 'installed SHIELD GUI'
        if ((Get-Hash $installedCli) -ne $cliHash) { throw '[SHIELD] CLI service installation hash mismatch.' }
        if ((Get-Hash $installedGui) -ne $guiHash) { throw '[SHIELD] GUI service installation hash mismatch.' }

        & $installedCli service uninstall 2>$null | Out-Null
        & $installedCli service install
        if ($LASTEXITCODE -ne 0) { throw '[SHIELD] Windows service installation failed.' }

        $serviceState = sc.exe query SHIELD
        if ($LASTEXITCODE -ne 0 -or $serviceState -notmatch 'STATE') { throw '[SHIELD] Windows service verification failed.' }

        New-StartMenuShortcut $installedGui $true
        & $installedCli doctor
        if ($LASTEXITCODE -ne 0) { throw '[SHIELD] Post-service doctor check failed.' }

        Write-Host ''
        Write-Host '[SHIELD] Field installation: PASS'
        Write-Host '[SHIELD] Service: SHIELD'
        Write-Host '[SHIELD] GUI: SHIELD Security Center'
        Start-Process $installedGui
        exit 0
    }
}
catch {
    Write-Host ''
    Write-Host ('[SHIELD] FAILED: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
