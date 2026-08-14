# 11 — 미스트 Metal 품질과 UHD 성능

**What to build:** 승인된 Generic Black·White 미스트를 Metal에서 CPU reference와 같은 Glow·Veil·Detail 반응으로 렌더하여 Resolve 무료판에서 실용적으로 사용할 수 있게 합니다.

**Blocked by:** 05 — 완료 시점 연동 Frame Arena; 08 — 할레이션 Metal 산란 피라미드; 10 — 미스트 Detail 보존과 Grade profile.

**Status:** resolved

- [x] Metal 경로가 Generic Black·White, 모든 Grade, Glow·Veil·Detail 제어와 진단 출력을 지원합니다.
- [x] 기본·강함·최대값에서 CPU와 Metal의 pixel 차이뿐 아니라 glow energy·radius, veil, MTF와 색 이동 parity를 기록합니다.
- [x] identity, alpha bit 보존, 투명 영역, crop 밖 sentinel, signed HDR, edge no-wrap와 해상도 계약을 통과합니다.
- [x] broad diffusion은 공유 산란 자원과 다중 해상도 처리를 사용하고 불필요한 full-frame 복제와 프레임별 할당을 피합니다.
- [x] 기준 장비의 기본 프리셋에서 1080p 41.67ms 이하, UHD 83.33ms 이하와 UHD 임시 메모리 220MiB 미만 목표를 측정합니다.
- [x] 빠른 경로는 pixel parity와 같은 Mist Model Gate를 함께 통과해야 하며 성능을 위해 detail 또는 profile 차이를 숨기지 않습니다.

## Answer

Metal Mist v2는 CPU reference가 컴파일한 Generic Black·White profile과 Grade coefficients를 그대로 받아 Glow·Veil·Detail을 독립적으로 산출합니다. Final, Component, Matte, Glow Only, Veil Only, Detail Difference 진단을 포함하며, 2e-4 pixel parity와 alpha/crop/padding/signed-HDR/no-wrap 계약을 `test-v2-mist-metal`에서 검증했습니다.

전체 프레임 UHD에서는 3x shared scatter pyramid를 사용하고 FrameArena가 7개 level resource의 lifetime과 재사용을 관리합니다. 정리 후 clean 단독 benchmark에서 Apple M3 Pro 기준 1920×1080 median 6.1326 ms, 3840×2160 median 13.7307 ms를 기록했고, UHD scratch requested/reserved는 103,219,200 B, warmup 이후 arena growth는 0 B였습니다. 효과 필터형 `benchmark-mist`와 기본 `benchmark-m7`의 전체 경로를 분리해 유지했습니다.

정리 후 비활성 fused 경로와 전용 `MistFusedArguments`/dual kernels를 제거하고 `test-v2-mist-metal`, `test-m4`는 다시 통과했습니다. 공유 Grain CPU 통계 작업 종료 후 clean `benchmark-mist`를 단독 실행하여 게이트를 재확인했습니다. 1920×1080 median 6.1326 ms, UHD median 13.7307 ms, UHD scratch requested/reserved 103,219,200 B, warmup 이후 arena growth 0 B로 모든 게이트가 통과했습니다. 초기 contention 실행(171 ms UHD)은 실패 증거로 보존하되 최종 판정에는 사용하지 않습니다. 기록: [`ticket11-cleanup-validation.log`](../../../.omo/evidence/ticket11-mist-metal-final/ticket11-cleanup-validation.log), [`cleanup-benchmark-clean/m7-performance.json`](../../../.omo/evidence/ticket11-mist-metal-final/cleanup-benchmark-clean/m7-performance.json).

계수는 내부 placeholder이고 상용 필터의 실측 또는 stock 동등성을 주장하지 않습니다.

## Implementation evidence

- [`summary.txt`](../../../.omo/evidence/ticket11-mist-metal-final/summary.txt)
- [`m7-performance.json`](../../../.omo/evidence/ticket11-mist-metal-final/m7-performance.json)
- [`m7-performance.md`](../../../.omo/evidence/ticket11-mist-metal-final/m7-performance.md)
- [`ticket11-focused-final.log`](../../../.omo/evidence/ticket11-focused-final.log)
- [`ticket11-build-final.log`](../../../.omo/evidence/ticket11-build-final.log)
