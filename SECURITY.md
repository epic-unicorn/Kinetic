# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| Latest release on GitHub (`v*`) | Yes |
| Development builds / untagged `main` | Best-effort |

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems.

Report privately via GitHub Security Advisories:

1. Open [Security → Advisories](https://github.com/ingmarstruijs/Kinetic/security/advisories)
2. Choose **Report a vulnerability**
3. Include: affected app (parent / kids), version or commit, steps to reproduce, and impact

We aim to acknowledge reports within **7 days** and share a remediation plan or mitigation when possible.

## Scope

In scope:

- Cryptography and key handling (vault / family key / WebDAV ciphertext)
- Authentication and credential storage
- Unauthorized access to local or synced data
- Supply-chain issues in dependencies used by release builds

Out of scope:

- Denial of service against a user’s own WebDAV server
- Issues that require physical access to an unlocked device
- Missing features or UX bugs without a security impact

## Hardening notes

- No telemetry or third-party analytics
- Optional WebDAV sync only; bring your own server
- Android auto-backup should remain disabled for both apps
- Prefer HTTPS for WebDAV endpoints
