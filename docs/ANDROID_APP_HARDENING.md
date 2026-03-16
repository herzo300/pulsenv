# Android App Hardening

## What Is Enforced In Code

- Release builds block screenshots with `FLAG_SECURE`.
- Release builds reject insecure backend base URLs without `https://`.
- Main manifest disables backups, data extraction, native lib extraction, and cleartext traffic.
- Release build requires proper signing unless explicitly overridden.
- R8 minification and resource shrinking are enabled.
- Flutter runtime can block execution on compromised Android environments.
- Sentry is configured without screenshots, view hierarchy, or default PII.

## What You Must Still Do

1. Use a real release keystore.
2. Keep `ANDROID_KEYSTORE_*` secrets outside the repo.
3. Build releases with Dart obfuscation and split debug info.
4. Keep the symbol files from `--split-debug-info` private.
5. Provide a production `BACKEND_BASE_URL` over HTTPS.
6. Provide `MCP_FETCH_URL` and `MCP_REPORTS_API_URL` explicitly if those features are needed.
7. Build with JDK 17/21. The repo-local script auto-picks Android Studio JBR when available.

## Keystore Setup

Use either:

- `services/Frontend/android/keystore.properties`
- or env vars:
  - `ANDROID_KEYSTORE_PATH`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEY_PASSWORD`

Template:

- [keystore.properties.example](C:/Soobshio_project/services/Frontend/android/keystore.properties.example)

## Hardened Build

From repo root:

```powershell
./scripts/build_hardened_android_arm64.ps1 -BackendBaseUrl "https://api.example.com"
```

## Important Limits

- Absolute protection from reverse engineering does not exist.
- Flutter/Dart obfuscation and R8 raise cost, but do not make code unreadable forever.
- Real resistance comes from moving secrets and privileged logic to the backend.
