# 06 — M5: 조리개형 CBEF Optical Blur vertical slice

**What to build:** 사용자가 일반 Gaussian이 아닌 조리개 날·곡률·회전·Anamorphism을 가진 전체 프레임 광학 블러를 적용할 수 있게 합니다.

**Blocked by:** 02 — M1: Headless Render Contract와 공통 색·알파 Module

**Status:** resolved

- [x] Optical Blur의 모든 파라미터, 세 preset, 기본값, Custom·Reset과 Output View가 Effect Definition과 일치합니다.
- [x] regular polygon과 circle 보간, Rotation, horizontal/vertical radius와 최소 4×4 subpixel coverage로 unit-sum aperture kernel을 생성합니다.
- [x] base aperture blur와 pivot 0.72·1-stop knee의 Highlight Response가 명세 순서로 합성됩니다.
- [x] Blur 0과 Mix 0 Final은 exact identity이고 Blurred Image와 Highlight Component가 각각 정의된 처리 단계의 값을 표시합니다.
- [x] kernel sum·centroid·constant image·second-moment anamorphism·analytic mask IoU·Highlight Response 단조 조건을 통과합니다.
- [x] frame edge와 1080p/4K PSNR·반경·energy, alpha와 HDR focused fixture를 통과합니다.
- [x] CPU·Metal parity와 affected build가 성공하며 depth map이나 AI 처리를 추가하지 않습니다.

## Completion evidence

Artifact: `m5-optical-blur-20260812`

- `make -B test-m5` — exit 0, `PASS (CPU + Metal M5 Optical Blur)`.
- QA record: `docs/qa/m5-optical-blur.md`.
