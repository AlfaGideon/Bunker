#!/usr/bin/env bash
set -euo pipefail
apk=${1:?Usage: verify_apk.sh APK}
test -s "$apk"
unzip -tq "$apk" | tail -1
tools=$(find "$ANDROID_HOME/build-tools" -name aapt -printf '%h\n' | sort -V | tail -1)
test -n "$tools"
"$tools/aapt" dump badging "$apk" > /tmp/bunker-unity-badging.txt
grep -q "package: name='org.bunker.unityprototype'" /tmp/bunker-unity-badging.txt
if ! grep -q "^launchable-activity: name='com.unity3d.player.UnityPlayerActivity'" /tmp/bunker-unity-badging.txt; then
  echo '::error::APK has no Unity launcher activity; Android cannot open it.'
  exit 1
fi
"$tools/apksigner" verify "$apk"
dexdir=$(mktemp -d)
trap 'rm -rf "$dexdir"' EXIT
unzip -l "$apk" > "$dexdir/files.txt"
grep -q 'libunity.so' "$dexdir/files.txt"
unzip -q "$apk" 'classes*.dex' -d "$dexdir"
for dex in "$dexdir"/*.dex; do "$tools/dexdump" -f "$dex"; done > "$dexdir/dexdump.txt"
grep -q 'Lorg/bunker/unityprototype/RadioSpeech;' "$dexdir/dexdump.txt"
hash=$(sha256sum "$apk" | cut -d' ' -f1)
bytes=$(stat -c %s "$apk")
echo "::notice::Unity prototype APK: $bytes bytes; SHA-256: $hash"
