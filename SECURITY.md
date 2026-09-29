# Security Policy

SHIELD is security-sensitive software. Vulnerabilities affecting endpoint security, privilege boundaries, update integrity, data protection, or detection/response behavior should be treated as security issues.

## Reporting

Do not disclose security vulnerabilities through public GitHub issues.

Use GitHub private vulnerability reporting when available. If it is unavailable, contact the repository maintainers privately through the repository profile.

Do not include live malware samples unless specifically requested by maintainers.

## Include
- affected version or commit
- affected platform
- reproduction steps
- expected behavior
- observed behavior
- security impact
- relevant minimal proof of concept

## Security-sensitive development
- minimize privileges
- validate untrusted input
- avoid unsafe file operations
- protect IPC
- verify update artifacts
- add regression tests for security bugs
- avoid mandatory telemetry

Until stable releases are established, the latest main branch is the primary development target.
