# 21 — 렌즈 반사 Metal Element 투영

**What to build:** 여러 광원과 signed-axis element profile을 Metal에서 CPU reference와 같은 위치·에너지·형태로 투영하여, 복잡한 야간 장면에서도 실용적인 렌즈 반사를 제공합니다.

**Blocked by:** 04 — 사전 컴파일 Metal 라이브러리; 05 — 완료 시점 연동 Frame Arena; 17 — 광학 블러 Metal PSF 샘플링; 19 — 렌즈 반사 외부 Matte 입력; 20 — Signed-axis 렌즈 반사 Element profile.

**Status:** resolved

- [x] Metal 경로가 자동·수동 광원, 외부 matte, 모든 generic profile, element 형태와 진단 출력을 지원합니다.
- [x] CPU와 Metal의 source centroid·energy, element signed 위치, magnification, PSF energy와 background adaptation parity를 기록합니다.
- [x] multi-source, signage, clipped white, saturated LED, focused pattern, frame-edge와 off-screen fixture에서 위치 연속성과 no-wrap을 통과합니다.
- [x] identity, alpha bit 보존, 투명 영역, crop 밖 byte, signed HDR, random seek와 same-queue completion 계약을 통과합니다.
- [x] element 수만큼 full-resolution RGBA 복제본을 만들지 않고 공유 source·PSF 자원과 Frame Arena를 사용합니다.
- [x] 기준 장비 기본 프리셋에서 1080p 41.67ms 이하, UHD 83.33ms 이하와 UHD 임시 메모리 256MiB 미만 목표를 측정합니다.

**Answer:**

Lens Reflections v2 now runs as one non-blocking Metal submission backed by the precompiled metallib and completion-bound Frame Arena. The GPU prepares pre/post external-matte source weights, builds a shared half-resolution focused-source plane, computes 8×8 source statistics, and performs a deterministic two-stage top-8 reduction that preserves the original tile index as the energy tie-breaker. One destination-gather projection evaluates the five compiled signed-axis elements without allocating an element-by-full-frame RGBA plane. Clean, Vintage, and Anamorphic families, Focused/Disc/Ring/Veil/Streak geometry, Auto/Manual source modes, Alpha/RGBA matte, Source Map before/after, Ghost Paths, Elements Only, element solo, and every Working Mode share this path.

The public Metal seam enforces max pixel error `<=2e-4`, mean error `<=2e-5`, centroid delta `<=0.1px`, energy delta `<=0.5%`, exact alpha/crop/identity behavior, deterministic random/reverse seek, odd origins/scales, signed HDR, premultiplied alpha, off-screen sources, and shallow-wide plus tall-narrow 8K/12K guards. Large normal-aspect Final frames use the bounded half-source/projection path while preserving the full-resolution original and upsampling only the reflection contribution; extreme aspect ratios stay on the exact path. On the Apple M3 Pro gate, 1080p median was `5.05ms`, UHD median was `13.57ms`, UHD scratch was `141,279,232 B`, and post-warmup arena growth was `0 B`.

**Evidence:** `.omo/evidence/ticket21/ticket21-lens-metal-final-20260812.md`
