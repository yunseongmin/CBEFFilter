# 15 — 화면 위치별 광학 PSF와 Cat-eye

**What to build:** 깊이 지도를 가장하지 않는 uniform defocus를 유지하면서 화면 위치와 방위각에 따라 조리개 PSF와 cat-eye가 연속적으로 달라지는 광학 블러를 제공합니다.

**Blocked by:** 01 — 품질 기준 영상과 근거 기록; 02 — 효과별 설정 컴파일 구조 확장; 03 — v2 Inspector 메타데이터와 조작 흐름.

**Status:** resolved

- [x] Blades, roundness, rotation, anamorphism, defocus와 highlight response를 유지하면서 Center·Rim Bias와 cat-eye를 조절할 수 있습니다.
- [x] center에서 corner로 point source를 옮기면 PSF axis ratio와 clipping이 tile seam 없이 연속적으로 변합니다.
- [x] 각 화면 위치와 channel의 PSF는 정규화되고 highlight gain 0의 constant field를 정한 내부 허용치 안에서 보존합니다.
- [x] Final, PSF Preview와 Highlight Source Map이 field별 결과와 source 선택을 독립적으로 보여 줍니다.
- [x] aperture geometry는 analytic target과 내부 IoU 기준으로, field PSF는 centroid·energy·second moment·axis ratio로 검증합니다.
- [x] UI와 도움말은 depth, focus distance, near/far occlusion 또는 실제 Depth of Field를 제공한다고 주장하지 않습니다.

Evidence: `.omo/evidence/ticket15-20260812/ticket15-field-psf-cpu.md`
