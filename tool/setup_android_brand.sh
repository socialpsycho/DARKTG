#!/usr/bin/env bash
set -euo pipefail
RES="android/app/src/main/res"
mkdir -p "$RES/drawable" "$RES/mipmap-anydpi" "$RES/mipmap-anydpi-v26" "$RES/values"
cat > "$RES/values/darktg_colors.xml" <<'XML'
<resources>
    <color name="darktg_launcher_background">#090812</color>
</resources>
XML
cat > "$RES/drawable/darktg_launcher_foreground.xml" <<'XML'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#00D5FF" android:fillType="evenOdd"
        android:pathData="M20,15 L62,15 C85,15 101,32 101,54 C101,77 85,93 62,93 L20,93 Z M36,31 L36,77 L61,77 C75,77 84,68 84,54 C84,40 75,31 61,31 Z"/>
    <path android:fillColor="#8B5CF6"
        android:pathData="M62,25 L42,57 L56,57 L46,84 L76,47 L61,47 Z"/>
    <path android:fillColor="#FFFFFF" android:fillAlpha="0.9"
        android:pathData="M17,20 L22,20 L22,88 L17,88 Z"/>
</vector>
XML
cat > "$RES/mipmap-anydpi-v26/darktg_launcher.xml" <<'XML'
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/darktg_launcher_background"/>
    <foreground android:drawable="@drawable/darktg_launcher_foreground"/>
</adaptive-icon>
XML
cat > "$RES/mipmap-anydpi/darktg_launcher.xml" <<'XML'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#090812" android:pathData="M0,0h108v108h-108z"/>
    <path android:fillColor="#00D5FF" android:fillType="evenOdd"
        android:pathData="M20,15 L62,15 C85,15 101,32 101,54 C101,77 85,93 62,93 L20,93 Z M36,31 L36,77 L61,77 C75,77 84,68 84,54 C84,40 75,31 61,31 Z"/>
    <path android:fillColor="#8B5CF6"
        android:pathData="M62,25 L42,57 L56,57 L46,84 L76,47 L61,47 Z"/>
</vector>
XML
python3 - <<'PY'
from pathlib import Path
p = Path("android/app/src/main/AndroidManifest.xml")
s = p.read_text()
s = s.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/darktg_launcher"')
s = s.replace('android:label="darktg"', 'android:label="DARKTG"')
p.write_text(s)
PY
