# SHIELD

**SHIELD** is the open-source security and threat-protection platform of the **Binesh OS ecosystem**.

It is a cross-platform security core that can run independently on Windows, Linux, and macOS, while serving as an integrated security layer for Binesh OS.

> Open source. Cross-platform. Local-first. Modular. Binesh OS security layer.

## Relationship with Binesh OS

SHIELD is a standalone project and a native Binesh OS component.

Binesh OS may use SHIELD for malware and threat detection, endpoint protection, security events, threat intelligence, quarantine, response, system security status, application/package trust, and future boot/runtime integrity.

The security core remains reusable outside Binesh OS. Binesh OS integration consumes SHIELD's stable APIs/events rather than forking detection logic.

## Status

Early development / foundation phase.

## Quick install

### Windows

```powershell
irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
```

SHIELD presents an interactive choice:

```text
[1] Live
[2] Install as Application
[3] Install as Service
[4] Exit
```

The installer is release-first: tagged Windows releases are downloaded and integrity-checked automatically. Until a release is published, it falls back to a source build and bootstraps Git/Rust when required.

## Interfaces

SHIELD provides a native Windows Security Center GUI plus a CLI:

```text
shield status
shield scan <path>
shield version
shield engines
shield doctor
```

The GUI reads the local SHIELD security state, controls supported Windows Defender scans/updates, and exposes the independent YARA-X detection engine. YARA-X 1.20.0 is pure Rust and supports compiled rules plus file scanning. citeturn3search0turn2search1 The service maintains the endpoint heartbeat and security state.

## Architecture

```text
                         SHIELD CORE
                              |
              +---------------+---------------+
              |               |               |
             CLI          Local API        Event Bus
              |               |               |
           Users          GUI/API         Binesh OS
                              |
                       Security Services
                              |
                +-------------+-------------+
                |             |             |
             Detection   Intelligence   Response
```

## Goals

- Cross-platform endpoint security
- Native Binesh OS security integration
- Modular detection engines
- Local-first operation
- Explainable detections
- Safe quarantine and response
- Open threat-rule ecosystem
- Optional AI-assisted analysis
- Simple one-command installation
- Stable integration interfaces

## MVP

- Rust security core
- Native Windows GUI (Security Center)
- CLI
- Windows service
- configuration
- normalized security events
- scanner abstraction
- SHA-256 scanning
- YARA and ClamAV adapters
- quarantine
- threat history
- logging
- tests and CI
- Binesh OS integration contract

## Documentation

- Product Requirements: `docs/PRD.md`
- Architecture: `docs/architecture.md`
- Interface: `docs/interface.md`
- Binesh OS Integration: `docs/binesh-os-integration.md`
- Development: `docs/development.md`
- Contributing: `CONTRIBUTING.md`
- Security Policy: `SECURITY.md`

## Security

See `SECURITY.md` for vulnerability reporting.

## License

Apache-2.0.


### Windows installer fallback

The Windows IRM installer is release-first. If a verified x64/ARM64 release is unavailable, it continues with a source build and warns that Git and Rust/Cargo are required. This keeps development installations usable while preserving verification for published releases.
