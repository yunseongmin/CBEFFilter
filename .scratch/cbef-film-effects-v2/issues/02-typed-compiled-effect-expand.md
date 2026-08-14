# 02 — 효과별 설정 컴파일 구조 확장

**What to build:** 다섯 효과의 공통 설정과 효과별 설정을 한 번 검증·컴파일한 뒤 렌더할 수 있게 확장하여, v2 파라미터가 늘어나도 다른 효과의 잘못된 설정이나 분기 비용에 영향을 받지 않게 합니다.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] 공통 작업 공간 입력, 출력 보기, 품질, Mix와 각 효과의 설정이 명확히 분리된 하나의 컴파일 결과로 렌더에 전달됩니다.
- [x] 기존 다섯 stable effect ID, 기본값, 프리셋 선택, identity 조건과 정의된 오류 동작이 유지됩니다.
- [x] 선택하지 않은 효과의 설정은 검증하거나 렌더 분기를 만들지 않으며, 효과별 설정 확장이 다른 효과의 계약을 깨지 않습니다.
- [x] 유효하지 않거나 non-finite인 설정은 렌더 전에 정확한 오류로 거부됩니다.
- [x] 기존 CPU·Metal 효과 계약이 공개 최상위 렌더 경계를 통해 계속 통과합니다.
- [x] 새 내부 primitive나 가짜 OFX host를 공개 테스트 경계로 추가하지 않습니다.

## Answer

`RenderPlan`에 공통 `CommonPlan`과 정확히 하나의 효과별 `std::variant`를 담는 `CompiledEffectPlan`을 추가했습니다. `render()`는 기존 설정 검증과 grain frame quantization을 통과한 요청을 `compileEffectPlan()`에서 한 번만 typed plan으로 펼치고, CPU adapter는 이 컴파일 결과의 stable effect ID로 분기합니다. 기존 Metal adapter가 사용하는 projection fields는 컴파일된 선택 대안에서만 채워집니다.

다섯 stable effect ID, 기본값·프리셋·identity 동작은 `tests/typed_compile_contract.cpp`에서 최상위 `render(RenderRequest, RenderBackend)`로 검증했습니다. 각 효과의 유효 렌더, Mix 0 identity byte 보존, finite 출력, non-finite 거부와 effect 간 settings mismatch를 확인합니다. 새 내부 primitive나 fake host는 추가하지 않았습니다.

검증:

- `make -C DaVinciFilmPlugin test-v2-compile` — 통과
- `xcrun clang++ ... -fsyntax-only .../src/core/RenderCore.cpp` — 통과
- `make -C DaVinciFilmPlugin build` — 로컬 Xcode 환경에 Metal CLI(`xcrun -sdk macosx metal`)가 없어 `CBEFFilmEffects.metallib` 단계에서 중단. 코드 컴파일과 focused CPU suite는 통과했습니다.

증적: `.omo/evidence/ticket-02-typed-compile.md`

## Comments

Stop-hook 재검증에서도 focused CPU 계약은 exit 0이었지만, `xcode-select -p`가 CommandLineTools를 가리키고 `xcrun --find metal`이 실패했습니다. 전체 plugin build는 metallib 단계에서 exit 2이므로 이 티켓은 전체 빌드가 가능한 Xcode Metal toolchain에서 재검증될 때까지 `ready-for-agent`로 유지합니다.

2026-08-12 환경 감사에서 이 Mac에 전체 Xcode 앱이 없고 Command Line Tools만 설치된 것을 확인했습니다. Metal compiler 설치는 시스템 수준의 사용자 작업이므로 `ready-for-human`으로 전환합니다. 전체 Xcode 설치 후 focused 계약과 전체 plugin build를 다시 실행하면 남은 criterion을 판정할 수 있습니다.

2026-08-12 전체 Xcode 26.6과 Metal Toolchain 17.6 설치 후, 프로젝트 범위의 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`로 전체 번들 및 M1~M6 CPU·Metal 계약을 강제 재빌드했습니다. `test-v2-compile`, M1~M6, ABI probe와 bundled metallib load가 모두 통과하여 마지막 criterion을 완료하고 티켓을 `resolved`로 전환합니다. 통합 증거는 `.omo/evidence/ticket04-green-20260812/verification.md`에 있습니다.
