# M3 Film Grain CPU direct audit

- Repository: /Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin
- Current attempt lookup: `omo ulw-loop status --json` reported `ULW_LOOP_PLAN_MISSING`; no active currentAttemptDir exists, so evidence is under `.omo/evidence/`.
- Build invocation: `make -B build`
- Build exit status: 0
- Focused invocation: `make -B test-m3-cpu`
- Focused test exit status: 0
- Captured output: /Users/younseongmin/Documents/CBEF/DaVinciFilmPlugin/.omo/evidence/m3-film-grain-cpu-direct-audit-2026-08-12.log
- Captured output bytes: 4078
- Audit exit status: 0
- Judgment: PASS. The arm64 bundle rebuild and focused public CPU Film Grain contract both passed in this audit.
