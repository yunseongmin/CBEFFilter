# CBEF Filter

DaVinci Resolve 무료판에서 사용하는 Apple Silicon Mac 전용 개인용 OpenFX 필터 프로젝트입니다.

개발 루트는 이 폴더 하나입니다. 소스, 테스트, 설계 문서, 품질 fixture와 빌드 증거를 모두 이 경로 아래에서 관리합니다.

Resolve에 등록되는 기존 번들명과 효과 ID는 프로젝트 호환성을 위해 `CBEF Film Effects`로 유지합니다.
`CBEF Filter`는 개발 프로젝트와 제품군을 부르는 이름입니다.

v2는 번들명과 다섯 OpenFX 효과 ID는 유지하지만 내부 효과 모델을 교체합니다. 숨은 v1 알고리즘 선택이나 자동 설정 마이그레이션은 포함하지 않습니다.

현재 v2 다섯 효과의 CPU·Metal 구현과 자동 통합 Gate가 구성되어 있습니다. 마지막 제품 승인은 실제 Resolve Free Host Acceptance와 사용자 원본 영상의 미학 승인으로 분리합니다.

## 개발 워크플로

로컬 OpenFX SDK는 DaVinci Resolve 설치본의 다음 위치를 사용합니다.

```text
/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX
```

Apple Command Line Tools로 arm64 번들을 빌드하고 등록 ABI를 확인합니다.

```sh
make test
```

빌드가 끝나면 `Contents/Resources`와 `Info.plist`까지 포함한 완성 번들을 ad-hoc 서명합니다.
이는 개인용 로컬 번들의 무결성 확인용이며 Developer ID 배포 서명이나 공증을 뜻하지 않습니다.
호스트 생성 생명주기와 설치 패키지는 각각 `make test-host-action`,
`make test-package-install`로 별도 확인할 수 있습니다.

v2 전체 clean build, fixture/provenance, ABI, 효과별 CPU·Metal 계약, 8K·12K 정확성,
48-frame Grain 통계와 성능·메모리 Gate는 다음 단일 명령으로 재현합니다.

```sh
make verify-v2
```

Metal 효과는 빌드 시 `src/metal/kernels/CBEFFilmEffects.metal`을 `CBEFFilmEffects.metallib`로
사전 컴파일하여 `Contents/Resources`에 넣습니다. 실행 중 Metal 소스 컴파일은 사용하지 않습니다.
따라서 빌드에는 전체 Xcode의 `metal`·`metallib` 도구가 필요합니다. 테스트 실행 파일은 같은
라이브러리를 `build/tests/CBEFFilmEffects.metallib`에서 사용합니다.

설치 번들에 라이브러리가 포함되었는지 ABI probe로 확인할 수 있습니다.

```sh
make test
```

개발 중 라이브러리 위치를 명시해야 하는 경우에만 `CBEF_METALLIB_PATH`를 사용할 수 있습니다.
이 변수는 이미 사전 컴파일된 파일을 선택할 뿐, 런타임 컴파일 fallback을 활성화하지 않습니다.

시스템 OpenFX 경로에 설치하거나 삭제하려면 관리자 권한이 필요합니다.

```sh
sudo make install
sudo make uninstall
```

Finder에서 더블클릭할 수 있는 macOS 설치 프로그램과 배포용 DMG는 다음 명령으로 만듭니다.

```sh
make dmg
```

결과물은 `build/dist/CBEFFilter-2.0.0.pkg`와
`build/dist/CBEFFilter-2.0.0.dmg`입니다. DMG에는 PKG 설치 프로그램,
설치 안내, 관리자 권한으로 실행되는 제거 명령이 들어 있습니다. PKG도 기존 1.x 번들을
활성 OpenFX 검색 경로 밖의 `/Library/OFX/CBEFBackups`로 이동한 뒤 v2를 설치합니다.
현재 개인용 패키지는 ad-hoc 서명 상태이며 Developer ID 서명·공증 배포본은 아닙니다.

포맷 후 오프라인 재설치용으로 장기 보관할 개인 복구본은 다음 명령으로 만듭니다.

```sh
make personal-restore
```

`releases/CBEFFilter-2.0.0-Personal-Restore.dmg`와 검증용 `.sha256` 파일이 생성됩니다.
`releases/`는 `make clean`으로 지워지지 않으므로 두 파일을 외장 저장장치나 클라우드에 함께
복사해 두면, 포맷 후 Xcode나 소스 코드 없이 PKG를 더블클릭해 복구할 수 있습니다.

기존 1.x 번들이 있으면 설치 스크립트가 v2 설치 전에
`/Library/OFX/CBEFBackups/CBEFFilmEffects-v1-backup.ofx.bundle`로 한 번만 이동합니다.
백업은 Resolve가 검색하는 `/Library/OFX/Plugins` 밖에 두며 기존 백업을 덮어쓰지 않습니다.
이전 설치기가 활성 검색 경로에 만든 백업도 다음 설치 때 외부 백업 폴더로 이동합니다.
v1 복구가 필요하면 Resolve를 종료한 뒤 현재 v2 번들을 다른 곳으로 옮기고, 외부 백업을
`/Library/OFX/Plugins/CBEFFilmEffects.ofx.bundle`로 옮깁니다.

개발 중 새 빌드와 설치를 연속으로 실행하려면 다음을 사용합니다.

```sh
./scripts/dev.sh
```

설치 뒤에는 실행 중인 Resolve를 강제 종료하지 말고, 사용자가 Resolve를 다시 시작해 `CBEF Film Effects` 그룹의 다섯 효과를 확인합니다. M0의 실제 환경 기록은 [M0 Resolve Free smoke evidence](docs/qa/m0-resolve-free-smoke.md)에 남깁니다.

- [제품·구현 계획](./docs/PLAN.md)
- [문서 안내](./docs/README.md)
- [프로젝트 폴더 구조](./docs/PROJECT-STRUCTURE.md)
- [최종 개발 요약](./docs/DEVELOPMENT-ARCHIVE.md)
- [보존 QA 증거](./docs/evidence/README.md)
- [용어집](./CONTEXT.md)
- [아키텍처 결정 기록](./docs/adr/)
