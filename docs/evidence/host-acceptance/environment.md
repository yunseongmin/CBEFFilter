# CBEF Filter v2 — Resolve Free host environment

- Date: 2026-08-12 (Asia/Seoul)
- Host: DaVinci Resolve 21.0.4 Free
- OS: macOS 26.5.2, Apple Silicon
- Installed bundle: `~/Library/OFX/Plugins/CBEFFilmEffects.ofx.bundle`
- Active user OFX path: `~/Library/OFX/Plugins`
- Binary: Mach-O 64-bit bundle arm64
- Binary SHA-256: `7f8ab4c1bf2957742034c2f84d3ff82967bacc88a4d6adf2803aa5a645304a89`
- Metallib SHA-256: `5ab83f9001b151e53a5296d667ad29fdf238c095da827a3799dce9610535d821`
- Resolve cache: binary `status=0`, OFX API 1, plug-in version 2.0, five stable effect IDs present.

## Discovery correction

The first normal launch did not have `OFX_PLUGIN_PATH`, so Resolve never scanned the user-level bundle. The same scan directory also contained a v1 backup with the same `CFBundleIdentifier` and five OFX IDs. The v1 backup was moved to `~/Library/OFX/CBEFBackups`, the user scan path was enabled, and Resolve was restarted. The next host log loaded all five v2 effects and rebuilt the cache.

## Current runtime gate

Discovery, Filter-context instance creation, and rendering pass. Resolve loaded all five stable v2 IDs. `Film Red`, `Neutral White (Artistic)`, strong Film Grain, Lens Reflections diagnostics, Anamorphic Optical Blur, and corrected `Generic White 2` Mist rendered on camera-original BRAW. The Mist edge-polarity defect and the Lens disconnected-Matte source fallback were fixed and re-observed in Resolve. The final installed bundle contains no runtime trace code or trace environment setting.

## Package note

The installed bundle and the validated build have identical binary/metallib hashes. `codesign --verify --deep --strict` passes on the installed bundle.

## Camera-original input

Resolve Free successfully imported `A002_05241837_C028.braw` as Blackmagic RAW, 12288×6480, 24 fps,
duration 00:00:04:07. The local copy was removed after QA; its URL and SHA-256 remain in the asset provenance.
