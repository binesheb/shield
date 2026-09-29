# SHIELD Architecture

## Design goal

Keep the security-sensitive core small, modular, testable, cross-platform, and independently usable.

Binesh OS is a first-class host/integration target, not a separate antivirus implementation.

## Logical architecture

```text
                    SHIELD CORE
                        |
       +----------------+----------------+
       |                |                |
   Interfaces        Security        Platform
       |              Engines            |
  +----+----+           |         +------+------+
  |         |           |         |             |
 CLI      Local API   Detection  Windows      Binesh OS
                         |         Linux        macOS
                         |
                  Correlation/Risk
                         |
                      Response
```

## Binesh OS relationship

```text
+------------------------------------------------+
|                  Binesh OS                     |
| Shell / Settings / Notifications / Packages    |
|                    |                           |
|              SHIELD API/Event Bus              |
+--------------------+---------------------------+
                     |
+--------------------v---------------------------+
|                 SHIELD CORE                    |
| Detection | Intelligence | Risk | Response     |
+------------------------------------------------+
```

Binesh OS owns the operating-system experience. SHIELD owns security decisions.

## Boundaries

- **Core:** platform-independent domain logic.
- **Engines:** YARA, ClamAV, and future engine adapters.
- **Platforms:** OS-specific collectors, services, and privileged operations.
- **Interfaces:** CLI, local API, GUI, and OS integrations.
- **Binesh OS adapter:** translates SHIELD events/operations into the OS-native security framework.

## Event flow

External signal -> engine adapter -> normalized event -> validation -> correlation -> risk assessment -> policy evaluation -> response -> audit record -> event consumers.

## Binesh OS event flow

```text
Binesh OS event
      |
SHIELD platform adapter
      |
Normalized SHIELD event
      |
Detection / correlation / risk
      +----> SHIELD response
      +----> Binesh OS security event
```

## Architectural rules

1. Security logic lives in SHIELD Core.
2. Binesh OS consumes stable SHIELD interfaces.
3. Platform-specific code belongs behind adapters.
4. External engines do not own SHIELD state.
5. AI is optional.
6. Cloud services are optional.
7. Destructive actions require explicit policy.
8. Every detection should be explainable.
9. Security decisions must be testable.
10. Binesh OS integration must not create a second detection engine.
