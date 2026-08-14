# CBEF Filter 프로젝트 구조

이 디렉터리가 DaVinci Resolve용 CBEF Filter의 단일 개발 루트입니다.

```text
CBEFFilter/
├── assets/       외부 QA 자산의 URL·해시 manifest
├── include/      공개 C++ 렌더 계약
├── src/
│   ├── core/     CPU reference와 compiled effect plan
│   ├── metal/    Metal backend, Frame Arena, 사전 컴파일 shader
│   └── ofx/      OpenFX host adapter
├── tests/        CPU·Metal·ABI·통계·성능 계약
├── fixtures/     결정적 scene-linear 품질 기준 영상과 manifest
├── docs/         설계, 연구, ADR, QA와 최종 증거
├── packaging/    macOS PKG/DMG payload와 설치 정책
├── releases/     포맷 후 복구용 장기 보관 DMG와 checksum
├── scripts/      설치·삭제·개발 실행 도구
├── legacy/       현재 빌드와 분리된 Lightroom 초기 실험
├── .scratch/     v2 spec과 구현 티켓
├── .omo/         티켓 단위·향후 자동 검증 작업 증거
├── build/        로컬 빌드 산출물과 테스트 실행 파일
└── Makefile      빌드·테스트·설치 진입점
```

## 이름 규칙

- 개발 프로젝트명: `CBEF Filter`
- 개발 폴더명: `CBEFFilter`
- 현재 설치 번들명: `CBEFFilmEffects.ofx.bundle`
- Resolve 효과 그룹: `CBEF Film Effects`

번들명과 stable effect ID는 기존 프로젝트 호환성을 위해 v2 통합 티켓에서 명시적으로 변경하기 전까지 유지합니다.

완성 번들은 모든 리소스를 기록한 뒤 ad-hoc 서명합니다. 1.x 자동 백업은 활성 OpenFX 검색 루트가
아닌 `/Library/OFX/CBEFBackups`에 보관하여 Resolve가 백업까지 별도 플러그인으로 스캔하지 않게 합니다.

## 관련 프로젝트 경계

상위 `CBEF` 폴더의 `Figma to Photoshop For Designer`는 별도 프로젝트입니다. Lightroom 초기 실험은
자료 유실을 막기 위해 `legacy/`에 보존하지만 현재 제품 빌드에는 포함하지 않습니다. CBEF Filter
빌드와 검증은 항상 이 디렉터리에서 실행합니다.

외부 RAW는 프로젝트에 넣지 않고 `assets/`에 출처 URL과 해시만 남깁니다. 최종 텍스트 판정은
`docs/evidence/`, 재생성 가능한 실행 로그는 `.omo/`에 분리합니다.
