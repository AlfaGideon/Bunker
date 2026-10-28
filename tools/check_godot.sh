#!/usr/bin/env bash
# Retain meaningful diagnostics via check annotations when log storage is unreachable.
set -uo pipefail
log=$(mktemp)
timeout "${GODOT_TIMEOUT:-120}" godot "$@" > "$log" 2>&1
result=$?
cat "$log"
if grep -Eq 'SCRIPT ERROR|Parse Error|Failed to load script' "$log"; then result=1; fi
if [ "$result" -ne 0 ]; then
  python3 - "$log" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(errors='replace')
first = text.find('SCRIPT ERROR')
if len(text) > 12000:
    start = max(0, first)
    s = text[start:start + 7000] + '\n... final diagnostics ...\n' + text[-5000:]
else:
    s = text
# Chunk annotations so diagnostics are not truncated at 4096 characters.
for i in range(0, len(s), 3500):
    chunk = s[i:i+3500].replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print('::error::' + chunk)
PY
fi
rm -f "$log"
exit "$result"
