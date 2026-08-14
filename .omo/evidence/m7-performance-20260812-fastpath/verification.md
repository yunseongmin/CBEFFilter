# M7 Gaussian fast-path verification

- Build: `make build` exited 0 (`build.log`).
- M1/M2/M4 focused suites: `make test-m1 test-m2 test-m4` exited 0; M2 and M4 include the original non-aligned/fallback fixture plus an alignment-qualified width-16 paired-tap parity fixture (`focused-tests.log`). The fixtures assert CPU/Metal RGB error <= 2e-4, crop preservation, alpha bit preservation, transparent hidden RGB, and row-padding contracts.
- Full M7 benchmark: `make benchmark-m7 M7_OUTPUT_DIR=.omo/evidence/m7-performance-20260812-fastpath` produced `m7-performance.json` and `.md`.
- Measured 4K gates: Halation median 86.0949 ms (83.33 ms threshold); Mist Diffusion median 122.733 ms (83.33 ms threshold). Both timing gates remain above threshold after the single implementation benchmark run.
- Resource gates: Halation temporary peak 398,131,200 bytes and steady delta 0; Mist temporary peak 663,552,000 bytes and steady delta 0. Both pass the benchmark resource limits.
