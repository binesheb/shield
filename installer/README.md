# SHIELD Installers

## Windows

PowerShell bootstrap:

    irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex

The current installer builds SHIELD from source and requires Git and Rust/Cargo.

After installation, open a new PowerShell window:

    shield status
    shield doctor
    shield scan .

Select a version with SHIELD_VERSION, for example:

    $env:SHIELD_VERSION='v0.1.0'; irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex

Production binary installation will require signed release artifacts, integrity verification, and signature verification before installation.
