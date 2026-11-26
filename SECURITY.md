# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.0.x | yes |

## Reporting a vulnerability

Please do **not** open a public issue for security problems. Use GitHub's
private vulnerability reporting on this repository, or contact the maintainer
directly. Include the affected version, reproduction steps and the impact you
observed. You should receive an acknowledgement within a few days.

## Scope notes

- The LAN remote control is **off by default**. When enabled it is
  unauthenticated: only use it on a network you trust, and disable it
  afterwards.
- The diagnostic HTTP server (enabled with `ECHO_DIAG=1`) binds to loopback
  only and must never be exposed to a network.
- Release assets are provided as reproducible builds from this repository;
  verify the SHA-256 digests published in the release notes before running the
  installer.
