# Ticket 07 direct verification rerun 3

Timestamp: 2026-08-12T04:45:13Z

This is a fresh execution after the third stop-hook challenge. Existing evidence was not used as a substitute for execution.

## Command results

```text
[1] xcrun metal
/var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.6.109.0.6RC9iZ/Metal.xctoolchain/usr/bin/metal
[2] xcrun metallib
/var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-v17.6.109.0.6RC9iZ/Metal.xctoolchain/usr/bin/metallib
[3] CPU focused
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
[4] typed and inspector
typed_compile_contract exited 0
inspector_metadata_contract exited 0
[5] ABI
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
```

Commands executed:

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-halation-cpu`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-compile test-v2-inspector`
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test`

The affected bundle build was performed by the Inspector target and completed with arm64 link output plus fresh `metal`/`metallib` compilation.

## Artifact checks

Each artifact passed `test -s` and was measured with `stat -f '%z %N'`:

```text
116760 build/tests/halation_v2_cpu_contract
115864 build/tests/typed_compile_contract
116344 build/tests/inspector_metadata_contract
38016 build/tests/plugin_abi_probe
342160 build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx
237249 build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib
```

Judgment: all requested ticket 07 CPU/typed/Inspector/ABI checks passed in this third direct run. This remains CPU-reference evidence; ticket 08 owns Metal v2 effect parity.
