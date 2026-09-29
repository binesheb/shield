# Binesh OS Integration

## Purpose

SHIELD is the security subsystem of Binesh OS while remaining independently usable on other platforms.

## Integration principle

Binesh OS should not fork SHIELD. The operating system integrates SHIELD through documented interfaces, events, capabilities, and platform adapters.

## Responsibilities

### SHIELD

- malware detection
- threat intelligence
- correlation
- risk assessment
- quarantine
- response
- security events
- scanner orchestration
- security policy enforcement

### Binesh OS

- OS lifecycle
- native security UI
- notifications
- system settings
- application/package lifecycle
- OS-specific privilege/service management
- presentation of security state

## Native service

Binesh OS should run SHIELD as a privileged security service with a narrowly defined interface.

The service must start with the OS, expose authenticated local IPC, enforce least privilege, emit health events, support controlled updates, and maintain auditable state.

## Security Center

Binesh OS should consume SHIELD health, protection status, last scan, active detections, quarantine count, engine health, policy status, and update status.

## Application/package integration

Future Binesh OS package installation may request a SHIELD pre-install scan:

```text
Package Manager -> SHIELD -> ALLOW / BLOCK
```

The policy decision must be attributable and explainable.

## Boot/runtime integration

Future Binesh OS versions may integrate SHIELD with boot and runtime integrity checks. These must have explicit trust boundaries.

## Compatibility

Binesh OS should query SHIELD capabilities and API version rather than assume an implementation version.

## Testing

Integration tests should use deterministic fixtures and synthetic threats whenever possible. Live malware must not be required for ordinary CI.
