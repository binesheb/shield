# SHIELD Installer

## One command

Windows users run exactly one command:

```powershell
irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
```

SHIELD presents an interactive menu:

```text
[1] Live
[2] Install as Application
[3] Install as Service
[4] Exit
```

The user selects how SHIELD should proceed.

## Bootstrap behavior

The installer is designed for a clean Windows machine.

It verifies the required build environment before downloading/building SHIELD:

- Windows PowerShell 5.1+
- Windows Package Manager (winget) when a bootstrap dependency is missing
- Git
- Rustup/Cargo
- a configured stable Rust toolchain

If Git or Rust is missing, the installer attempts to install it with winget.

If Rustup exists without a default toolchain, the installer installs and selects stable automatically.

Every important stage is checked:

1. dependency availability
2. source checkout
3. source manifest
4. successful Rust build
5. SHIELD executable existence
6. Windows PE executable signature
7. SHA-256 of the built executable
8. SHA-256 of the installed executable
9. application status command after installation

A failed checkpoint stops the installation. Temporary source/build files are cleaned up.

## Current implementation

The installer is **release-first**. It downloads the matching x64/ARM64 Windows release and verifies its SHA-256 checksum before use. If no suitable release exists, it falls back to a source build and bootstraps Git/Rust.

### Live

Uses a verified release when available, launches the native Security Center GUI, and leaves no permanent installation.

### Application

Installs the verified CLI and GUI under:

```text
%LOCALAPPDATA%\SHIELD\bin
```

and adds that directory to the user's PATH.

### Service

Installs the verified CLI and GUI, registers the SHIELD Windows service with the Service Control Manager, starts it, verifies its state, and creates an all-users Start Menu shortcut.

## Version

Set `SHIELD_VERSION` to a release tag:

```powershell
$env:SHIELD_VERSION='v0.2.0'
irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
```

## Release-first installer

The production path uses signed/attested prebuilt release artifacts. The source bootstrap remains only as a fallback when no suitable release is available:

```text
IRM
 ↓
Detect OS + architecture
 ↓
Download signed release metadata
 ↓
Verify publisher signature
 ↓
Verify SHA-256
 ↓
Install/run
 ↓
Verify installed binary
 ↓
Start selected mode
```

No Rust or Git is required when a matching release artifact is available; otherwise the installer can fall back to a source build.

## Security

Do not pipe an unreviewed installer from an untrusted fork into PowerShell. Production releases must use signed artifacts and authenticated update metadata.


## Field stack

A service installation provides:

- `shield.exe` CLI
- `shield-ui.exe` native Security Center GUI
- Windows Service Control Manager integration
- automatic service startup
- service heartbeat/state file
- Microsoft Defender health telemetry
- Quick Scan / Full Scan / Custom Scan controls
- Defender signature update control
- Defender threat history
- SHA-256 file/directory scanning
- Start Menu shortcut
- post-install executable, hash, service, and doctor checkpoints

The GUI is built with native Rust/egui and does not require Node.js or a browser runtime. The Windows service is implemented with the Windows Service Control Manager integration. Release artifacts are built by GitHub Actions with artifact attestations; GitHub documents attestations as signed provenance linking a binary to its repository and workflow. 
