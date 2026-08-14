# 05 — M4: Black·White CBEF Mist Diffusion vertical slice

**What to build:** 사용자가 Black·White mode와 네 Density를 선택하고, 하이라이트 확산·대비·질감 보존을 자연스럽게 조절할 수 있게 합니다.

**Blocked by:** 03 — M2: 자연스러운 CBEF Halation vertical slice

**Status:** resolved

- [x] Mist의 모든 파라미터, 여덟 preset, 기본값, Custom·Reset과 Output View가 Effect Definition과 일치합니다.
- [x] Density radius/energy factor, White radius factor, 두 diffusion sigma와 Bloom sigma/energy가 명세대로 적용됩니다.
- [x] Q=P+diffusion contribution+bloom contribution, Mode별 contrast slope, Texture 합성과 signed residual 복원이 정의된 순서로 동작합니다.
- [x] Mix 0 또는 Diffusion·Bloom·Contrast 0 Final은 exact identity이며 Diffusion Component와 Highlight Matte가 정확한 pre-Mix 값을 표시합니다.
- [x] Density energy 단조성, White/Black half-maximum 반경, shadow-lift 비율, Black·White 기본 MTF와 Texture 단조 조건을 통과합니다.
- [x] 1080p/4K PSNR·반경·energy, frame edge, alpha와 HDR focused fixture를 통과합니다.
- [x] CPU·Metal parity와 affected build가 성공하며 Resolve 시각 튜닝은 M7에 남깁니다.
