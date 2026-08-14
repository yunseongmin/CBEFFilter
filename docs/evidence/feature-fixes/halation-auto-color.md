# Halation Auto color verification — 2026-08-12

## Scope

- Added `Auto (Scene Adaptive)` as `Color Emphasis` ordinal 4. Existing ordinals 0–3, default 0, and all five preset ordinals remain unchanged.
- Added explicit `HalationColorMode` compilation and a mirrored `uint32_t color_mode` Metal ABI field.
- Auto analyzes the already spatially smoothed raw local/global halo RGB at each output pixel. It adds no pass, CPU readback, histogram, history, or random state.
- Auto blends Film Red, Warm Amber, and artistic Neutral White targets with bounded smoothstep weights, normalizes the target to unit scene-linear halo luminance, then uses `Color Strength` to blend from Profile Relative.

## Formula

For normalized positive raw halo chroma `r,g,b`:

- `warm = smoothstep(0.24, 0.48, r-b) * smoothstep(0.12, 0.20, g-b)`
- `cool = smoothstep(0.30, 0.55, max(b-r, g-r))`
- `amber = (1-cool) * warm`
- `red = 1-cool-amber`
- target = `red*(1,.16,.04) + amber*(1,.55,.12) + cool*(1,1,1)`, normalized by the existing scene-linear Halation luminance coefficients.

Auto target classification, normalization, and final emphasis blend use the same explicit float constants and operation order in CPU and Metal. The pre-existing Profile Relative and fixed manual color path intentionally remains unchanged and retains its prior CPU double-valued intermediates before float frame storage.

## TDD record

- Initial RED: `make test-v2-halation-cpu` failed at the metadata contract because only four choices existed.
- First implementation exposed an actual model error: neutral halo was over-classified as amber after channel-dependent scatter. Public-render observation showed neutral local normalized deltas `r-b=0.211`, `g-b=0.109`, versus tungsten `r-b=0.568`, `g-b=0.212`. The continuous boundaries above separate those responses without a hard class switch.

## Verification

All commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

- `make test-v2-halation-cpu` — PASS, exit 0. Covers metadata ordinals/default; bit-exact hex goldens for Profile Relative, Film Red, Warm Amber, and Neutral White; neutral/tungsten/blue/green Auto tendency; annulus luminance within `3e-5`; boundary continuity within `0.015` normalized chroma distance; linear Color Strength; Source Mask bit equality; finite/unclamped signed HDR; negative residual preservation; straight/premultiplied alpha bits; zero-alpha hidden RGB no-leak; crop; no-wrap; and resolution behavior.
- `make test-v2-halation-metal` — PASS, exit 0. Representative Auto CPU/Metal maximum errors: neutral `1.78814e-07`, tungsten `5.96046e-08`, blue `7.45058e-09`, green `2.98023e-08`, signed premultiplied/hidden-RGB `2.98023e-08`; all below `2e-4`. Auto also runs through the cropped strong pyramid, all wide diagnostics/working modes, and the real 1024×576 wide aggregate path. The existing wide aggregate gate records CPU/Metal energy and centroid directionality; it is not claimed as a `2e-4` pixel parity test.
- `make test-v2-compile` — PASS, exit 0.
- `make test-v2-inspector` — PASS, exit 0; bundle relinked and ad-hoc signed without warnings.
- `make build` — PASS, exit 0.
- `make test` — PASS, exit 0; `plugin_abi_probe` reports five stable OpenFX descriptors and bundled Metal library.
- `make test-m2` — PASS, exit 0; `halation_render_contract: PASS (CPU + Metal M2 Halation)`.

## Full integration and performance

- `CBEF_V2_EVIDENCE_DIR=.omo/evidence/v2-final-auto-color-20260812 make verify-v2` — PASS, exit 0. The final verdict is `passed`; all five CPU/Metal effects, the 48-frame Grain contract, 8K/12K integration, package/signature checks, and the complete performance/memory matrix passed.
- Halation 1920×1080: median `9.7157 ms`, scratch `41,304,064 B`, post-warmup arena growth `0 B`.
- Halation 3840×2160: median `50.9183 ms`, scratch `164,888,576 B` below the `160 MiB` gate (`167,772,160 B`), post-warmup arena growth `0 B`.
- The verified bundle and installed user-level bundle have identical SHA-256 values: executable `895d9019d5e65fc6cbf6b9a7931f5c0bd33d620e59d726b75604513d89672e0d`; metallib `f214acd4f4943f0d92de49f9c22cc3dd4d47d42f9d02f16fe16925154316271a`. Both pass deep/strict code-signature validation.

## Resolve 21 Free manual QA — official Wetsuit BRAW

- Loaded the installed bundle in DaVinci Resolve 21 Free; the Resolve log records all five `com.cbef.filmeffects.*` IDs loading, including Halation, with no CBEF render error during the test.
- Applied CBEF Halation to `Wetsuit.braw`, disabled the pre-existing Lens/Mist instances, selected `Auto (Scene Adaptive)`, and used a deliberately visible stress setting: Strength `130`, Local Radius `1.2`, Source Limit `0.5`, Source Smoothness `70`, Global Diffusion `40`, Color Strength `100`, Mix `100`.
- With Halation disabled the BRAW frame remains neutral. With Auto enabled, the bright hand, watch, collar, hair, and frame-edge highlights receive a coherent warm red/amber halo rather than a white wash. `Halation Only` removes the source image and shows only the same spatially aligned red/amber contribution.
- Scrubbed to another frame and completed approximately four looped playbacks of the 3 s 11 f clip; the instance stayed active, the viewer returned the expected colored result, and Resolve logged no CBEF failure or source fallback.
- The off/final/Halation Only observations are retained above; the large screenshot attachments were removed
  after acceptance.
