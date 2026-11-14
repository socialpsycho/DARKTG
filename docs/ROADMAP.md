# DARKTG Roadmap

## Phase 1 — UI foundation
- [x] Flutter application shell
- [x] Chats, Contacts and Settings tabs
- [x] DARKTG settings prototype
- [ ] Responsive polish and accessibility review

## Phase 2 — Telegram connectivity
- [ ] Select a supported Telegram client integration (TDLib or another officially supported option)
- [ ] Implement secure authentication
- [ ] Load chats, contacts and message history
- [ ] Handle session data securely on-device

## Phase 3 — Supported features
- [ ] Local themes and interface customization
- [ ] Translation workflow
- [ ] Local audio effects
- [ ] Multiple-account management
- [ ] Local app lock
- [ ] Message history for content already received by the client

## Privacy and platform limits
DARKTG will respect Telegram's API, account security, protected-content settings and platform rules. It cannot recover messages that were deleted before the client received them or bypass protected-media restrictions. Any presence or read-state controls must be implemented only where supported by the Telegram API and must not be represented as guaranteed invisibility.
