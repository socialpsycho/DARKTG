# DARKTG native migration

This branch is the staging branch for moving DARKTG from the Flutter + TDLib prototype to the native Android source layout used by AyuGram4A (Telegram Android sources, Java/Android Gradle project).

## Upstream inspected

- Upstream: https://github.com/AyuGram/AyuGram4A
- Branch: `rewrite`
- Inspected tree: `7013145676d36d82ee13c02a89f72097b7490dcd`
- License: GPL-2.0
- Native app module: `:TMessagesProj`
- Build target documented upstream: `./gradlew assembleAfatRelease`

## Important source dependency

The upstream repository declares a Git submodule:

```ini
[TMessagesProj/src/main/java/com/radolyn/ayugram/proprietary]
    path = TMessagesProj/src/main/java/com/radolyn/ayugram/proprietary
    url = https://github.com/AyuGram/AyuGram4A_proprietary.git
```

That repository is not publicly readable at the time this migration was inspected (GitHub returns 404). The upstream README also says a custom fork must implement `AyuMessageUtils` and `AyuHistoryHook`. These are not present in the public tree as ordinary source files.

Therefore, copying only the visible public tree and starting a release build would not be a verified, complete migration. This branch deliberately does not claim that a native APK is ready.

## Migration requirements

1. Bring in a buildable native Android Telegram source tree and preserve all upstream GPL-2.0 notices and third-party licenses.
2. Replace AyuGram package/application branding with DARKTG branding without removing upstream attribution.
3. Supply DARKTG implementations for the Ayu message-history hooks required by the chosen upstream revision.
4. Configure the documented API build parameters through the upstream build configuration; do not commit private signing keys or service credentials.
5. Build and inspect the APK in CI before offering it for device testing.
6. Port DARKTG-specific UI and settings only after the native base builds and launches.

## Current state

- `main` remains the existing Flutter + TDLib prototype.
- This branch is an isolated migration workspace.
- No claim is made that login, native build, Ghost Mode, or history has been validated on a device yet.
