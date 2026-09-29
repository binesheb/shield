# Development

## Prerequisites

- Git
- Rust stable
- platform-specific SDK/tooling

## Build

```bash
cargo build
```

## Test

```bash
cargo test
```

## Format

```bash
cargo fmt --all
```

## Lint

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

## Run

```bash
cargo run -- status
cargo run -- scan .
```

## Binesh OS development

Binesh OS integration belongs behind the SHIELD platform adapter and local API/event contracts.

The core must remain buildable and testable without Binesh OS.

## Security-sensitive development

Do not test unknown malware on a normal workstation. Use isolated environments and synthetic fixtures whenever possible.

Do not commit credentials, private data, or live malware samples.

## Roadmap

1. Event model
2. Scanner abstraction
3. Hash scanner
4. YARA adapter
5. ClamAV adapter
6. Quarantine
7. Platform adapters
8. Binesh OS adapter
9. Local API
10. GUI
