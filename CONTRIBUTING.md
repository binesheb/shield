# Contributing to SHIELD

Thank you for contributing to SHIELD.

SHIELD is security-sensitive software. Contributions must prioritize correctness, safety, auditability, and maintainability.

## Before you start
Read README.md, docs/PRD.md, docs/architecture.md, and SECURITY.md.

## Good first contributions
Documentation, unit tests, CLI improvements, cross-platform compatibility, detection test fixtures, safe rule improvements, and CI improvements.

Look for issues labelled good-first-issue or help-wanted.

## Development
Install Rust stable.

cargo build
cargo test
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings

## Pull requests
Every PR should explain what changed, why it changed, how it was tested, affected platforms, security implications, and performance implications where relevant.

Security-sensitive changes should include tests covering expected detection and important benign cases.

## Detection rules
Rules are code. Where practical, new rules must include a rule ID, name, description, severity, confidence, references, false-positive notes, and test coverage.

Do not commit live malware samples unless explicitly approved and handled under the repository security/testing process. Prefer hashes, synthetic fixtures, metadata, and controlled test artifacts.

## Security
Do not disclose vulnerabilities in public issues. Follow SECURITY.md.

## Commit style
Use concise commits such as feat(scanner): add sha256 file scanner, fix(quarantine): prevent path traversal, or test(yara): add persistence fixtures.

## Principle
If a security decision cannot be explained, tested, and reproduced, it is not ready to merge.
