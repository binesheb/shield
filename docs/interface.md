# SHIELD Interface Specification

## Strategy

SHIELD is CLI-first for v0.1 and API-first for integration.

The CLI is the human/automation reference interface. The local API and event model are the integration contract for the GUI and Binesh OS.

## CLI

```text
shield status
shield scan <path>
shield protect
shield monitor
shield threats
shield quarantine
shield engines
shield config
shield update
shield version
shield doctor
```

## Machine-readable mode

Structured commands support:

```text
--json
```

This JSON contract is consumed by automation, the future GUI, and Binesh OS.

## Binesh OS integration API

The planned local API provides:

- security status
- engine status
- threat history
- quarantine
- scan
- quarantine/restore
- health
- capabilities
- version
- security event subscription

## Event contract

Each event should contain:

- event_id
- timestamp
- host_id
- platform
- event_type
- severity
- confidence
- source
- object
- explanation
- references

Events must be versioned.

## Security

The local API binds locally by default, authenticates privileged operations, authorizes destructive actions, validates inputs, uses secure IPC where supported, and exposes minimum required privileges.

## GUI and Binesh OS

Both are first-class clients of SHIELD Core/API. Neither implements independent scanning, detection, risk, or quarantine logic.
