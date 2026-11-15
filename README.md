# DARKTG

DARKTG is an experimental Flutter-based Telegram client interface.

## Current status
This repository contains an early UI prototype with:
- Chats, Contacts and Settings tabs
- DARKTG settings sections for privacy, appearance and tools
- A GitHub Actions workflow that builds an Android debug APK

**Telegram sign-in and message sync are not yet verified end-to-end.** The Android app starts a background TDLib worker, configures TDLib parameters from `lib/core/telegram/config.dart`, and provides phone, login-code, optional 2FA password, and new-account registration steps. A successful build does not prove that Telegram authorization works on a device; chat synchronization and live messaging remain unfinished.

## Telegram integration status
- Android: initial TDLib engine bridge added with `handy_tdlib_next` (TDLib 1.8.36).
- Background TDLib receive loop and an authorization UI/request flow have been added; device-level sign-in still needs testing.
- Chat synchronization, live message send/receive, and local message-history storage are still pending.
- The selected Flutter binding currently declares Android support only; iOS needs a separately built and linked TDLib native library.

## Security notes\n- API ID/hash are entered at runtime and are not committed to the repository. Never share login codes or 2FA passwords in chat or GitHub.\n- TDLib session data is stored in the app-private support directory on the device.\n\n## Build
The Android APK workflow runs on pushes to `main` and can also be started manually from the Actions tab. It uploads an artifact named `darktg-debug-apk`.

## Roadmap
See [docs/ROADMAP.md](docs/ROADMAP.md).

## Privacy and platform limits
DARKTG will use supported Telegram interfaces and respect account security and protected-content restrictions. Local history can only retain messages already received by the client; it cannot recover messages deleted before receipt or bypass protected-media restrictions. Presence and read-state controls depend on supported API capabilities.
