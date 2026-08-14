# Ticket 08 evidence

Generated: 2026-08-12

## Build and focused behavior

Invocation (Xcode scoped):

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -j2 test-v2-halation-metal
```

Observable result:

```text
halation_v2_metal_ticket08: PASS
```

The focused binary renders a 97×61 v2 linear scene with local and global settings through CPU and Metal, compares every RGB sample to a 4e-4 internal tolerance, checks alpha bit preservation, then renders a 1024×576 strong local/global pyramid case with a cropped render window. The pyramid case verifies finite output, transparent hidden RGB suppression and crop-outside sentinel preservation.

Artifact: `build/tests/halation_v2_metal_ticket08`

## Arena and pyramid memory

Trace invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CBEF_FRAME_ARENA_TRACE_PATH=.omo/evidence/ticket08/halation-arena-trace-run1.jsonl \
make test-v2-halation-metal
```

The 1024×576 pyramid batch reaches `peak_in_flight_bytes=5,099,464` bytes. Its two largest temporary resources are 2,359,296 bytes each, corresponding to reusable half-resolution RGBA level buffers; no full-resolution RGBA scratch is allocated per scatter scale. The complete trace is in [halation-arena-trace-run1.jsonl](halation-arena-trace-run1.jsonl).

## Regression suites

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -j2 \
  test-v2-halation-cpu test-v2-halation-metal test-frame-arena test-m1 test-v2-compile test-v2-inspector test
```

Observed: CPU v2, focused Metal, Frame Arena, M1 headless Metal, typed compile, inspector metadata and ABI probe passed.

## Performance gate

The complete 3-warmup/10-sample benchmark is [m7-performance.md](../ticket08-m7/m7-performance.md) with machine-readable [JSON](../ticket08-m7/m7-performance.json).

Halation on the Apple M3 Pro measured median 16.34 ms at 1920×1080 and 111.12 ms at 3840×2160. The 1080p target passes; the UHD target is 83.33 ms, so the UHD timing gate fails by 27.79 ms. The failure is recorded without weakening the quality gate or claiming the ticket resolved.
