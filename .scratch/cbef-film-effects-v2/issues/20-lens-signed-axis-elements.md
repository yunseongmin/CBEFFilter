# 20 — Signed-axis 렌즈 반사 Element profile

**What to build:** 각 광원에서 optical center 축을 따라 서로 다른 signed 위치와 형태를 갖는 여러 ghost element를 생성하여, 단일 불투명 복제상이 아닌 generic 렌즈 내부 반사 family로 보이게 합니다.

**Blocked by:** 16 — 광학 수차와 결정적 품질 모드; 18 — 렌즈 반사 광원 지도와 수동 광원.

**Status:** resolved

- [x] 각 generic profile이 element별 signed axis position, magnification, defocus, aperture clipping, ring·falloff, 색 감쇠, dispersion과 energy를 소유합니다.
- [x] source가 이동하면 모든 element centroid가 optical center 축에서 연속적으로 이동하며 보편적인 `k=-1` 대칭으로 강제되지 않습니다.
- [x] aperture disc, ring, veil, streak와 source pattern을 일부 보존하는 focused ghost를 profile에 따라 함께 표현할 수 있습니다.
- [x] focused ghost도 감쇠, defocus, spectral response와 background adaptation을 적용받아 불투명 스티커처럼 붙지 않습니다.
- [x] 밝은 배경에서는 visible impact가 줄고 화면 밖 광원은 정해진 reach 안에서만 기여하며 반대편 edge로 wrap하지 않습니다.
- [x] Ghost Paths, Elements Only와 element solo 진단 출력에서 geometry와 energy를 개별 검증할 수 있습니다.
- [x] 실제 렌즈명, focal length와 T-stop을 가장하지 않는 Clean·Vintage·Anamorphic 계열 generic profile로 표시됩니다.

**Answer:**

The CPU Lens Reflections reference now compiles five render-ready elements for every generic Clean, Vintage, and Anamorphic family. Each element owns a signed optical-axis position, magnification, defocus, aperture/ring/falloff shape, spectral response, dispersion, normalized energy, background response, and one of Focused, Disc, Ring, Veil, or Streak geometry. Focused projection keeps a bounded source-local pattern, while defocused elements reuse the Optical v2 aperture primitive. Diagnostics separately expose axis paths, all elements, and exact element-solo reconstruction. Manual sources just outside the frame use a finite reach; farther sources contribute nothing and never wrap.

**Evidence:** `.omo/evidence/ticket20/ticket20-signed-axis-elements-cpu-20260812.md`
