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

The current bootstrap builds from source and requires Git and Rust/Cargo.

## Interfaces

The CLI is the reference interface for v0.1:

```text
shield status
shield scan <path>
shield version
shield engines
shield doctor
```

A local API/event interface will become the integration contract for the future GUI and Binesh OS.

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
- CLI
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
