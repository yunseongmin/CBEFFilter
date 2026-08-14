# Ticket 13 direct verification

Date: 2026-08-12

All commands were run from `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for Xcode-backed targets.

| Scenario | Invocation | Observable result | Verdict |
|---|---|---|---|
| Grain CPU focused contract | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CBEF_GRAIN_EVIDENCE_DIR=.omo/evidence/ticket13-grain-population-20260812 make -B test-v2-grain-stock-cpu` | Recompiled `RenderCore.cpp` and `grain_v2_stock_cpu_contract`; `grain_v2_stock_cpu_contract: PASS` | PASS |
| Fixture regression | `python3 -m unittest tests/quality_fixture_test.py` | `Ran 3 tests ... OK` | PASS |
| Typed compiler, Inspector, bundle ABI | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-compile test-v2-inspector test` | typed contract executable completed; Inspector executable completed; `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)` | PASS |
| Fixture evidence schema | Python JSON/hash audit | 12 metrics; every metric has `id`, `value`, `threshold`, `pass`, `provenance`; all pass values are true; frame and mask hashes match manifest | PASS |

The focused evidence reports 48 frames, mean bias `-1.4308e-05` stop, RMS `0.0223201` stop within `0.02128..0.02352`, neighbor correlation `-0.0143415`, anisotropy `-1.33832 dB`, covariance RG/RB `0.87431/0.871766`, canonical diameter `24.846` against placeholder target `25 +/-10%`, non-DC peak `1.70409`, sparkle fraction `0`, flicker RMS `6.39394e-05`, and flicker peak `0.000291024`.

The evidence is a synthetic generic profile and explicitly keeps `measured_profile_gate=false`; it is not a measured film-stock claim. CPU/Metal parity remains Ticket 14's ownership after the CPU population model change and is not claimed by this verification.
