# DARKTG — native Android migration

The \`native-migration\` branch removes the Flutter/Dart app and pins the Android client source as a Git submodule.

- Base client: [Telegram-FOSS-Team/Telegram-FOSS](https://github.com/Telegram-FOSS-Team/Telegram-FOSS)
- Upstream revision: \`10da5406ed92d30c6add3b25d40b2b3b6995d873\`
- Upstream license: GPL-2.0. Keep the license, copyright notices, and publish corresponding source for distributed binaries.
- The Telegram-FOSS client is Java/Android (not Flutter). Its native app module is \`TMessagesProj_App\`; core client module is \`TMessagesProj\`.

## Clone the native branch

\`\`\`bash
git clone -b native-migration --recurse-submodules https://github.com/socialpsycho/DARKTG.git
cd DARKTG
git submodule update --init --recursive
\`\`\`

If you already cloned without submodules:

\`\`\`bash
git submodule update --init --recursive
\`\`\`

## Configure Telegram API credentials

Do not use random, borrowed, or guessed API keys. Telegram requires an API ID and API hash issued for your own application:

1. Open https://my.telegram.org and sign in to your Telegram account.
2. Open **API development tools** and register DARKTG.
3. Create \`Telegram-FOSS/API_KEYS\` (this file is intentionally ignored by Git):

\`\`\`properties
APP_ID = YOUR_APP_ID
APP_HASH = YOUR_APP_HASH
\`\`\`

The upstream Gradle script reads this file at build time and exposes values to \`BuildVars\` through \`BuildConfig.APP_ID\` and \`BuildConfig.APP_HASH\`. Do not hardcode credentials in \`BuildVars.java\` or commit \`API_KEYS\`.

## Apply DARKTG modifications

On Linux / WSL2 with Git installed:

\`\`\`bash
bash native/apply.sh
\`\`\`

This copies \`GhostModeManager.java\` and \`DarkTgSettingsActivity.java\` into the Telegram-FOSS source tree and applies the patch to \`ConnectionsManager.java\` and \`ProfileActivity.java\`.

The upstream profile/settings page already contains native Privacy, Data and Devices screens:
- \`PrivacySettingsActivity\`
- \`DataSettingsActivity\`
- \`SessionsActivity\`

The patch adds a **DARKTG Settings** row to the existing native profile/settings list.

## Build requirements

Telegram-FOSS documents Linux builds; Windows is not supported natively. Use Ubuntu or WSL2 with the Android SDK, Android NDK 21.4.7075529, Go, Ninja, CMake 3.10.2, and the JDK version supported by the pinned upstream Gradle wrapper. The upstream project also builds native libraries.

\`\`\`bash
cd Telegram-FOSS
./gradlew assembleAfatDebug
\`\`\`

For a release build use the upstream documented task \`assembleAfatRelease\`.

The app's launcher/navigation, login, chat list, profile, privacy, data and active sessions come from the native Telegram-FOSS source. This is Android-only; iOS is not part of this native Android migration.

## Ghost Mode behavior and limitations

The patch intercepts outgoing MTProto requests before serialization:
- \`account.updateStatus\` when **Скрыть онлайн** is enabled;
- \`messages.setTyping\` when **Скрыть печать** is enabled;
- read-history / read-content request types when **Скрыть прочтение** is enabled.

\`updateUserStatus\` is a server-to-client update, not the outgoing request to suppress. Blocking read requests may leave unread counters locally inconsistent until the server sends later updates. Ghost Mode cannot retract a request already sent, guarantee invisibility in every Telegram flow, or bypass Telegram server behavior. Calls such as voice-chat speaking actions may use different request types and are not covered by this first patch.

Before distribution, run the upstream test/build workflow, review every request path, and comply with GPL-2.0 source publication requirements.
