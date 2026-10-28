#!/usr/bin/env bash
# Retain meaningful diagnostics via check annotations when log storage is unreachable.
set -uo pipefail
log=$(mktemp)
godot "$@" > "$log" 2>&1
result=$?
cat "$log"
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$log"; then result=1; fi
if [ "$result" -ne 0 ]; then
  python3 - "$log" <<'PY'
import sys
from pathlib import Path
s = Path(sys.argv[1]).read_text(errors='replace')[-12000:]
# Chunk annotations so diagnostics are not truncated at 4096 characters.
for i in range(0, len(s), 3500):
    chunk = s[i:i+3500].replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print('::error::' + chunk)
PY
fi
rm -f "$log"
exit "$result"
