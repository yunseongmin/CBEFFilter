# 08 — 할레이션 Metal 산란 피라미드

**What to build:** 승인된 할레이션 v2를 Metal 다중 해상도 산란으로 제공하여 Resolve 무료판에서 CPU reference와 같은 재료적 반응을 실용적인 UHD 성능과 메모리로 사용할 수 있게 합니다.

**Blocked by:** 04 — 사전 컴파일 Metal 라이브러리; 05 — 완료 시점 연동 Frame Arena; 07 — 할레이션 광역 산란과 채널 profile.

**Status:** resolved

- [x] Metal 경로가 Local, Global, Source Mask와 Final을 지원하며 CPU reference의 Safety·Model gate를 동일하게 통과합니다.
- [x] 기본·강함·최대값과 모든 작업 공간 입력·진단 출력 표본에서 pixel, halo energy, centroid와 채널 profile parity를 기록합니다.
- [x] identity는 bit-exact이고 crop 밖 byte, alpha, 투명 영역, signed HDR와 가장자리 no-wrap 계약이 유지됩니다.
- [x] wide scatter는 half/quarter/eighth 다중 해상도 packed RG32 자원과 채널별 alpha-normalized numerator/denominator를 사용하며 full-resolution RGBA 복제본을 scale마다 남발하지 않습니다.
- [x] 기준 장비의 기본 프리셋에서 1080p 41.67ms 이하, UHD 83.33ms 이하와 UHD 임시 메모리 160MiB 미만 목표를 측정합니다.
- [x] 성능 목표와 메모리 기준을 약화하지 않고 Gaussian pair 경계 버그를 수정한 뒤 최종 수치와 계측 의미를 증거에 남겼습니다.

## Implementation evidence

- v2 CPU/Metal focused parity, cropped strong pyramid safety, Frame Arena lifetime and ABI/build checks are recorded in [ticket08-evidence.md](../../../.omo/evidence/ticket08/ticket08-evidence.md).
- Direct rerun evidence with exit codes is recorded in [ticket08-verification-20260812.md](../../../.omo/evidence/ticket08/ticket08-verification-20260812.md).
- Optimization evidence, including the red UHD NaN reproduction/fix, wide parity/diagnostic coverage, and scoped validation is recorded in [ticket08-optimization-20260812.md](../../../.omo/evidence/ticket08/ticket08-optimization-20260812.md).
- The final Metal implementation uses reusable half/quarter/eighth packed RG32 planes, per-channel Gaussian profile factors, and one full-resolution composite dispatch per Local/Global branch.
- Final M7 Halation medians are 8.72 ms at 1920×1080 and 50.35 ms at 3840×2160. UHD scratch requested/reserved peak is 149,323,776 B (<160 MiB), with zero arena growth after warm-up.
- The prior external `RenderCore.cpp` build blocker was resolved by the owning ticket; fresh affected build and full Ticket 08 regression are green. See [ticket08-verification-run5-20260812.md](../../../.omo/evidence/ticket08/ticket08-verification-run5-20260812.md).
