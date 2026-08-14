# Ticket 02 evidence

Date: 2026-08-12

## Focused public render-contract scenario

Invocation:

```text
make -C DaVinciFilmPlugin test-v2-compile
```

Observable:

```text
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -Isrc/core -c "src/core/RenderCore.cpp" -o "build/obj/core/RenderCore.o"
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -Isrc/core "tests/typed_compile_contract.cpp" "build/obj/core/RenderCore.o" -o "build/tests/typed_compile_contract"
"build/tests/typed_compile_contract"
```

Result: exit 0. The focused executable rendered all five stable effects through `render(RenderRequest, CpuRenderBackend)`, verified Mix-zero pixel identity and source immutability, finite output, non-finite setting rejection, and cross-effect settings mismatch rejection.

Artifact: `build/tests/typed_compile_contract`

## Affected core compile scenario

Invocation:

```text
xcrun clang++ -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -fsyntax-only -I DaVinciFilmPlugin/include -I DaVinciFilmPlugin/src/core DaVinciFilmPlugin/src/core/RenderCore.cpp
```

Result: exit 0 with no diagnostics.

## Full plugin build attempt

Invocation:

```text
make -C DaVinciFilmPlugin build
```

Result: blocked before link because this machine's `xcrun` cannot locate the Metal compiler:

```text
xcrun -sdk macosx metal -c "src/metal/kernels/CBEFFilmEffects.metal" -o "build/obj/metal/CBEFFilmEffects.air"
xcrun: error: unable to find utility "metal", not a developer tool or in PATH
make: *** [build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib] Error 72
```

This is an environment/toolchain blocker at the precompiled Metal library step; the changed core translation unit and focused CPU contract compiled successfully.

## Changed files

- `src/core/RenderPlan.h`
- `src/core/RenderCore.cpp`
- `tests/typed_compile_contract.cpp`
- `Makefile`
- `.scratch/cbef-film-effects-v2/issues/02-typed-compiled-effect-expand.md`

## Fresh stop-hook verification

Invocation:

```text
make -C DaVinciFilmPlugin test-v2-compile
xcrun clang++ -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -fsyntax-only -I DaVinciFilmPlugin/include -I DaVinciFilmPlugin/src/core DaVinciFilmPlugin/src/core/RenderCore.cpp
make -C DaVinciFilmPlugin build
```

Observed exit statuses from the same verification run:

```text
focused_exit=0
syntax_exit=0
xcrun: error: unable to find utility "metal", not a developer tool or in PATH
build_exit=2
```

The focused CPU contract and core syntax check are green. The full plugin build is not green in this environment because the required Xcode Metal CLI is unavailable; this is an explicit blocker, not a passed build.

## Second fresh verification

Invocation:

```text
xcode-select -p
xcrun --find clang++
xcrun --find metal
make -C DaVinciFilmPlugin test-v2-compile
make -C DaVinciFilmPlugin build
```

Observed:

```text
/Library/Developer/CommandLineTools
/Library/Developer/CommandLineTools/usr/bin/clang++
xcrun: error: unable to find utility "metal", not a developer tool or in PATH
typed_binary=present
evidence=present
focused_exit=0
make: *** [build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib] Error 72
build_exit=2
```

Judgment: the focused CPU implementation is verified, but the ticket is not fully complete because the required full plugin build and Metal contract cannot execute without an Xcode installation that provides the Metal compiler. Ticket status was reverted to `ready-for-agent` until that toolchain blocker is removed.

## Third fresh verification

Invocation:

```text
find /Applications /Library/Developer /Users/younseongmin -maxdepth 5 -type d \\
  \\( -name 'Xcode.app' -o -name 'Xcode-beta.app' -o -name 'CommandLineTools' \\) 2>/dev/null | sort
xcode-select -p
DEVELOPER_DIR=/Library/Developer/CommandLineTools xcrun --find metal
make -C DaVinciFilmPlugin test-v2-compile
make -C DaVinciFilmPlugin build
```

Observed:

```text
/Library/Developer/CommandLineTools
xcrun: error: unable to find utility "metal", not a developer tool or in PATH
focused_exit=0
xcrun -sdk macosx metal -c "src/metal/kernels/CBEFFilmEffects.metal" -o "build/obj/metal/CBEFFilmEffects.air"
xcrun: error: unable to find utility "metal", not a developer tool or in PATH
build_exit=2
```

No full Xcode developer directory exists under the checked locations. The build failure is an external toolchain blocker that cannot be fixed by source changes in this workspace. This attempt does not claim completion.
