# Ticket 16 direct hook verification

Date: 2026-08-12

Invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build test-v2-optical-field-cpu test-v2-optical-aberration-cpu test-m5-cpu test-v2-compile test-v2-inspector test
```

Exit status: `0`

Observed output:

```text
optical_field_psf_cpu_contract: PASS
optical_aberration_cpu_contract: PASS
optical_blur_render_contract: PASS (CPU + Metal M5 Optical Blur)
plugin_abi_probe: PASS (five stable OpenFX effect descriptors + bundled Metal library)
```

The `build` target completed with no compiler or Metal warnings in the captured output. The aberration contract includes adjacent 4→5→6→7→8 px transition bounds, 1080/UHD and 0.5/1/2 render-scale normalized moments, active signed-HDR finite/no-upper-clamp checks, and straight/premultiplied alpha preservation plus transparent RGB non-leak checks.
