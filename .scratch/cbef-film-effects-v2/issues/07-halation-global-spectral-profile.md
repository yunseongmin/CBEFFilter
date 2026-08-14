# 07 — 할레이션 광역 산란과 채널 profile

**What to build:** 국소 할레이션에 더 넓고 약한 광역 산란과 profile-relative 채널 반응을 더하여, 강도를 높여도 단색 테두리나 흰 안개가 아닌 한 가지 필름 재료처럼 이어지게 합니다.

**Blocked by:** 06 — 장면 반응형 할레이션 광원과 국소 산란.

**Status:** resolved

- [x] Local Radius와 Global Diffusion을 독립적으로 조절하고 Halation Only, Local Only, Global Only를 비교할 수 있습니다.
- [x] Local Only와 Global Only의 합이 정한 내부 허용치 안에서 Halation Only를 재구성합니다.
- [x] Red Bias와 Blue Compensation은 generic profile에 상대적인 예술 제어로 표시되며 실제 stock 측정값으로 주장되지 않습니다.
- [x] 채널별 반경·에너지와 다중 스케일 감쇠가 연속적이고 finite하며, 강한 설정에서도 중심 재착색과 화면 전체 백색 veil을 제한합니다.
- [x] `No Remjet`, `No Backing`과 제조사 stock 이름은 프리셋에 없고, 실측되지 않은 강한 profile은 Generic 또는 Uncalibrated로 표시됩니다.
- [x] point source, 배경 밝기, 색 광원과 CPU reference 해상도 계약에서 model gate를 통과합니다.

## Answer

Halation CPU reference에 독립적인 Global Diffusion branch를 추가하고, Local Radius와 별도로 조절되도록 typed plan과 Inspector metadata를 확장했습니다. Local·Global은 각각 R/G/B 채널별 Gaussian 반경과 다중 스케일 감쇠를 사용하며, 공개 실측이 없는 값은 generic profile-relative sanity envelope로만 취급합니다. Red Bias와 Blue Compensation에는 profile-relative 의미를 명시한 도움말을 붙였고, 기존 Generic 및 Uncalibrated preset 이름을 유지했습니다.

Halation Only는 Local Only와 Global Only를 같은 scene-linear 합성 경로로 재구성합니다. Global branch는 화면 전체를 덮는 흰 veil이 되지 않도록 약한 에너지 계수, core protection, background adaptation을 함께 적용합니다. 기존 ticket06의 source mask·local diagnostics·HDR/alpha/crop/no-wrap/resolution 계약은 유지했습니다.

Metal v2 parity는 이 티켓의 완료 주장에 포함하지 않으며 ticket08에서 검증합니다.

검증과 생성 artifact는 `.omo/evidence/ticket07-halation-global-20260812/verification.md`에 기록했습니다.
