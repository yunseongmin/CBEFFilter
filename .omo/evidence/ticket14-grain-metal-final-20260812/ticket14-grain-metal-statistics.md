# Ticket 14 Grain Metal Statistics

- fixture: grain-response-grid; CPU and Metal use the same 48 frame indices (0..47).
- same-frame max absolute pixel error: 1.94907e-05 (threshold <=2e-4, PASS)
- CPU mean bias: 0.000339639 stops; Metal mean bias: 0.000339625 stops (threshold |x|<2e-3, PASS)
- CPU RMS: 0.0221384 stops; Metal RMS: 0.0221384 stops (reference envelope 0.02128..0.02352, PASS)
- ensemble mean/RMS delta: 1.79647e-08 (threshold <=2e-4, PASS)
- resolution crops: 1080p, UHD, and 8K-height; identity/crop/padding/alpha contracts preserved.
- measured_profile_gate: false
