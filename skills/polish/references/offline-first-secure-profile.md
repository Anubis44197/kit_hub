# Offline-First Secure Profile

Use this profile to disable external data egress by default.

## Profile Name
- `offline_first_secure`

## Policy
- External network calls: disabled by default.
- External upload/share operations: blocked.
- Report/manifests must avoid external URLs unless explicitly allowed.
- Export outputs stay within project-controlled directories.

## Allowed Exceptions
- Explicit user-approved network operation with scope/time bound.
- Document each exception in run summary metadata.

## Required Config Fields
- `security_profile.name = "offline_first_secure"`
- `security_profile.network_egress = "blocked"`
- `security_profile.external_upload = "blocked"`
- `security_profile.allowlisted_domains = []`
