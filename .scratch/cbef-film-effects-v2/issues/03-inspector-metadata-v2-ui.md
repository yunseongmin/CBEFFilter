# 03 — v2 Inspector 메타데이터와 조작 흐름

**What to build:** Resolve Inspector에서 다섯 효과가 Basic, Advanced, Diagnostics로 정돈되고, 프리셋과 profile에 따라 필요한 제어만 자연스럽게 보이는 v2 조작 흐름을 제공합니다.

**Blocked by:** 02 — 효과별 설정 컴파일 구조 확장.

**Status:** resolved

- [x] 처음 열면 자연스러운 프리셋, 3~5개의 핵심 제어와 Mix가 Basic 그룹에 먼저 보입니다.
- [x] 세부 source·shape·spectrum·lens·quality 제어와 격리 출력은 각각 Advanced와 Diagnostics 그룹에 배치됩니다.
- [x] profile이나 출력 보기에 필요하지 않은 제어는 비활성화되거나 숨겨지고, 도움말은 결과 방향과 작업 공간 입력의 의미를 설명합니다.
- [x] 프리셋 변경은 작업 공간 입력, 출력 보기와 Mix를 보존하며, 값을 수정하면 Custom 상태가 드러나고 reset으로 되돌릴 수 있습니다.
- [x] 기존 다섯 효과 이름과 stable ID는 유지되고 카메라 Log 자동 감지나 변환을 제공한다고 표시하지 않습니다.
- [x] descriptor와 설정 컴파일 계약에서 표시 순서, 그룹, 기본값, 범위, 활성 조건이 단일 정의와 일치함을 검증합니다.

## Answer

- `ParameterDefinition`을 Inspector metadata의 단일 정의로 확장했습니다. 각 효과가 Basic, Advanced, Diagnostics 그룹, 표시 순서, semantic role, 도움말·단위·범위·정밀도, 조건부 활성화를 공유합니다.
- OFX descriptor는 같은 정의에서 Inspector page와 세 그룹을 생성하고, 그룹별 순서·기본값·hint·secret·초기 enabled 상태를 적용합니다. Lens Reflections의 Anamorphism은 Anamorphic lens profile에서만 활성화됩니다.
- Preset 변경은 `Working Mode`, `Output View`, `Mix`를 보존하고, preset-controlled 값을 수정하면 `Custom`으로 전환됩니다. 기존 다섯 stable ID와 카메라 변환 자동 감지 부재를 유지했습니다.
- focused metadata/typed settings contract, affected OFX bundle build, ABI probe가 모두 통과했습니다.
- 증거: [ticket03-inspector-20260812.md](/Users/younseongmin/Documents/CBEF/CBEFFilter/.omo/evidence/ticket03-inspector-20260812.md)
