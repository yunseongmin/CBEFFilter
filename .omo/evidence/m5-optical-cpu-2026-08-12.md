# M5 Optical Blur CPU evidence

- Scenario: `make test-m5-cpu` builds and executes `build/tests/optical_blur_render_contract` through the public `cbef::render` CPU seam.
- Observable: exit status 0 and `optical_blur_render_contract: PASS`.
- Coverage: definition/preset expansion and exact identity; aperture unit sum, centroid, constant preservation, anamorphism second moment; 4x4 analytic polygon support IoU >= 0.95; highlight response monotonicity; HDR finite output, alpha preservation, transparent hidden-RGB suppression; H=1080/H=2160 matched-crop PSNR >= 45 dB, canonical radius and energy.
- Artifact: `.omo/evidence/m5-optical-test-cpu-2026-08-12.log`

- Scenario: `make -B build` compiles the plugin bundle and CPU/Metal objects with project warning flags.
- Observable: exit status 0; compilation and link log contains no warning diagnostics.
- Artifact: `.omo/evidence/m5-optical-build-2026-08-12.log`

- Regression scenario: `make test-m1-cpu test-m2 test-m3-cpu test-m4-cpu build`.
- Observable: M1, M2, M3, M4 focused suites pass and build exits 0.
