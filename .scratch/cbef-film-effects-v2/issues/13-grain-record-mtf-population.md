# 13 — 필름 그레인 Color Record와 입자 집단

**What to build:** 단일 노이즈장의 색 혼합 대신 노출에 반응하는 R/G/B record별 입자 집단, MTF와 covariance를 합성하여, 강한 설정에서도 디지털 점 노이즈가 아닌 필름 기록층의 질감으로 보이게 합니다.

**Blocked by:** 12 — 필름 그레인 Stock Response와 Capture Format.

**Status:** resolved

- [x] 노출 변화가 generic profile 곡선을 따라 RMS, 입자 크기, clumping과 색 record 반응을 서로 연관되게 바꿉니다.
- [x] R/G/B record가 공통 latent field와 compiled Cholesky covariance, record별 diameter/MTF gain으로 합성됩니다.
- [x] Film Resolution과 Grain Softness는 독립 branch로 노출되고 섀도·중간톤·하이라이트와 Exposure Bias를 통해 반응합니다.
- [x] 48-frame flat-field CPU suite가 mean bias, RMS, temporal correlation, radial PSD anisotropy, covariance, canonical diameter, non-DC peak, sparkle와 flicker gates를 통과합니다.
- [x] clump population과 bounded asymmetric density perturbation을 사용하며 기본·강한 설정의 sparkle/반복 peak 회귀 검사를 유지합니다.
- [x] optional Markdown evidence는 실제 stock 계측값이 아님을 `measured_profile_gate=false`로 표시합니다.

## Answer

기존 `format`, `amount`, `size`, `softness`, `chroma`, tone response, `seed`, `stock_response`, `scan_sampling`, `processing_modifier` ID와 ordinal을 유지하고, 16–18번에 `film_resolution`, `clump`, `exposure_bias`를 append했습니다. Stock/scan/processing 메타데이터는 Generic Fine/Balanced/Fast, 2K/4K/8K Equivalent, Generic Normal/Gentle/Enhanced (Uncalibrated)으로 정리했습니다.

CPU Grain synthesis는 fine·medium·coarse population envelope, exposure-linked diameter/clump, record별 diameter/MTF gain과 RGB covariance Cholesky를 사용합니다. 랜덤 생성기는 기존 Philox frame/seed counter를 유지하며, field 계산은 고정 회전 좌표로 lattice 축 편향을 줄입니다. 실제 stock 측정값이나 제품 profile을 주장하지 않도록 fixture와 통계 산출물은 placeholder로 표시했습니다.

## Implementation evidence

- [`ticket13-grain-statistics.md`](../../../.omo/evidence/ticket13-grain-population-20260812/ticket13-grain-statistics.md) and [`ticket13-grain-statistics.json`](../../../.omo/evidence/ticket13-grain-population-20260812/ticket13-grain-statistics.json), with per-metric value/threshold/pass/provenance fields.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CBEF_GRAIN_EVIDENCE_DIR=.omo/evidence/ticket13-grain-population-20260812 make -B test-v2-grain-stock-cpu` — PASS (48 frames; mean bias -1.4308e-05 stop; RMS 0.0223201 stop; neighbor correlation -0.0143415; anisotropy -1.33832 dB; covariance RG 0.87431/RB 0.871766; diameter 24.846; non-DC peak 1.70409; sparkle 0; flicker 0.000291024).
- `python3 -m unittest tests/quality_fixture_test.py` — 3 tests PASS; deterministic `grain-response-grid` fixture and manifest entry generated.
- `python3 -m unittest tests/quality_fixture_test.py` — 3 tests PASS after checked-in manifest regeneration.
- `make -B test-v2-compile test-v2-inspector test` — typed/Inspector/ABI PASS; stable five-effect bundle and bundled Metal library load.
- Existing Metal parity executable reaches CPU contracts but reports expected ticket14-owned CPU/Metal mismatch after CPU population changes; no Metal parity claim is made by this ticket.
