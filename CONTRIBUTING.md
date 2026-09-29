# Contributing to SHIELD

Thank you for contributing to SHIELD.

SHIELD is security-sensitive software and a component of the Binesh OS ecosystem.

## Read first

- README.md
- docs/PRD.md
- docs/architecture.md
- docs/interface.md
- docs/binesh-os-integration.md
- SECURITY.md

## Contribution areas

Core Rust, Windows/Linux/macOS, Binesh OS integration, scanner engines, detection rules, threat intelligence, CLI, API, GUI, CI/CD, testing, and documentation.

## Binesh OS contributions

Binesh OS integration uses SHIELD's public contracts. Do not copy detection logic into Binesh OS. OS-specific code belongs in platform adapters.

## Development

```text
cargo build
cargo test
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings
```

## Detection rules

Rules should include an identifier, description, severity, confidence, references, false-positive notes, and tests where practical.

Do not commit live malware samples unless explicitly approved and handled under the security/testing process.

## Pull requests

Explain what changed, why, how it was tested, affected platforms, security implications, and Binesh OS implications when applicable.

## Principle

If a security decision cannot be explained, tested, and reproduced, it is not ready to merge.
