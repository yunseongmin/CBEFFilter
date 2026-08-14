# Mist Generic White 2 edge-polarity correction

## Reproduction

- Surface: public `cbef::render` CPU seam, then the actual Metal command-queue seam.
- Settings: `Generic White 2`, `DWG Intermediate`, Veil 88, Glow 82, Veil Contrast 68, Detail Retention 44, Mix 100.
- Fixture: non-negative high-contrast field (`0.08` background, `0.78` bright rectangle), matching the edge structure that exposed the Resolve BRAW artifact.
- Before the correction, the CPU output reached `-0.668271124` at a source value of `0.779999971`. With Detail Retention 100 the same point was `+0.234067485`, confirming the Detail branch as a major contributor rather than the sole cause.
- An isolated DWG Linear one-pixel line showed the independent signed-veil failure: Grade 2 scales Veil 88 by 1.20, so `O = S + 1.056(B-S)` assigns the source a negative coefficient.

## Root cause and correction

1. Generic White's signed `blur-source` branch was allowed to exceed interpolation weight 1.0.
2. Strong contrast reduction and the signed Detail residual were then summed without a positive-source floor.
3. A Rec.709-looking buffer interpreted as DWG Intermediate magnified the defect, but the same failure remained possible for valid HDR DWG Intermediate values.

The correction keeps signed veil interpolation at or below 1.0 and applies any excess strength to positive scatter only. The composite then preserves the signed HDR residual while bounding the positive branch with the compiled profile's black-retention coefficient. Generic White retention is 0.50, enough to prevent the bright exterior ring from exceeding the adjacent interior while retaining strong broad diffusion. `Detail Difference` reports the limiter-adjusted residual so Glow + Veil + Detail continues to reconstruct Final.

The initial Metal correction passed the exact-size fixture but a new `1056×576` regression, selected so its `352×192` one-third-resolution texture exercises the real pyramid branch, failed with `Generic White 2 Metal pyramid must not create negative-polarity outlines`. The pyramid was incorrectly using its downsampled source sample as the final retention reference. Both Metal finalizers now use the full-resolution `positive(original)` for final retention and signed-residual reconstruction; the UHD regression then passed.

## Observed corrected profile

On the same strong edge fixture:

- far background: `0.234067485`
- near background: `0.404019803`
- edge outside: `0.693472028`
- edge inside / center: `0.706770957`
- source maximum: `0.78`

The profile rises smoothly into the subject (`far < near < outside <= inside`), remains non-negative, does not exceed the source maximum, and retains a broad white veil rather than a dark/bright outline inversion.

## Verification

Final affected command:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test-v2-mist-cpu test-v2-mist-metal test-m4 build
```

Result:

```text
mist_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 11)
mist_v2_metal_ticket11: PASS
mist_render_contract: PASS
build/CBEFFilmEffects.ofx.bundle: replacing existing signature
```

`codesign --verify --deep --strict build/CBEFFilmEffects.ofx.bundle` also exited 0.

The regression gates now require CPU, exact Metal, and an actually executed UHD Metal pyramid render to preserve non-negative polarity, no maximum overshoot, and no bright exterior edge reversal. The CPU/exact path also locks CPU/Metal parity, broad veil monotonicity, and bounded signed Veil Only subtraction.
