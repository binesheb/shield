# Development

## Prerequisites
- Git
- Rust stable
- Platform-specific SDK/tooling for the platform being developed

## Build
cargo build

## Test
cargo test

## Format
cargo fmt --all

## Lint
cargo clippy --all-targets --all-features -- -D warnings

## Run
cargo run -- status
cargo run -- scan .

## Security-sensitive development

Do not test unknown malware on a normal workstation. Use isolated environments and synthetic fixtures whenever possible.

Do not commit credentials, private data, or live malware samples.

## Initial roadmap
1. Event model
2. Scanner abstraction
3. Hash scanner
4. YARA adapter
5. ClamAV adapter
6. Quarantine
7. Detection tests
8. Platform adapters
