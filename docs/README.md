# CBEF Filter 문서 안내

현재 제품을 이해하거나 다시 개발할 때는 아래 순서로 읽습니다.

## 제품과 구조

- [제품·구현 계획](PLAN.md): 지원 범위, 효과별 모델, 품질 기준
- [프로젝트 구조](PROJECT-STRUCTURE.md): 폴더 역할과 산출물 경계
- [공통 용어](../CONTEXT.md): 제품 도메인 언어
- [아키텍처 결정](adr/): 변경하면 안 되는 주요 기술 결정

## 설계와 근거

- [v2 전체 수정 범위](design/premium-film-effects-revision-scope.md)
- [1차 자료 조사](research/premium-film-effects-primary-sources.md)
- [심화 근거 조사](research/premium-film-effects-deep-evidence.md)
- [공식 RAW·Log QA 소스](research/official-raw-log-qa-sources.md)

## 검증과 개발 기록

- [QA 문서](qa/): 효과별 자동·수동 합격 기준
- [최종 개발 요약](DEVELOPMENT-ARCHIVE.md): v2 결과, 핵심 수정, 현재 해시
- [보존 증거](evidence/README.md): 최종 자동 검증, Resolve 캡처, 비교 이미지
- `.scratch/`: 완료된 v1·v2 spec과 티켓 이력
- `.omo/evidence/`: 티켓 단위 원시 로그와 이후 검증 명령이 생성할 작업 증거

새 문서는 목적에 따라 `adr/`, `design/`, `research/`, `qa/` 중 한 곳에만 추가하고 같은 내용을
여러 문서에 복제하지 않습니다.
