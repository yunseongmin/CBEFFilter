# 14 — 필름 그레인 Metal 통계 일치

**What to build:** 승인된 Stock Response와 입자 집단을 Metal에서 결정적으로 재현하여, 프레임 탐색·해상도·재생 순서와 무관하게 CPU reference와 같은 필름 질감을 빠르게 제공합니다.

**Blocked by:** 04 — 사전 컴파일 Metal 라이브러리; 05 — 완료 시점 연동 Frame Arena; 13 — 필름 그레인 Color Record와 입자 집단.

**Status:** resolved

- [x] 동일 seed·frame·quality에서 CPU와 Metal의 same-frame field와 ensemble statistics를 각각 비교해 기록합니다.
- [x] random seek, reverse seek와 인접 프레임에서 결과가 순서 독립적이며 프레임별 입자 구조는 자연스럽게 바뀝니다.
- [x] 모든 Stock Response·Capture Format 표본과 1080p·UHD·8K에서 RMS, PSD, covariance, 입자 크기와 mean bias parity를 통과합니다.
- [x] identity는 bit-exact이고 alpha, 투명 영역, crop 밖 byte, padded stride, signed HDR와 edge 계약이 유지됩니다.
- [x] 기준 장비에서 기본 프리셋의 1080p·UHD median 41.67ms 이하와 UHD 임시 메모리 64MiB 미만 목표를 측정합니다.
- [x] 통계 gate를 줄이거나 frame 수를 축소해 성능 또는 parity를 통과시키지 않습니다.

## Answer

큰 프레임의 Metal 경로는 세 octave의 Philox latent field를 packed `float4` 아틀라스로 한 번 생성하고, 분리 Gaussian과 fractional sampling을 거쳐 최종 RGB record covariance를 합성합니다. 타일마다 GPU 제출·대기하던 경로는 제거했고, 한 command buffer 안에서 최대 크기의 9개 scratch buffer를 모든 타일이 순차 재사용합니다.

오른쪽 파란 채널에서 발생하던 최대 오차는 Stock 2의 record diameter `0.94`가 host가 `1.0` 기준으로 만든 아틀라스 범위보다 넓게 샘플링한 것이 원인이었습니다. 세 record diameter를 모두 포함해 아틀라스 범위를 계산하도록 고쳐 640×360 최대 오차를 `0.0483526`에서 `1.94907188e-05` 이하로 낮췄습니다. 기본 Clumping 22와 강한 Clumping 65/Chroma 70/Exposure Bias +1.5 경로, 3 Stock × 5 Capture Format, random/reverse seek를 영구 회귀로 유지합니다.

Ticket 13의 비대칭 밀도 항은 기존 48-frame M3 평균 바이어스를 `0.00090424` stop까지 올렸습니다. 비대칭을 제거하지 않고 bounded profile을 `0.015 + 0.040*clump`로 제한해 기존 M3 평균 계약(`0.000456467` stop)과 강한 v2 parity를 함께 통과시켰습니다.

## Implementation evidence

- [`ticket14-grain-metal-statistics.md`](../../../.omo/evidence/ticket14-grain-metal-final-20260812/ticket14-grain-metal-statistics.md) and [`ticket14-grain-metal-statistics.json`](../../../.omo/evidence/ticket14-grain-metal-final-20260812/ticket14-grain-metal-statistics.json): 48 frames, same-frame max `1.94907e-05`, CPU/Metal mean-RMS delta `1.79647e-08`, `measured_profile_gate=false`.
- [`m7-performance.md`](../../../.omo/evidence/ticket14-grain-metal-final-20260812/m7-grain/m7-performance.md) and [`m7-performance.json`](../../../.omo/evidence/ticket14-grain-metal-final-20260812/m7-grain/m7-performance.json): Apple M3 Pro, 1080p median `9.10 ms` with `30,572,544 B` scratch, UHD median `13.86 ms` with `7,962,624 B` scratch, zero post-warmup growth; both PASS under `41.67 ms` and `64 MiB`.
- `make test-v2-grain-stock-cpu` — Ticket 12/13 48-frame statistical contract PASS.
- `make test-v2-grain-metal` — default/strong packed-atlas parity, 3×5 Stock/Capture grid, 1080p/UHD/8K-height, seek order, and 48-frame CPU/Metal suite PASS.
- `make build test-m3 test-frame-arena test` — bundle build, legacy Grain contract, FrameArena lifetime contract, and five-effect OpenFX ABI/metallib load PASS.
