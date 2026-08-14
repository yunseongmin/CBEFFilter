# 17 — 광학 블러 Metal PSF 샘플링

**What to build:** 화면 위치별 PSF와 수차를 Metal에서 CPU reference와 같은 결정적 sampling policy로 재현하여, 고급 광학 블러를 Resolve 무료판에서 실용적인 속도로 제공합니다.

**Blocked by:** 04 — 사전 컴파일 Metal 라이브러리; 05 — 완료 시점 연동 Frame Arena; 16 — 광학 수차와 결정적 품질 모드.

**Status:** resolved

- [x] Metal 경로가 모든 품질 모드, field profile, 수차 제어와 진단 출력을 지원합니다.
- [x] 같은 quality에서 CPU와 Metal이 호환되는 sample sequence를 사용하고 pixel, PSF centroid·energy·second moment parity를 통과합니다.
- [x] center·rim·corner, 작은·큰 반경, 1080p·UHD·8K와 Render Scale 표본에서 seam과 방향 불연속이 없습니다.
- [x] identity, alpha bit 보존, crop 밖 byte, signed HDR, 투명 영역과 가장자리 no-wrap 계약을 통과합니다.
- [x] 기준 장비 기본 프리셋에서 1080p 41.67ms 이하, UHD 83.33ms 이하와 UHD 임시 메모리 192MiB 미만 목표를 측정합니다.
- [x] 성능 근사는 같은 Optical Blur Model Gate를 유지하고 광학 수차나 field dependence를 조용히 끄지 않습니다.

## Answer

Optical Blur now compiles a deterministic 24/64/128-sample policy shared by CPU and Metal. The Metal path preserves the complete field-dependent model and diagnostics, uses a continuous full/half transition over 4–8 px plus packed quarter/eighth levels, and keeps the UHD scratch set below 192 MiB. The zero-chromatic-aberration fast path removes redundant RGB fetches only when all three channels use the same coordinates; non-zero dispersion continues through the full per-channel model. Pixel parity measured max `2.38e-6` and mean `7e-8`. On Apple M3 Pro, median performance measured 12.10 ms at 1080p and 48.58 ms at UHD, with 176,259,072 B UHD scratch and zero post-warmup arena growth.

Evidence: `.omo/evidence/ticket17-20260812/ticket17-optical-metal.md`
