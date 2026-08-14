# Ticket 14 resume validation

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-grain-stock-cpu`: PASS.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make -B test-v2-grain-metal`: PASS; 48-frame parity and a 320x320 full-window case exercise the >256 render contract, max absolute error `4.48524952e-06`.
- CPU and Metal now share the stationary normalized Philox basis and retain exposure-linked population, clump, record covariance, MTF, and softness shaping.
- Metal host submission selects the direct v2 kernel for all Grain windows; the previous legacy lattice final is unreachable and is not used for output.
- M7 benchmark remains blocked by the direct kernel's unresolved UHD performance target; no performance gate is claimed from the previous legacy-lattice probe.
- The required 640x360 fast-path RED probe remains active. After aligning rotated atlas extents, exposure/process controls, record/population coordinate scaling, and per-octave asymmetry, its current maximum error is `7.12425e-02` at `(328,53)` channel 2. The fast atlas path is not claimed complete.
