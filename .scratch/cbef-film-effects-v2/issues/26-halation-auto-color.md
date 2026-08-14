# 26 — 할레이션 장면 반응형 자동 색상

**What to build:** Halation의 기존 수동 `Color Emphasis` 결과와 기본값을 그대로 유지하면서, 공간적으로 평활된 halo 색에 연속적으로 반응하는 `Auto (Scene Adaptive)` 선택지를 추가합니다.

**Blocked by:** 08 — 할레이션 Metal 산란 피라미드.

**Status:** resolved

- [x] `Color Emphasis`의 기존 네 ordinal과 기본값을 유지하고 ordinal 4에 `Auto (Scene Adaptive)`를 추가합니다.
- [x] Auto는 같은 프레임의 평활된 raw halo 색만 분석하며 중성·저채도는 Film Red, warm/orange는 Warm Amber, 강한 cool/blue·green은 Neutral White 방향으로 연속적으로 반응합니다.
- [x] Auto target은 scene-linear halo luminance를 보존하고 `Color Strength`가 Profile Relative와 auto target 사이를 제어합니다.
- [x] CPU와 Metal은 명시적인 typed mode와 같은 bounded float 수식을 사용하며 별도 pass, readback, histogram, frame state를 추가하지 않습니다.
- [x] 기존 수동 모드, 기본값, Source Mask, signed HDR, alpha, crop/no-wrap, 피라미드 성능 계약을 보존합니다.
- [x] 공개 `render(...)` seam의 CPU·Metal·metadata·compile 계약과 affected build가 모두 통과합니다.

## Answer

`Color Emphasis` ordinal 4에 `Auto (Scene Adaptive)`를 추가하고 `HalationColorMode` typed plan을 Metal ABI까지 명시적으로 전달했습니다. Auto는 추가 pass 없이 이미 평활된 local/global raw halo RGB를 픽셀별로 분석합니다. bounded smoothstep 가중치로 Film Red·Warm Amber·artistic Neutral White target을 연속 혼합하고, 기존 scene-linear Halation luminance로 정규화한 뒤 `Color Strength`만큼 Profile Relative에서 보간합니다.

기존 Profile Relative와 세 수동 mode의 대표 CPU 결과는 hex float golden으로 고정해 bit-equivalent임을 확인했습니다. Auto는 neutral, tungsten, saturated blue, saturated green에서 의도한 순서를 보이며 작은 hue/chroma 변화에 branch popping이 없습니다. Source Mask는 Auto와 bit-identical이고, signed negative residual, unclamped HDR, straight/premultiplied alpha, zero-alpha hidden RGB, crop/no-wrap 계약을 보존합니다.

CPU/Metal Auto 대표 fixture의 최대 오차는 `1.78814e-07`, signed premultiplied fixture는 `2.98023e-08`로 `2e-4` gate를 통과했습니다. 최종 affected CPU·Metal·M2·typed compile·Inspector·bundle·OpenFX ABI 검증은 모두 PASS이며 세부 명령과 수치는 `docs/evidence/feature-fixes/halation-auto-color.md`에 기록했습니다.

최종 `make verify-v2`도 다섯 효과 전체와 성능·메모리 게이트까지 PASS했습니다. 설치된 번들을 Resolve 21 Free의 공식 `Wetsuit.braw`에 적용해 Auto의 warm red/amber 합성과 `Halation Only` 진단을 직접 확인했고, 반복 재생 중 CBEF 오류나 source fallback은 없었습니다. 관찰 결과는 `docs/evidence/host-acceptance/visual-qa-20260812.md`에 남겼고 대용량 화면 첨부는 최종 승인 뒤 제거했습니다.
