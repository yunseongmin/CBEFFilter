# 03 — M2: 자연스러운 CBEF Halation vertical slice

**What to build:** 사용자가 밝은 경계에 얇고 따뜻한 번짐을 만들고 Amount·Radius·Threshold·색 반응과 진단 보기를 조절할 수 있게 합니다.

**Blocked by:** 02 — M1: Headless Render Contract와 공통 색·알파 Module

**Status:** resolved

- [x] Halation의 모든 파라미터, 세 preset, 기본값, Custom·Reset 동작이 Effect Definition과 정확히 일치합니다.
- [x] threshold와 0.75-stop knee, Highlights Only, 세 sigma 확산, core subtraction, Warmth·Saturation과 Amount 수식이 canonical linear DWG에서 동작합니다.
- [x] Amount 0과 Mix 0 Final은 exact identity이며 Halation Component와 Highlight Matte는 명세 단계의 값을 표시하고 Mix를 무시합니다.
- [x] threshold 아래 matte, halo 비음수성, 바깥 profile 단조성, R ≥ G ≥ B, highlight core 2% 조건을 모두 통과합니다.
- [x] frame edge, straight·premultiplied alpha, 음수 residual과 HDR fixture에서 seam·hidden RGB leak·임의 clipping이 없습니다.
- [x] 1080p/4K 비교가 PSNR, 반경과 저주파 energy 조건을 통과합니다.
- [x] CPU와 Metal 결과가 2e-4 이내이며 Halation focused suite와 affected build가 성공합니다.

## Completion evidence

Artifact: `m2-halation-2026-08-12`

- `make build` — exit 0.
- `make test-m1` — exit 0, `PASS (CPU + Metal M1 contract)`.
- `make test-m2` — exit 0, `PASS (CPU + Metal M2 Halation)`.
- QA record: `docs/qa/m2-halation.md`.
