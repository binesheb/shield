# SHIELD Installers

## Windows

### Application mode

Default mode. Installs the SHIELD CLI application:

```powershell
irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
```

### Live mode

Builds SHIELD and runs it without installing a persistent copy:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1))) -Mode Live
```

Live mode is intended for testing, evaluation, and development.

### Service mode

Installs the SHIELD binary and selects service deployment:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1))) -Mode Service
```

The current release does not register a Windows service because continuous protection and the privileged service boundary are not implemented yet. The installer reports this explicitly instead of creating a non-functional service.

### Application mode

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1))) -Mode Application
```

Application mode currently installs the CLI. The desktop GUI will be added without changing the security core.

## Version selection

```powershell
$env:SHIELD_VERSION='v0.1.0'; irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
```

## Architecture

The intended model is:

```text
                 SHIELD CORE
                      |
        +-------------+-------------+
        |             |             |
       LIVE        SERVICE      APPLICATION
        |             |             |
     CLI/test    endpoint       CLI + GUI
                 protection
```

All three modes use the same SHIELD Core. They must not implement separate detection logic.

## Security

The current bootstrap builds from source and requires Git and Rust/Cargo.

Production binary distribution must add signed release artifacts, integrity metadata, signature verification, rollback support, and authenticated update metadata before it is treated as a production-grade security-product installer.
