# 04 — M3: 결정적 CBEF Film Grain vertical slice

**What to build:** 사용자가 재생·scrub·재렌더에서도 같은 프레임에는 같은 입자, 다음 프레임에는 새로운 입자를 얻고 포맷·크기·색·명암 반응을 조절할 수 있게 합니다.

**Blocked by:** 02 — M1: Headless Render Contract와 공통 색·알파 Module

**Status:** resolved

- [x] Grain의 모든 파라미터, 네 format/preset, 기본값, Custom·Reset과 세 Output View가 명세와 일치합니다.
- [x] half-away-from-zero frame rounding, signed frame encoding, Philox round, counter/key packing, domain ID와 12-uniform 소비 순서가 CPU·Metal에서 동일합니다.
- [x] canonical 좌표, format-relative diameter, 세 octave, C1 interpolation, Softness Gaussian과 coefficient RMS normalization이 정확히 적용됩니다.
- [x] Shadow·Midtone·Highlight response, Format Strength, sigma_stop, energy-preserving Chroma 혼합과 log-exposure 합성이 명세 수식을 만족합니다.
- [x] Amount 0과 Mix 0은 exact identity이고 Grain Component와 Luminance Response가 정의된 처리 단계의 값을 표시합니다.
- [x] 이 티켓에서만 Grain heavy statistical suite를 실행해 재실행 bit identity, subframe 일치, 이웃 프레임 상관, 48-frame bias, RMS와 channel correlation 조건을 통과합니다.
- [x] 1080p/4K particle diameter, radial spectrum, 방향성, non-DC spike 조건을 통과합니다.
- [x] CPU·Metal parity와 affected build가 성공하며 성능 gate는 M7에 남깁니다.
