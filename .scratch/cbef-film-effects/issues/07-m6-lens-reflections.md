# 07 — M6: 장면 반응형 CBEF Lens Reflections vertical slice

**What to build:** 사용자가 현재 프레임의 실제 광원 형태와 색으로 광축상 ghost를 만들고 Lens Model·Spread·Blur·Chroma·Anamorphism을 조절할 수 있게 합니다.

**Blocked by:** 03 — M2: 자연스러운 CBEF Halation vertical slice; 06 — M5: 조리개형 CBEF Optical Blur vertical slice

**Status:** resolved

- [x] Lens Reflections의 모든 파라미터, 세 preset, 기본값, Custom·Reset과 Output View가 Effect Definition과 일치합니다.
- [x] threshold와 1-stop knee로 source highlight를 만들고 frame center 기준 affine 위치식으로 모든 source 광원을 처리합니다.
- [x] forward mapping은 화면 안 energy를 보존하고 화면 밖 energy를 버리며 반대 edge로 wrap하지 않습니다.
- [x] 명세의 anisotropic Gaussian, tint, model energy, Chroma와 Amount를 정확한 순서와 횟수로 적용합니다.
- [x] Amount 0과 Mix 0 Final은 exact identity이고 Reflection Component와 Source Matte가 정의된 pre-Mix 값을 표시합니다.
- [x] threshold, ghost centroid, model energy ratio, Amount 단조성, threshold popping과 off-screen wrap focused 조건을 통과합니다.
- [x] 1080p/4K·alpha·HDR fixture, CPU·Metal parity와 affected build가 성공하며 고정 flare bitmap이나 connected-component tracking을 추가하지 않습니다.

## Answer

Metal Lens Reflections now executes scene-reactive source matte, affine ghost mapping, anisotropic blur, tint/model-energy/Chroma/Amount composition and diagnostics on the supplied host command queue. The focused CPU + actual Metal contract passes with `make -B test-m6`; evidence is recorded at `.omo/evidence/m6-lens-reflections-20260812/focused-validation.log`. No fixed flare bitmap or connected-component tracking was introduced.
