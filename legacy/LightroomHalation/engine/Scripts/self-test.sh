#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "${HALATION_EVIDENCE_DIR:-}" ]]; then
  work="$HALATION_EVIDENCE_DIR"
  mkdir -p "$work"
else
  work="$(mktemp -d "${TMPDIR:-/tmp}/halation-self-test.XXXXXX")"
  trap 'rm -rf "$work"' EXIT
fi

python3 - "$work/input.ppm" <<'PY'
import sys
path = sys.argv[1]
w, h = 128, 96
with open(path, "wb") as f:
    f.write(f"P6\n{w} {h}\n255\n".encode())
    for y in range(h):
        for x in range(w):
            edge = max(0, 255 - int(((x - 64) ** 2 + (y - 48) ** 2) ** 0.5 * 4))
            f.write(bytes((edge, min(255, edge // 2 + 35), 18)))
PY

sips -s format png "$work/input.ppm" --out "$work/input.png" >/dev/null
"$root/.build/release/halation-engine" \
  --input "$work/input.png" --output "$work/output.png" \
  --halation-amount 0.9 --halation-radius 14 --threshold 0.45 \
  --softness 0.45 --warmth 0.8 --bloom-amount 0.5 --bloom-radius 18

test -s "$work/output.png"
sips -g pixelWidth -g pixelHeight "$work/output.png" >/dev/null
if cmp -s "$work/input.png" "$work/output.png"; then
  echo "self-test failed: output bytes are unchanged" >&2
  exit 1
fi
echo "self-test passed: $work/output.png"
