# SHIELD Architecture

## Design goal

Keep the security-sensitive core small, modular, testable, and independent from platform-specific implementations.

## Logical architecture

CLI / Dashboard / API
        |
    SHIELD Core
        |
  +-----+------+
  |            |
Scanner      Platform
  |            |
YARA/       OS adapters
ClamAV
  |            |
  +-----+------+
        |
 Event Normalizer
        |
 Correlation Engine
        |
    Risk Engine
        |
 Response Manager
   /       |       \
 Alert  Quarantine  Block

## Boundaries

Core contains platform-independent domain logic.

Platform-specific code belongs under platforms/.

External security engines are adapters and should not own SHIELD state.

## Event flow

External signal -> engine adapter -> normalized event -> validation -> correlation -> risk assessment -> policy evaluation -> response -> audit record.

## Security boundaries

Distinguish untrusted file content, untrusted event data, privileged operations, engine processes, local API clients, configuration, and update artifacts.

Privileged operations should be minimized and isolated.

## Repository layout

cmd/
core/
engines/
platforms/
intelligence/
plugins/
api/
dashboard/
rules/
installer/
tests/
docs/
scripts/
.github/

## Technology direction

Rust is the preferred implementation language for the security-sensitive core.

Other languages may be used for platform tooling, UI, scripts, or integrations when justified.

## Architectural rules
1. Prefer interfaces over hard-coded engines.
2. Do not make AI mandatory.
3. Do not make cloud services mandatory.
4. Keep destructive actions behind explicit policy.
5. Every detection should be explainable.
6. Security decisions should be testable.
7. Platform-specific code belongs behind adapters.
