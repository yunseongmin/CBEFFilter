# Ticket 14 Grain Metal Statistics

- fixture: grain-response-grid; CPU and Metal use the same 48 frame indices (0..47).
- same-frame max absolute pixel error: 1.00285e-05 (threshold <=2e-4, PASS)
- CPU mean bias: -1.4308e-05 stops; Metal mean bias: -1.43195e-05 stops (threshold |x|<2e-3, PASS)
- CPU RMS: 0.0223201 stops; Metal RMS: 0.0223202 stops (reference envelope 0.02128..0.02352, PASS)
- ensemble mean/RMS delta: 1.23573e-08 (threshold <=2e-4, PASS)
- resolution crops: 1080p, UHD, and 8K-height; identity/crop/padding/alpha contracts preserved.
- measured_profile_gate: false
