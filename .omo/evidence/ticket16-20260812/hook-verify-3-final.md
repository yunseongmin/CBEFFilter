# Ticket 16 direct verification attempt 3

Date: 2026-08-12

Direct artifact invocations:

```text
./build/tests/optical_field_psf_cpu_contract
./build/tests/optical_aberration_cpu_contract
```

Observed output:

```text
optical_field_psf_cpu_contract: PASS
optical_aberration_cpu_contract: PASS
```

The field contract also reported center energy `1.003913`, corner energy `1.001220`, and deterministic quality errors `0.003026` (Preview) and `0.000901` (Balanced). The aberration contract reported CA separation `0.00000 -> 1.24227`, coma shift `0.14658`, astigmatism delta `0.10710`, and focus-corner delta `1.02960`.

Warning check:

```text
rg -n "warning:" /tmp/cbef-ticket16-hook-verify-2-clean2.log
```

Observed: no warning lines. Combined direct verification exit code: `0`.
