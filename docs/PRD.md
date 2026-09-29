# SHIELD Product Requirements Document

## Vision

SHIELD is an open-source, cross-platform endpoint security platform and the security subsystem of the Binesh OS ecosystem.

It provides malware detection, threat intelligence, security telemetry, behavioral analysis, risk assessment, quarantine, and response through one modular security core.

## Product principles

1. Open source first.
2. Local first.
3. Modular and replaceable.
4. Safe by default.
5. Explainable detections.
6. Minimal privileges.
7. Testable security decisions.
8. Privacy by default.
9. No mandatory cloud or AI dependency.
10. One security core, multiple interfaces.
11. Binesh OS integration through stable contracts, not a fork.

## Product relationship

### SHIELD owns

Scanning, detection, correlation, risk assessment, security events, quarantine, response, threat intelligence, and security policy enforcement.

### Binesh OS owns

Operating-system lifecycle, native security UI, notifications, system settings, package/application lifecycle, OS-specific privilege/service management, and presentation of security state.

Binesh OS must not duplicate SHIELD's detection engine.

## Platforms

Initial: Windows, Linux, macOS. Strategic platform: Binesh OS.

Future: Android, BSD, NAS, containers, Kubernetes nodes, and edge devices.

## Operating modes

- **Live:** run without persistent installation.
- **Application:** install as a user-facing security application/CLI.
- **Service:** persistent endpoint protection service.
- **Binesh OS native:** provisioned as an OS security component.

## Core

The core provides configuration, orchestration, event model, correlation, risk assessment, response, logging, and state.

### Scanner

SHA-256 hashing, YARA, ClamAV, and future engines.

### Events

Normalized events contain event ID, timestamp, host ID, platform, event type, severity, source, confidence, and object metadata.

### Risk

Risk levels: informational, low, medium, high, critical. Risk is an assessment, not proof of maliciousness.

### Response

Alert, quarantine, restore, block, and policy-controlled remediation. Destructive actions require explicit policy.

### Quarantine

Isolate suspicious objects, preserve metadata, assign IDs, record original paths/reasons, support restoration/deletion, and maintain an audit trail.

## Binesh OS integration

Binesh OS integration is first-class.

The initial contract provides:

- service discovery
- security status
- threat notifications
- scan requests/results
- quarantine actions
- health state
- policy state
- security event stream
- version/capability information

Binesh OS should present a unified security state backed by SHIELD.

## AI

AI is optional for correlation, anomaly analysis, explanations, investigations, and rule assistance. It must not be required for baseline protection or silently override deterministic controls.

## Installation

The user-facing goal is one command:

```powershell
irm https://raw.githubusercontent.com/binesheb/shield/main/installer/install.ps1 | iex
```

The bootstrap presents available modes.

Long-term installers should use signed prebuilt artifacts rather than requiring Rust.

## Security requirements

Signed releases, authenticated update metadata, integrity verification, least privilege, secure IPC, input validation, safe path handling, tamper-aware state, security regression tests, reproducible builds where practical, and secure Binesh OS service integration.

## Privacy

Security data remains local by default. Personal files are not uploaded by default. Telemetry is optional and explicit.

## Field-ready Windows stack

The Windows field deployment includes a native Security Center GUI, CLI, persistent Windows service, Microsoft Defender health/scanning controls, local state/logging, release-first installation, SHA-256 verification, Authenticode verification, architecture-specific releases, and post-install health checks.

The installer must never claim a production release is trusted unless the downloaded binaries pass both integrity and signature verification.

## MVP

In scope: Rust core, CLI, configuration, normalized events, scanner abstraction, SHA-256 scanner, YARA/ClamAV adapters, quarantine architecture, threat history, logging, CI, documentation, Binesh OS integration contract.

Out of scope: mandatory cloud/AI, enterprise fleet management, mobile clients, advanced network IDS, automatic destructive remediation, and a fully integrated Binesh OS UI before the API contract stabilizes.

## Roadmap

0. Foundation
1. Scanner abstraction and detection engines
2. Quarantine and response
3. Endpoint monitoring
4. Binesh OS security service integration
5. Network detection
6. Correlation and risk engine
7. GUI/security center — implemented for Windows
8. Independent YARA-X detection engine — implemented
8. Release packaging, provenance and signing — implemented in CI
9. Optional AI
10. Fleet management

## Definition of done

A feature is complete only when implementation, tests, documentation, security review, and CI validation are complete. Binesh OS features additionally require contract/integration tests without duplicating security logic in the OS.
