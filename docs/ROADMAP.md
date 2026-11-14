# DARKTG Roadmap

## Phase 1 — UI foundation
- [x] Flutter application shell
- [x] Chats, Contacts and Settings tabs
- [x] DARKTG settings prototype
- [ ] Responsive polish and accessibility review

## Phase 2 — Telegram connectivity
- [x] Select TDLib JSON integration for the Android prototype
- [x] Add the Android TDLib engine bootstrap and client ID bridge
- [x] Add in-app authentication UI and TDLib request methods (device verification pending)\n- [ ] Verify secure authentication end-to-end on an Android device
- [x] Add a background TDLib receive worker and authorization-state event handling
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
