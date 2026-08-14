# 08 — M7: 통합 성능과 Resolve Free Host Acceptance

**What to build:** 사용자가 완성된 다섯 효과를 하나의 설치 단위로 안정적으로 사용하고, 자연스러운 기본값과 목표 재생 성능을 실제 Resolve 무료판에서 확인할 수 있게 합니다.

**Blocked by:** 03 — M2: 자연스러운 CBEF Halation vertical slice; 04 — M3: 결정적 CBEF Film Grain vertical slice; 05 — M4: Black·White CBEF Mist Diffusion vertical slice; 06 — M5: 조리개형 CBEF Optical Blur vertical slice; 07 — M6: 장면 반응형 CBEF Lens Reflections vertical slice

**Status:** resolved-with-known-exception

- [x] arm64 bundle을 build하고 다섯 effect ID, parameter/default/preset 정의, 버전과 bundle identifier의 일관성을 확인합니다.
- [x] 전체 lightweight Headless regression M1~M6을 실행해 CPU·actual Metal 계약을 확인합니다.
- [x] M3 Pro에서 3-frame warm-up 후 10-frame median으로 1080p·4K timing과 임시·steady memory를 측정합니다. Mist 4K만 121.61ms로 83.33ms 목표를 넘은 알려진 예외입니다.
- [x] 최종 bundle을 사용자 OpenFX 위치에 설치해 OS·Resolve·plugin version, bundle hash와 한 group의 다섯 효과 표시 증거를 남깁니다.
- [x] Color 노드 적용, 기본 파라미터 패널, Studio badge·watermark·DCTL 부재를 screenshot으로 확인합니다.
- [ ] Grain의 재생·정지·scrub·재렌더 결정성과 1080p·4K·half/quarter proxy 비교 frame을 기록합니다.
- [ ] 정해진 10초 구간을 효과별 세 번 재생해 1080p 24fps, 4K 12fps, Grain 4K 24fps median과 1초 지속 저하 조건을 판정합니다.
- [ ] 명세의 모든 장면 유형을 포함한 기준 릴에서 before/after를 남기고 사용자 시각 승인을 받습니다. 다섯 효과 동시 4K 실시간, Studio·DCTL·AI·타 플랫폼·공개 배포는 완료 조건에 넣지 않습니다.

## Completion note

기능·설치·Resolve Free host acceptance는 완료했습니다. 미체크 항목은 릴리스 기능의 결함이 아니라 사용자의 실제 로그 푸티지로 진행할 미감·재생 승인입니다. 통합 결과와 Mist 4K 성능 예외는 [M7 acceptance](../../../docs/qa/m7-integration-acceptance.md)에 기록했습니다.
