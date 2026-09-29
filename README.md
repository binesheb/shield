# SHIELD

SHIELD is an open-source, cross-platform endpoint security platform designed to unify malware scanning, threat intelligence, behavioral detection, security events, and response behind a single interface.

> Open source. Cross-platform. Modular. Local-first.

## Status

Early development / foundation phase.

The current priority is a secure, testable core before advanced EDR, network detection, AI, or enterprise management.

## Goals
- Cross-platform endpoint security
- Modular detection engines
- Local-first operation
- Explainable detections
- Safe quarantine and response
- Open threat-rule ecosystem
- Optional AI-assisted analysis
- Simple installation and administration

## Platforms
- Windows
- Linux
- macOS

## MVP
- Rust core
- CLI
- Configuration
- Structured security events
- SHA-256 file scanning
- YARA integration
- ClamAV integration
- Quarantine
- Threat history
- Logging
- Tests and CI
- Contributor documentation

## Development

Requirements: Rust stable and Git.

Build: cargo build

Test: cargo test

Run: cargo run -- status

Scan: cargo run -- scan .

## Documentation
- docs/PRD.md
- docs/architecture.md
- docs/development.md
- CONTRIBUTING.md
- SECURITY.md

## Security

Do not report vulnerabilities through public GitHub issues. See SECURITY.md.

## License

Apache-2.0.
