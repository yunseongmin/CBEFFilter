# Ticket 12 direct audit

Date: 2026-08-12
Working directory: `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin`

## Current metadata audit

Invocation: an arm64 C++ probe linked against the current `src/core/RenderCore.cpp`, printing parameter indices 13–15 from `effectDefinition(FilmGrain)`.

Observed:

```text
13 stock_response type=3 choices=3 range=0.00..2.00 default=choice:0
  Generic Fine
  Generic Balanced
  Generic Fast
14 scan_sampling type=3 choices=3 range=0.00..2.00 default=choice:1
  2K Equivalent
  4K Equivalent
  8K Equivalent
15 processing_modifier type=3 choices=3 range=0.00..2.00 default=choice:0
  Generic Normal
  Generic Gentle
  Generic Enhanced (Uncalibrated)
```

The Sol-plan metadata/type divergence previously recorded in issue 12 is no longer present in the current source. Ticket 13 has corrected the shared metadata to the planned Choice axes.

## Focused contract audit

Invocation:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
make -B test-v2-grain-stock-cpu
```

Observed result: exit 1.

```text
grain_v2_stock_cpu_contract: new grain axes must append after legacy parameter ordinals
make: *** [test-v2-grain-stock-cpu] Error 1
```

The focused test is stale against the ticket 13-expanded Grain definition: it still expects 16 parameters and sends a Double `scan_sampling` value, while the current definition has indices 13–18 and Choice scan sampling. Therefore ticket 12 cannot be marked complete from this audit. The shared test/metadata owner must update the focused contract and rerun it.

## Inspector regression

Invocation:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
make -B test-v2-inspector
```

Observed result: exit 0. The command rebuilt the current arm64 bundle and completed `inspector_metadata_contract` successfully; four non-fatal unused-constant warnings remain in `RenderCore.cpp`.

## Issue status

`.scratch/cbef-film-effects-v2/issues/12-grain-stock-capture-format.md` remains `Status: needs-triage`. That status is correct until the stale focused test is brought to the expanded indices/types and passes.
