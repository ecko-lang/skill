#!/usr/bin/env bash
# Every code sample in this skill is verified.
#   ```ecko        -> must RUN cleanly (offline, mock mode)
#   ```ecko-check  -> must pass `ecko check` (for servers and other blocking programs)
set -u
ECKO=${ECKO:-ecko}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for md in "$@"; do
  python3 - "$md" "$TMP" <<'PY'
import sys, os, re
md, tmp = sys.argv[1], sys.argv[2]
src = open(md).read()
base = os.path.basename(md).replace('.md', '')
for i, m in enumerate(re.finditer(r'```(ecko-check|ecko)\n(.*?)```', src, re.S)):
    kind = 'chk' if m.group(1) == 'ecko-check' else 'run'
    open(os.path.join(tmp, f"{base}__{kind}__{i:03d}.ecko"), 'w').write(m.group(2))
PY
done
fail=0; total=0
for f in "$TMP"/*.ecko; do
  [ -e "$f" ] || continue
  total=$((total+1))
  case "$(basename "$f")" in
    *__chk__*) cmd=(check) ;;
    *)         cmd=() ;;
  esac
  if ! out=$(cd "$TMP" && "$ECKO" "${cmd[@]}" "$f" 2>&1); then
    fail=$((fail+1)); echo "FAIL $(basename "$f")"; echo "$out" | head -4 | sed 's/^/     /'
  fi
done
echo "--- $((total-fail))/$total blocks verified ---"
[ $fail -eq 0 ]
