# Direct verification judgment

The CPU Grain statistical contract passed. The Metal test did not pass: the required 640x360 benchmark-sized fast-path guard reports `atlas max=0.0712425 at (328,53) ch=2` and exits through the failure assertion. Therefore Ticket14 is not complete and no performance or parity completion claim is valid.

Observed compiler warnings are unused constants/locals in the in-progress atlas/lattice implementation; they do not change the failed verdict.
