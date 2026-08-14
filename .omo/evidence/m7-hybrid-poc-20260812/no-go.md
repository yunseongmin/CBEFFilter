# M7 Mist hybrid POC: NO-GO

The hybrid path was removed after the required performance gate failed. The first complete benchmark invocation was:

```text
make benchmark-m7 M7_OUTPUT_DIR=.omo/evidence/m7-hybrid-poc-20260812-r3
```

The captured benchmark is [m7-performance.md](../m7-hybrid-poc-20260812-r3/m7-performance.md) with machine-readable data in [m7-performance.json](../m7-hybrid-poc-20260812-r3/m7-performance.json). Mist Diffusion measured 86.14 ms at 3840x2160 against the 83.33 ms M7 gate (temporary peak 663,552,000 bytes and steady delta 0 bytes). This is a timing-gate failure, so the hybrid structs, kernels, host allocations, eligibility gate, and hybrid parity fixture were removed and the stable buffer-fused path restored.

Post-removal focused validation:

```text
make test-m4
```

Observed binary output: `mist_render_contract: PASS`.
