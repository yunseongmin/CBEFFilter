# Project instructions

## 모델 분담

- **현재 사용자 지정:** 기획, 설계, 구현, 수정, 빌드, 테스트를 모두 `gpt-5.6-sol` 에이전트에 위임한다.
- Luna는 사용자가 다시 요청하기 전까지 사용하지 않는다.
- 지정한 모델이나 reasoning effort로 위임할 수 없으면 전환했다고 주장하지 말고 사용자에게 알린다.

## Agent skills

### Issue tracker

이 프로젝트의 이슈와 스펙은 `.scratch/<feature-slug>/` 아래의 로컬 마크다운 파일로 관리한다. 자세한 규칙은 `docs/agents/issue-tracker.md`를 따른다.

### Triage labels

트리아지는 기본 역할 라벨을 그대로 사용한다. 라벨 매핑은 `docs/agents/triage-labels.md`를 따른다.

### Domain docs

도메인 문서는 루트 `CONTEXT.md`와 `docs/adr/`를 사용하는 single-context 구조다. 소비 규칙은 `docs/agents/domain.md`를 따른다.

## 경량 구현·검증 정책

- 각 구현 티켓은 하나의 fresh context에서 완료한다. 구현 에이전트는 해당 티켓, 제품 spec, `CONTEXT.md`, 관련 ADR을 읽고 이전 대화의 암묵적 결정을 가정하지 않는다.
- 코드 구현·수정·빌드·테스트는 Luna `xhigh` 모델 분담 규칙을 따른다.
- 자동 테스트는 공개 `Headless Render Contract` seam을 통해서만 작성한다. 내부 blur, matte, RNG, ghost pass를 별도 공개 테스트 interface나 fake host로 노출하지 않는다.
- 작업 중 필요한 증분 build는 허용하되 티켓 완료 증거로 affected target build 한 번과 해당 티켓의 focused suite 한 번만 요구한다. 매 티켓마다 clean build나 전체 suite를 반복하지 않는다.
- 실제 Resolve Free 확인은 M0 설치·로드 smoke 한 번과 M7 전체 Host Acceptance 한 번으로 제한한다. M1~M6에서는 Resolve를 반복 실행하지 않는다.
- 검증 소유권은 M1 공통 계약·색·알파, M2 Halation, M3 Grain statistical, M4 Mist, M5 Optical Blur, M6 Lens Reflections, M7 통합 성능·최종 Resolve QA로 고정한다.
- Grain heavy statistical suite와 효과별 해상도 suite는 소유 티켓에서 실행한다. 이후 해당 production 동작이 바뀌지 않았다면 M7은 증거를 재사용하고, 영향받은 suite만 다시 실행한다.
- 전체 lightweight Headless regression, clean package build와 모든 효과의 성능 측정은 M7에서 한 번 실행한다.
- 명세가 정한 3-frame warm-up, 10-frame 성능 표본, 48-frame Grain 통계와 효과별 세 번의 Resolve 재생 횟수는 줄이지 않는다.
- 완료 기록에는 build 결과, focused test 결과, 실패가 있었다면 최종 해결 상태와 생성된 QA artifact 식별자만 남긴다. 같은 screenshot, frame export나 통계 보고서를 여러 티켓에 복제하지 않는다.
- 입력이 바뀌지 않은 동일 검증을 반복하지 않는다. 코드·설정·fixture가 바뀐 경우에만 영향받은 검증을 다시 실행한다.
- 명세에 이미 결정된 구현 선택은 사용자에게 다시 묻지 않는다. 명세와 ADR이 실제로 충돌하거나 외부 권한·사용자 시각 승인 없이는 진행할 수 없는 경우에만 상태를 명시하고 중단한다.
