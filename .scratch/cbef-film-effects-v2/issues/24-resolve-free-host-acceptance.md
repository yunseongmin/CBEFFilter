# 24 — Resolve 무료판 Host Acceptance

**What to build:** 실제 DaVinci Resolve 무료판에 v2 번들을 설치해 다섯 효과의 검색, Inspector, Edit·Color 적용, 재생, 저장·재열기와 최종 Deliver가 일반 설치형 효과처럼 작동함을 증명합니다.

**Blocked by:** 23 — v2 자동 통합 Gate.

**Status:** ready-for-agent

- [ ] v1 번들을 별도로 백업한 뒤 v2를 설치하고 Resolve 재시작 후 다섯 효과가 기존 이름으로 검색되며 Studio badge, watermark, DCTL 요구가 없습니다.
- [ ] 각 효과를 Edit 클립과 Color 노드에 적용하고 Basic·Advanced·Diagnostics, preset·reset·Custom과 조건부 제어를 확인합니다.
- [ ] Lens Reflections의 외부 matte 연결·해제와 다섯 효과의 작업 공간 입력·출력 보기·Mix가 Inspector와 렌더에서 일치합니다.
- [ ] 프로젝트 저장·종료·재열기, cache clear, random·reverse seek, scrub와 각 효과 세 번의 정상 재생에서 crash·stale frame·flicker가 없습니다.
- [ ] 기본·강함·극단값의 preview와 Deliver가 완료되고 float 또는 half 기준 frame, screenshot, Resolve 버전, 프로젝트 설정과 bundle hash를 증거에 기록합니다.
- [ ] 자동 gate 결과와 실제 host 결과가 다르면 host 결과를 우선 결함으로 기록하고 ABI probe만으로 호환성을 주장하지 않습니다.
