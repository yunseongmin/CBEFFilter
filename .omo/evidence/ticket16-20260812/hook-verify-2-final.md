# Ticket 16 direct verification attempt 2

Date: 2026-08-12

The first rerun exposed a real warning in the forced rebuild: an unused `sigma` parameter in `softenedLatticeGaussian`, followed by the now-unused softness forwarding value. The parameters were behaviorally unused; they were removed from the private grain helper signatures without changing the lattice calculation.

Final forced rebuild invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build test-v2-optical-aberration-cpu
```

Final result: exit code `0`; no `warning:` lines were emitted.

Observed final output:

```text
optical_aberration_cpu_contract: PASS
EXIT_CODE=0
```

Regression invocation after the warning fix:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-optical-field-cpu test-m5-cpu test-v2-compile test-v2-inspector test
```

Regression result: exit code `0`.

Observed regression output:

```text
optical_field_psf_cpu_contract: PASS
optical_blur_render_contract: PASS (CPU + Metal M5 Optical Blur)
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
```
