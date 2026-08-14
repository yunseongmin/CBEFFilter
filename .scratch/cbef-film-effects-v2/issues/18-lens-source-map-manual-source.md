# 18 — 렌즈 반사 광원 지도와 수동 광원

**What to build:** 장면의 여러 실제 광원을 위치·크기·색·에너지로 분석하고, 자동 검출이 실패할 때 사용자가 수동 광원으로 확실히 교정할 수 있는 렌즈 반사 source 흐름을 제공합니다.

**Blocked by:** 01 — 품질 기준 영상과 근거 기록; 02 — 효과별 설정 컴파일 구조 확장; 03 — v2 Inspector 메타데이터와 조작 흐름; 06 — 장면 반응형 할레이션 광원과 국소 산란.

**Status:** resolved

- [x] 간판, clipped white, 포화 R/G/B LED, fine LED array, 창문과 specular fixture에서 여러 광원을 독립 source로 검출합니다.
- [x] 자동 광원 검출은 threshold sweep에서 centroid와 energy가 연속적이며 precision·recall·centroid·energy 오차를 기록합니다.
- [x] Manual Source를 켜면 지정한 위치·크기·색·강도가 자동 검출을 명확히 대체하고 frame edge와 화면 밖 reach를 예측 가능하게 처리합니다.
- [x] Source Map 진단 출력이 선택된 자동·수동 광원과 각 에너지를 Final과 분리해 보여 줍니다.
- [x] 같은 프레임은 random seek와 렌더 순서에 관계없이 같은 source map을 만들며 과거 프레임 상태에 의존하지 않습니다.
- [x] HDR·signed RGB, alpha, 투명 영역, crop, non-zero origin, off-screen source와 no-wrap 계약을 CPU reference에서 통과합니다.

**Answer:**

CPU reference now builds a frame-local source map from scene-linear positive RGB using selectable metric, softened threshold, gamma, bounded morphology, 8x8 energy tiles, and deterministic top-8 spatial maxima. Manual Source replaces that map with an analytic normalized ellipse, supports off-screen coordinates, intensity and color modes, and shares the same crop-safe compositing path. Source Map is a diagnostic view independent of Mix; background adaptation, veil, optical center, and element-solo controls are compiled and wired for the later signed-axis/Metal tickets.

**Evidence:** `.omo/evidence/ticket18/ticket18-cpu-source-map-20260812.md`
