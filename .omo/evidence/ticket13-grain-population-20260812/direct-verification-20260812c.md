# Ticket 13 direct verification, third run with ABI failure repair

Date: 2026-08-12

The first ABI invocation in this run exposed a real compile failure in shared Optical CPU code: `opticalConvolve` had a six-offset implementation but two five-argument call sites, and its compatibility overload was unused. I repaired both call sites to pass per-channel six-element offsets, changed the implementation signature to `std::array<float, 6>`, and removed the unused overload.

| Scenario | Command | Result |
|---|---|---|
| Grain focused | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CBEF_GRAIN_EVIDENCE_DIR=.omo/evidence/ticket13-grain-population-20260812 make -B test-v2-grain-stock-cpu` | Exit 0; `grain_v2_stock_cpu_contract: PASS` |
| Fixture suite | `python3 -m unittest tests/quality_fixture_test.py` | Exit 0; 3 tests `OK` |
| ABI after repair | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test` | Exit 0; `plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)`; no `warning:` or `error:` lines in captured output |
| Evidence audit | Python audit of JSON and manifest | Exit 0; `metrics=12 hashes=2 all_pass=true measured_profile_gate=false` |

The initial failed ABI attempt is not counted as a pass. The repaired implementation was rebuilt and the final ABI, focused, fixture, and evidence audits all passed. CPU/Metal parity remains outside Ticket 13 and is not claimed.
