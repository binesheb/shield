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

This is a **development/source bootstrap**. It compiles SHIELD locally and therefore downloads Git/Rust when needed.

### Live

Builds and runs SHIELD without permanently installing the executable.

### Application

Installs the verified executable under:

```text
%LOCALAPPDATA%\SHIELD\bin
```

and adds that directory to the user's PATH.

### Service

Installs and verifies the executable but does **not** register a Windows service yet.

The service option is intentionally non-destructive until the SHIELD protection daemon, privilege boundary, secure IPC, recovery, update, and uninstall design are complete.

## Version

Set `SHIELD_VERSION` to a branch or tag:

```powershell
$env:SHIELD_VERSION='v0.1.0'
irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
```

## Production installer

The source bootstrap is temporary.

The production installer should keep the exact same user experience but use signed prebuilt release artifacts:

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

No Rust or Git should be required for normal users in the production release.

## Security

Do not pipe an unreviewed installer from an untrusted fork into PowerShell. Production releases must use signed artifacts and authenticated update metadata.
