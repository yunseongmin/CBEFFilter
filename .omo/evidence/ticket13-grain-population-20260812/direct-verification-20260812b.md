# Ticket 13 direct verification, second independent run

Date: 2026-08-12

Working directory: `/Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin`.

| Check | Exact command | Actual result |
|---|---|---|
| CPU Grain contract | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CBEF_GRAIN_EVIDENCE_DIR=.omo/evidence/ticket13-grain-population-20260812 make -B test-v2-grain-stock-cpu` | Exit 0; `grain_v2_stock_cpu_contract: PASS` |
| Quality fixtures | `python3 -m unittest tests/quality_fixture_test.py` | Exit 0; `Ran 3 tests ... OK` |
| Typed/Inspector/ABI | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-compile test-v2-inspector test` | Exit 0; typed and Inspector executables completed; `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)` |
| Evidence JSON and hashes | Python audit requiring 12 metrics with `id`, `value`, `threshold`, `pass`, `provenance`, `measured_profile_gate=false`, plus manifest frame/mask SHA matches | `evidence-audit: PASS; metrics=12; hashes=2; measured_profile_gate=false` |

The Metal parity contract is intentionally not claimed here because CPU population changes are owned by Ticket 13 and Metal parity is Ticket 14.
