# Ticket 16 Optical Aberration CPU Evidence

Date: 2026-08-12

## Implementation

- Preserved ticket 15 parameter ordinals 0–12 and appended `vignetting`, `coma`, `astigmatism`, `field_curvature`, `chromatic_aberration`, and `quality` as ordinals 13–18.
- Kept all profile labels generic and documented that controls are artistic, uncalibrated coefficients.
- Added smooth field-radius curvature, bounded radial/tangential coma and astigmatism weights, per-channel bilinear dispersion, explicit optical vignetting, and deterministic 2x2/4x4/8x8 aperture coverage for Preview/Balanced/Final.
- Added a dedicated public-seam contract target `test-v2-optical-aberration-cpu` covering CA 0/25/50/100, coma radial shift, astigmatism moments, Field Focus Bias center/rim behavior, quality repeatability and ordering, adjacent 4→5→6→7→8 px transitions (energy jump ≤0.5%, centroid jump ≤0.25 px, radius-normalized second-moment jump ≤3%), true 1080/UHD cropped windows at 0.5/1/2 render scale (normalized moment consistency ≤3%), odd padded nonzero-origin crops, sentinels, active signed HDR finite/no-upper-clamp behavior, straight and premultiplied alpha-bit preservation, transparent RGB non-leakage, no-wrap, diagnostics, and identity.

## Verification

Invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-optical-field-cpu
```

Observed:

```text
field center energy=1.003913 centroid=(96.0001,95.9995) corner energy=1.001220 centroid=(23.9190,23.9192) nearby centroid=(25.9215,23.9194) cat-eye axis 0.997569 -> 0.868457
aberration chromatic separation 0.00000 -> 1.94895, quality errors preview 0.003026 balanced 0.000901, vignette 0.74971 -> 0.16500
optical_field_psf_cpu_contract: PASS
```

Dedicated aberration invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-optical-aberration-cpu
```

Observed:

```text
aberration ca0=0.00000 ca100=1.24227 coma_shift=0.14658 astig_delta=0.10710 focus_corner_delta=1.02960
quality errors preview=0.005239 balanced=0.003864 final=0.000000
optical_aberration_cpu_contract: PASS
```

Regression invocation:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-m5-cpu test-v2-compile test-v2-inspector test
```

Observed: `optical_blur_render_contract: PASS (CPU + Metal M5 Optical Blur)`; typed compile, inspector metadata, and ABI probes exited 0. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B build` completed warning-free. The focused aberration contract printed `optical_aberration_cpu_contract: PASS` after all adjacent-transition, normalized-moment, active-HDR, and alpha/non-leak assertions.
