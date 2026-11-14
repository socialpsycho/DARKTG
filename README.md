# DARKTG

DARKTG is an experimental Flutter-based Telegram client interface.

## Current status
This repository contains an early UI prototype with:
- Chats, Contacts and Settings tabs
- DARKTG settings sections for privacy, appearance and tools
- A GitHub Actions workflow that builds an Android debug APK

**Telegram sign-in and message sync are not implemented yet.** The Android app now initializes a community-maintained TDLib binding and creates a client ID, but it does not authenticate an account or receive updates. The current chat list remains prototype content.

## Telegram integration status
- Android: initial TDLib engine bridge added with `handy_tdlib_next` (TDLib 1.8.36).
- Account authorization, update receiving, chat synchronization and local message-history storage are still pending.
- The selected Flutter binding currently declares Android support only; iOS needs a separately built and linked TDLib native library.

## Build
The Android APK workflow runs on pushes to `main` and can also be started manually from the Actions tab. It uploads an artifact named `darktg-debug-apk`.

## Roadmap
See [docs/ROADMAP.md](docs/ROADMAP.md).

## Privacy and platform limits
DARKTG will use supported Telegram interfaces and respect account security and protected-content restrictions. Local history can only retain messages already received by the client; it cannot recover messages deleted before receipt or bypass protected-media restrictions. Presence and read-state controls depend on supported API capabilities.
