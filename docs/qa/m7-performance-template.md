# M7 Metal performance benchmark

Status: pending final M7 run after the Metal resource-lifetime implementation settles.

Run the complete benchmark from the plugin directory:

```sh
make benchmark-m7
```

The target builds the arm64 bundle and benchmark, then writes these artifacts under
`.omo/evidence/m7-performance-YYYYMMDD/` (override with `M7_OUTPUT_DIR=...`):

- `m7-performance.json` is the machine-readable result consumed by CI/review tooling.
- `m7-performance.md` is the readable summary with all case medians and memory gates.

The executable can also be run directly after an affected build:

```sh
build/tests/m7_performance_benchmark \
  --output-dir .omo/evidence/m7-performance-YYYYMMDD \
  --bundle build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx
```

## Contract

The harness obtains a real `MTLDevice` and owns one `MTLCommandQueue`. It refuses to
run a CPU backend: every request uses `MemoryKind::Metal`, `MetalRenderBackend`, and
must return `Enqueued`. A same-queue sentinel is committed and waited on before any
destination read. Source and destination `MTLBuffer`s are allocated once per
resolution and reused for all five effects.

Each effect runs default settings (`Final`, `Mix 100`, full frame) at 1920×1080 and
3840×2160. The source is a deterministic straight float RGBA fixture containing a
gradient, fine sinusoidal texture, center HDR highlight, and two edge HDR highlights.
There are three completed warmups followed by ten measured renders. Grain warmups use
frames 0, 1, 2 and measured renders use frames 3 through 12; all other effects use
frame 0. Each sample starts immediately before `render()` and ends after the
same-queue sentinel completes.

## Gates and evidence map

| Scenario | Invocation / binary | Observable | Artifact |
|---|---|---|---|
| Harness compilation | `make build/tests/m7_performance_benchmark` → `build/tests/m7_performance_benchmark` | exit 0, warning-free compile | `.omo/evidence/m7-performance-YYYYMMDD/build.log` |
| Five effects at 1080p | `make benchmark-m7` → benchmark binary | ten samples each, median ≤ 41.67 ms | `m7-performance.json` and `m7-performance.md` |
| Five effects at 4K | `make benchmark-m7` → benchmark binary | ten samples each, median ≤ 83.33 ms | `m7-performance.json` and `m7-performance.md` |
| Film Grain at 4K | same run | median ≤ 41.67 ms; Grain frame sequence 0–12 | `m7-performance.json` and `m7-performance.md` |
| Metal temporary memory | same run | peak minus baseline < 1 GiB per case | `m7-performance.json` (`temporary_peak_bytes`) |
| Metal steady memory | same run, after autorelease drain | steady minus baseline ≤ 8 MiB per case | `m7-performance.json` (`steady_delta_bytes`) |
| Provenance | same run | OS, GPU name, bundle path and SHA-256 recorded | `m7-performance.json` and `m7-performance.md` |

The process exits nonzero if Metal is unavailable, the bundle hash cannot be read,
any request is not enqueued on Metal, a sentinel fails, output is non-finite or
unchanged, a timing threshold fails, or either memory gate fails. The JSON always
contains every completed case and all ten timing samples for each completed case.
