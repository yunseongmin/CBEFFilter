# M0 Resolve Free load smoke

Status: passed on Resolve Free with a user-level OpenFX install.

## Observed environment

| Item | Observed value |
|---|---|
| Recorded at | 2026-08-12 (Asia/Seoul) |
| macOS | 26.5.2 (25F84) |
| DaVinci Resolve | Free 21.0.4 |
| GPU | Apple M3 Pro |
| Test project | `CBEF Film Effects QA` |

## Built and installed artifact

| Item | Result |
|---|---|
| Build and regression | Warning-free build; ABI and M1–M6 CPU + Metal suites pass |
| Architecture | `Mach-O 64-bit bundle arm64` |
| Bundle identifier | `com.cbef.filmeffects` |
| Bundle version | `2.0.0` |
| Binary SHA-256 | `29c89da940142293ab3b1b804868359e9de87767333b02093bb695ec9070b280` |
| User install | `~/Library/OFX/Plugins/CBEFFilmEffects.ofx.bundle` |
| Packaged notice | `Contents/Resources/THIRD_PARTY_NOTICES.md` present |

The ABI probe and Resolve log both verified this ordered set of effect IDs:

1. `com.cbef.filmeffects.halation`
2. `com.cbef.filmeffects.filmgrain`
3. `com.cbef.filmeffects.opticalblur`
4. `com.cbef.filmeffects.lensreflections`
5. `com.cbef.filmeffects.mistdiffusion`

## Resolve Free host smoke

Resolve was launched with the user-level OpenFX directory in `OFX_PLUGIN_PATH`. Its host log reported all five IDs as loaded. Searching for `CBEF` in the Color page OpenFX panel showed exactly five entries under `CBEF Film Effects`:

- CBEF Film Grain
- CBEF Halation
- CBEF Lens Reflections
- CBEF Mist Diffusion
- CBEF Optical Blur

`CBEF Halation` was dragged onto a Color page node. The active OpenFX settings panel displayed its Working Mode, Output View, Mix, Preset, Amount, Radius, Threshold, Highlights Only, Warmth, and Saturation controls. No Studio badge, watermark, or DCTL requirement was shown.

Evidence: Resolve log entries at 2026-08-12 06:28:20 for all five effect IDs and the retained
[host acceptance report](../evidence/host-acceptance/host-run-20260812.md). Large screenshot attachments were
removed after the final QA verdict.

## Installation note

The normal system-wide target, `/Library/OFX/Plugins`, is owned by `root:wheel`; unattended `sudo` was correctly refused because an administrator password is required. The host smoke therefore used the installed user-level bundle plus `OFX_PLUGIN_PATH` and did not bypass macOS authentication.

For normal launches without that environment variable, install the same tested bundle once with:

```sh
cd /Users/younseongmin/Documents/CBEF/CBEFFilter
sudo make install
```

Then restart Resolve normally.
