#!/bin/sh
set -eu

plugin_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if command -v luac >/dev/null 2>&1; then
  exec luac -p "$plugin_dir/Info.lua" "$plugin_dir/ExportFilter.lua" "$plugin_dir/PluginInfoProvider.lua"
fi
if command -v lua >/dev/null 2>&1; then
  exec lua -e 'for _, path in ipairs(arg) do local fn, err = loadfile(path); if not fn then error(err) end end' \
    "$plugin_dir/Info.lua" "$plugin_dir/ExportFilter.lua" "$plugin_dir/PluginInfoProvider.lua"
fi
python3 - "$plugin_dir/Info.lua" "$plugin_dir/ExportFilter.lua" "$plugin_dir/PluginInfoProvider.lua" <<'PY'
import sys

paths = sys.argv[1:]
required = {
    "Info.lua": ("LrExportFilterProvider", "LrPluginInfoProvider"),
    "ExportFilter.lua": ("postProcessRenderedPhotos", "LrTasks.execute", "renditionIsDone"),
    "PluginInfoProvider.lua": ("sectionsForTopOfDialog", "halation-engine"),
}

for path in paths:
    text = open(path, encoding="utf-8").read()
    if "\x00" in text:
        raise SystemExit(f"NUL byte in {path}")
    stack = []
    quote = None
    escaped = False
    for line_number, line in enumerate(text.splitlines(), 1):
        for char in line:
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
                continue
            if char in ("'", '"'):
                quote = char
            elif char in "({[":
                stack.append((char, line_number))
            elif char in ")}]":
                expected = {")": "(", "]": "[", "}": "{",
                }[char]
                if not stack or expected != stack[-1][0]:
                    raise SystemExit(f"unbalanced delimiter in {path}:{line_number}")
                stack.pop()
    if quote or stack:
        raise SystemExit(f"unclosed string/delimiter in {path}")
    for needle in required.get(path.rsplit("/", 1)[-1], ()):
        if needle not in text:
            raise SystemExit(f"missing {needle!r} in {path}")

print("Lua parser unavailable; delimiter and required-structure check passed for:")
for path in paths:
    print(path)
PY
