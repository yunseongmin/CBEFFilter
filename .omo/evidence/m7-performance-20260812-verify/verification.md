# M7 Grain verification

Date: 2026-08-12

## Build and focused contracts

Invocation:

```sh
make build test-m1 test-m3
```

Exit code: `0`

Captured output:

```text
"build/tests/headless_render_contract"
headless_render_contract: PASS (CPU + Metal M1 contract)
"build/tests/film_grain_render_contract"
film_grain_render_contract: PASS
```

Binary observables:

- `build/tests/headless_render_contract` passed the CPU + Metal M1 contract.
- `build/tests/film_grain_render_contract` passed the M3 CPU/Metal parity, alpha, identity, crop, and sentinel contract.

## Performance benchmark

Invocation:

```sh
make benchmark-m7 M7_OUTPUT_DIR=.omo/evidence/m7-performance-20260812-verify
```

The complete multi-effect benchmark exits `2` because unrelated Halation/Mist cases remain over their pre-existing thresholds. The Film Grain cases in the generated JSON pass independently:

| Case | Median | Timing | Temporary peak | Steady delta | Pass |
|---|---:|---|---:|---:|---|
| 1920x1080 | 8.4474 ms | true | 109,428,736 B | 262,144 B | true |
| 3840x2160 | 9.4767 ms | true | 109,166,592 B | 0 B | true |

Source artifact: `m7-performance.json` in this directory.

Judgment: the requested Grain production path is green under the 41.67 ms Grain threshold and below the 1 GiB temporary allocation limit; the aggregate benchmark failure is unrelated to Grain.
