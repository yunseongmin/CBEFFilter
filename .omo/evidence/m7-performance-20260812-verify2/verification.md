# Independent M7 Grain verification

Date: 2026-08-12

## Contracts

Command:

```sh
make build test-m1 test-m3
```

Exit: `0`

Observed output:

```text
"build/tests/headless_render_contract"
headless_render_contract: PASS (CPU + Metal M1 contract)
"build/tests/film_grain_render_contract"
film_grain_render_contract: PASS
```

## Benchmark

Command:

```sh
make benchmark-m7 M7_OUTPUT_DIR=.omo/evidence/m7-performance-20260812-verify2
```

The aggregate command exits `2` because the existing 4K Halation and Mist cases exceed their thresholds. The generated JSON records these Grain cases as independently passing:

| Resolution | Median ms | Temporary peak bytes | Steady delta bytes | Grain pass |
|---|---:|---:|---:|---|
| 1920x1080 | 6.8575 | 109428736 | 262144 | true |
| 3840x2160 | 9.4187 | 109166592 | 0 | true |

JSON artifact: `m7-performance.json` in this directory.

Judgment: M7 Film Grain meets its 41.67 ms timing threshold, stays below the 1 GiB temporary allocation limit, and remains green in the M1/M3 CPU–Metal contract. Aggregate failures are unrelated effects.
