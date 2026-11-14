# DARKTG

DARKTG is an experimental Flutter-based Telegram client interface.

## Current status
This repository contains an early UI prototype with:
- Chats, Contacts and Settings tabs
- DARKTG settings sections for privacy, appearance and tools
- A GitHub Actions workflow that builds an Android debug APK

**Telegram connectivity is not implemented yet.** The current app is a visual prototype and does not sign in to Telegram or send and receive messages.

## Build
The Android APK workflow runs on pushes to `main` and can also be started manually from the Actions tab. It uploads an artifact named `darktg-debug-apk`.

## Roadmap
See [docs/ROADMAP.md](docs/ROADMAP.md).

## Privacy and platform limits
DARKTG will use supported Telegram interfaces and respect account security and protected-content restrictions. Local history can only retain messages already received by the client; it cannot recover messages deleted before receipt or bypass protected-media restrictions. Presence and read-state controls depend on supported API capabilities.
