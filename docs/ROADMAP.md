# DARKTG Native Android Roadmap

## Phase 1 — Native base
- [x] Preserve the previous Flutter implementation on \`main\`
- [x] Create \`native-migration\` branch
- [x] Pin Telegram-FOSS as a Git submodule
- [x] Remove Dart sources and Flutter package configuration from this branch
- [x] Add Ghost Mode manager and native settings screen source
- [ ] Apply and compile the native overlay against the pinned upstream revision
- [ ] Verify login, chats, profile, and settings on a physical Android device

## Phase 2 — Privacy controls
- [x] Add independent preferences for online, read receipts, and typing controls
- [x] Add an outgoing MTProto request filter for the relevant request classes
- [ ] Audit all request paths, including channel reads and voice-chat activity
- [ ] Add automated tests for request filtering and preference persistence
- [ ] Verify behavior against server-side updates and multi-account state

## Phase 3 — DARKTG features
- [ ] Add DARKTG branding and app identity without using Telegram's official name/logo as the app identity
- [ ] Implement additional customization behind native settings
- [ ] Review storage, background operation, and battery behavior
- [ ] Publish corresponding source and license notices for distributed builds

## Platform scope
This migration branch targets native Android (Java/Kotlin) using Telegram-FOSS. It does not provide an iOS build. Telegram-FOSS is GPL-2.0; preserve its notices and comply with source-distribution requirements.
