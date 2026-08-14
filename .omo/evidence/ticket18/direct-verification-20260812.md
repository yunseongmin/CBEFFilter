# Ticket 18 direct verification

Verification was rerun from the shared worktree on 2026-08-12 with Xcode selected explicitly through `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

Command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -s test-v2-lens-source-cpu test-m6-cpu test-v2-compile test-v2-inspector test
python3 -m unittest tests/quality_fixture_test.py
```

Observed output:

```text
lens_source_map_cpu_contract: PASS (v2 CPU source map + manual source)
lens_reflections_render_contract: PASS (CPU + Metal M6 Lens Reflections)
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
Ran 3 tests in 0.460s
OK
```

The typed compile and Inspector targets exited successfully without a failure line; the ABI probe loaded the freshly built bundle and bundled Metal library. Source inspection in the same run confirmed `detectLensSources`, `manualLensMatte`, `DiagnosticView::SourceMap`, appended `source_mode`, and the `test-v2-lens-source-cpu` Make target are present. This is direct evidence for the reported ticket18 implementation and its focused CPU, M6 regression, typed, Inspector, ABI, and fixture gates.

The direct binary rerun also recorded explicit zero exits:

```text
lens_source_map_cpu_contract 0
lens_reflections_render_contract 0
typed_compile_contract 0
inspector_metadata_contract 0
plugin_abi_probe 0
Ran 3 tests in 0.461s
OK
```
