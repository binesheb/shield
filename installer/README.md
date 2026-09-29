# SHIELD Installer

## One command

Windows users run exactly one command:

```powershell
irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
```

SHIELD then presents an interactive menu:

```text
How would you like to run SHIELD?

[1] Live
    Build and run without installing

[2] Install as Application
    Install the SHIELD CLI/application

[3] Install as Service
    Install for continuous endpoint protection

[4] Exit
```

The user selects how SHIELD should proceed.

## Current implementation

The development bootstrap builds SHIELD from source and therefore requires:

- Windows
- PowerShell
- Git
- Rust/Cargo

### Live

Nothing is permanently installed.

### Application

The SHIELD binary is installed under the user's local application directory and added to the user's PATH.

### Service

The binary is installed, but the Windows service is not registered yet. Continuous protection requires the service architecture, privilege boundary, IPC, recovery, update, and uninstall behavior to be implemented first.

The installer intentionally does not create a non-functional service.

## Version

Set `SHIELD_VERSION` before running the same command to select a branch or tag:

```powershell
$env:SHIELD_VERSION='v0.1.0'; irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
```

## Production release plan

The development source bootstrap will eventually be replaced/extended by signed prebuilt artifacts.

Production installation should verify:

- HTTPS
- authenticated release metadata
- artifact hash
- publisher signature
- release version
- platform and architecture
- rollback compatibility

The user experience should remain the same: **one command → select mode → SHIELD installs or runs.**
