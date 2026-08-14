# 06 — 장면 반응형 할레이션 광원과 국소 산란

**What to build:** 할레이션이 밝은 중심을 하얗게 부풀리는 블룸이 아니라, 장면의 광원·색·주변 밝기에 반응하며 밝은 경계 바깥에 좁게 형성되는 따뜻한 국소 산란으로 보이게 합니다.

**Blocked by:** 01 — 품질 기준 영상과 근거 기록; 02 — 효과별 설정 컴파일 구조 확장; 03 — v2 Inspector 메타데이터와 조작 흐름.

**Status:** resolved

- [x] Basic·Advanced 제어로 광원 제한, 광원 부드러움, 국소 반경, 강도와 core protection을 조절할 수 있습니다.
- [x] 중성, tungsten, 청색 LED, 포화 적색 광원에서 광원 mask가 연속적으로 반응하며 threshold 부근에서 갑자기 켜지지 않습니다.
- [x] 국소 산란은 밝은 중심보다 주로 경계 바깥에서 나타나고 hard red outline이나 white bloom으로 붕괴하지 않습니다.
- [x] 같은 광원에서 밝은 배경의 visible impact가 어두운 배경보다 낮고, 중성 highlight 중심의 색과 에너지가 보호됩니다.
- [x] Source Mask와 Local Only 진단 출력이 Final 합성과 무관하게 광원 선택과 국소 성분을 보여 줍니다.
- [x] HDR·signed RGB, straight·premultiplied alpha, 투명 픽셀, non-zero origin, crop, 가장자리와 해상도 계약을 CPU reference 렌더에서 통과합니다.

## Answer

Halation은 `Generic Subtle`, `Generic Warm`, `Strong Halo (Uncalibrated)` 세 preset과 `Source Limit`, `Source Smoothness`, `Local Radius`, `Strength`, `Core Protection`, `Background Adaptation`을 갖는 CPU reference로 교체했습니다. source isolation은 scene-linear positive RGB의 luminance와 Max RGB 보조 metric을 사용해 neutral·tungsten·blue LED·saturated red source를 부드러운 knee로 선택합니다. Local Halo는 source core를 보호하고, 현재 픽셀의 배경 밝기로 visible contribution을 낮춥니다.

`Source Mask`, `Local Only`, `Halation Only`은 Final Mix와 독립적으로 CPU reference 결과를 보여 줍니다. Global branch는 아직 0이며, global/spectral model과 Metal parity는 다음 차단 티켓 07·08의 범위입니다. 이 티켓은 Metal v2 parity를 주장하지 않습니다.

검증과 생성 artifact는 `.omo/evidence/ticket06-halation-local-20260812/verification.md`에 기록했습니다.
