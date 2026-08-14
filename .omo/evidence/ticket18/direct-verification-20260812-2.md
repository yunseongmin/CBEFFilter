# Ticket 18 direct verification attempt 2

Date: 2026-08-12

## Commands executed

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-lens-source-cpu test-m6-cpu test-v2-compile test-v2-inspector test
python3 -m unittest tests/quality_fixture_test.py
```

The forced rebuild completed successfully. The only diagnostics were existing unused-variable/constant warnings in grain and Metal code. The resulting target output included:

```text
lens_source_map_cpu_contract: PASS (v2 CPU source map + manual source)
lens_reflections_render_contract: PASS (CPU + Metal M6 Lens Reflections)
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
Ran 3 tests in 0.466s
OK
```

The freshly built binaries were then invoked directly:

```text
lens_source_map_cpu_contract exit=0
lens_reflections_render_contract exit=0
typed_compile_contract exit=0
inspector_metadata_contract exit=0
plugin_abi_probe exit=0
Ran 3 tests in 0.455s
OK
```

Judgment: PASS. This attempt directly verifies the focused CPU source/manual contract, M6 CPU+Metal regression, typed compile, Inspector metadata, bundled ABI load, and deterministic fixture suite after a forced rebuild.
