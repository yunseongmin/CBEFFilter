# 16 — 광학 수차와 결정적 품질 모드

**What to build:** 화면 위치별 PSF에 generic coma·astigmatism과 색수차를 더하고, Preview·Balanced·Final이 재생성과 최종 품질을 예측 가능하게 바꾸도록 합니다.

**Blocked by:** 15 — 화면 위치별 광학 PSF와 Cat-eye.

**Status:** resolved

- [x] Coma, astigmatism, chromatic aberration과 optical vignetting이 generic artistic control로 제공되고 실제 렌즈 calibration을 암시하지 않습니다.
- [x] 색수차 0에서는 channel centroid가 정렬되고 값을 올리면 분리가 연속적이고 단조롭게 증가합니다.
- [x] center·rim·corner와 여러 방위각에서 PSF energy, centroid, second moment와 수차 방향이 profile envelope 안에 있습니다.
- [x] Preview·Balanced·Final은 같은 입력과 설정에서 결정적이며 품질을 높일수록 sample budget과 기준 오차가 정의된 방향으로 개선됩니다.
- [x] 작은 반경과 큰 반경의 경계에서 밝기, PSF 크기 또는 위치가 튀지 않고 해상도·Render Scale 일관성을 유지합니다.
- [x] HDR·signed RGB, alpha, 투명 edge, crop, odd dimensions, no-wrap와 identity 계약을 CPU reference에서 통과합니다.

Evidence: `.omo/evidence/ticket16-20260812/ticket16-optical-aberration-cpu.md`

Answer: The CPU reference now provides generic, explicitly uncalibrated field character controls. Chromatic dispersion is zero-aligned and monotonic, coma and astigmatism alter radial/tangential PSF moments, Field Focus Bias changes only the rim response, and vignetting is an independent gain. Quality modes are deterministic and ordered by sample density. The focused contract covers 1080/UHD cropped data windows, render scales, padded odd origins, crop sentinels, signed HDR, alpha, no-wrap, diagnostics, and identity.
