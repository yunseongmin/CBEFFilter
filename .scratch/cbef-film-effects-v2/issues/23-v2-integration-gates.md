# 23 — v2 자동 통합 Gate

**What to build:** 최종 번들 하나를 대상으로 다섯 효과의 Safety, Model, Parity, 성능·메모리와 자산 권리 gate를 한 번에 재현하여, Resolve 실기 전에 객관적 결함을 차단합니다.

**Blocked by:** 22 — v1 내부 구조 제거와 v2 계약 확정.

**Status:** resolved

- [x] clean arm64 package build와 ABI probe가 다섯 stable ID, float RGBA 지원과 사전 컴파일 Metal 자산을 확인합니다.
- [x] 최상위 렌더 계약에서 모든 작업 공간 입력, profile·preset, quality, diagnostic view와 숫자 parameter의 min·default·strong·max 표본을 실행합니다.
- [x] 각 효과의 Safety·Model gate와 CPU·Metal parity를 통과하고 identity는 tolerance가 아닌 bit-exact로 확인합니다.
- [x] Grain 48-frame 통계, 효과별 해상도·Render Scale, 8K·12K 정확성, invalid input와 backend failure 계약을 실행합니다.
- [x] 기준 장비에서 3-frame warm-up 뒤 10-frame median, scratch peak와 10 warm frame 이후 steady allocation을 기록합니다.
- [x] 기준 영상 manifest와 외부 자산 기록이 완전하고 권리가 불명확한 원본이 번들·저장소·공개 증거에 포함되지 않았음을 확인합니다.
- [x] 실패한 목표는 effect·설정·해상도·측정값과 함께 보고하며 threshold, frame 수 또는 품질을 낮춰 통과시키지 않습니다.

**Answer:**

`make verify-v2`가 clean SDK bootstrap과 arm64 package build를 한 번 수행한 뒤 fixture/provenance, v2 ABI·bundle·metallib 함수, 금지 심볼, 공통 오류·색·alpha 계약, 다섯 효과의 CPU·Metal focused suite, 48-frame Grain 통계, Frame Arena, 모든 효과의 8K/12K shallow-wide/tall 정확성과 bit-exact identity를 fail-fast로 실행합니다. 마지막으로 각 효과를 1080p/UHD에서 3회 warm-up 후 10회 측정하고 effect별 scratch 한계와 post-warmup growth를 판정합니다. 최종 실행은 10개 성능 case를 포함해 전부 통과했으며, 증거 폴더에 원본 로그, JSON, fixture checksum, 전체 checksum과 verdict를 남겼습니다.

**Evidence:** `docs/evidence/v2-final-20260812/`
