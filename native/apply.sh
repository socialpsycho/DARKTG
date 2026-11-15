#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM="$ROOT/Telegram-FOSS"
PATCH="$ROOT/native/patches/0001-darktg-ghost-mode.patch"

if [ ! -d "$UPSTREAM/.git" ]; then
  echo "Telegram-FOSS submodule missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

mkdir -p "$UPSTREAM/TMessagesProj/src/main/java/org/telegram/messenger"
mkdir -p "$UPSTREAM/TMessagesProj/src/main/java/org/telegram/ui"
cp "$ROOT/native/GhostModeManager.java" "$UPSTREAM/TMessagesProj/src/main/java/org/telegram/messenger/GhostModeManager.java"
cp "$ROOT/native/DarkTgSettingsActivity.java" "$UPSTREAM/TMessagesProj/src/main/java/org/telegram/ui/DarkTgSettingsActivity.java"

if git -C "$UPSTREAM" apply --check "$PATCH"; then
  git -C "$UPSTREAM" apply "$PATCH"
elif git -C "$UPSTREAM" apply --reverse --check "$PATCH"; then
  echo "DARKTG source patch already applied."
else
  echo "Patch does not match this Telegram-FOSS revision. Do not force it; rebase the patch against upstream." >&2
  exit 2
fi

echo "DARKTG native sources applied to Telegram-FOSS."
