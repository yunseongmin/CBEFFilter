# CBEF Film Effects 제품·구현 계획

## 1. 목표

DaVinci Resolve Studio 전용 기능에 의존하지 않고 무료판의 Edit·Color 페이지에서 사용할 수 있는 개인용 OpenFX 효과 모음을 만듭니다. 한 번 설치하면 다음 다섯 효과가 각각 독립적으로 나타납니다.

1. `CBEF Halation`
2. `CBEF Film Grain`
3. `CBEF Optical Blur`
4. `CBEF Lens Reflections`
5. `CBEF Mist Diffusion` (`Black`·`White` 모드)

모든 기본값은 정상 속도 재생에서 효과보다 영상이 먼저 보이는 자연스러운 상태로 조정합니다. 강한 표현은 프리셋이나 조절값으로 선택합니다.

## 2. 지원 환경과 제외 범위

### 지원

- Apple M3 Pro, 18GB 메모리
- macOS 26
- DaVinci Resolve 무료판 21
- Apple Silicon `arm64`
- Metal GPU 처리와 CPU 기준 처리
- 32비트 부동소수 RGBA 입력·출력

### 제외

- DCTL 및 Studio 전용 기능
- 카메라별 Log 변환과 자동 카메라 감지
- Windows, Linux, Intel Mac
- 공개 배포, 코드 서명, 공증, 자동 업데이트
- VHS 손상, Gate Weave, Flicker
- 노이즈 제거, 물체 제거, 얼굴 보정 등 AI·복원 기능
- Blackmagic 또는 광학 필터 제조사의 내부 구현 복제

## 3. 사용 흐름과 색공간 계약

권장 흐름은 다음과 같습니다.

```text
카메라 Log
→ Resolve Color Management 또는 CST로 작업 색공간 변환
→ 기본 색보정
→ Mist Diffusion / Optical Blur / Lens Reflections
→ Halation
→ Film Grain
→ Resolve 출력 변환
```

Resolve가 카메라 Log 변환을 담당하고, 각 효과의 `Working Mode`를 실제 입력과 일치시킵니다. v1은 `DWG / Intermediate`, `DWG / Linear`, `Rec.709 / Gamma 2.4`를 지원합니다. 플러그인은 이 명시값으로 광학 효과를 내부 선형광으로 변환해 처리한 뒤 같은 인코딩으로 되돌립니다. 호스트가 작업 색공간 정보를 항상 제공한다고 가정하거나 입력을 자동 추정하지 않습니다. Inspector 안내문에 Resolve 설정과 `Working Mode`를 일치시키는 방법을 표시합니다.

내부 밝기 분석에서는 음수를 안전하게 제외하되 원본의 음수 값과 `1.0` 초과 HDR 값은 원본 혼합 경로에 보존하고 임의로 자르지 않습니다. Film Grain은 선형광을 내부 로그 노출·농도 영역으로 옮겨 영평균 입자를 더한 뒤 복원하여 하이라이트와 암부의 반응을 안정적으로 만듭니다.

## 4. 공통 사용성

모든 효과는 다음 원칙을 공유합니다.

- `Working Mode`: `DWG / Intermediate`(기본), `DWG / Linear`, `Rec.709 / Gamma 2.4`
- `Mix`: 원본과 결과의 혼합 비율
- `Output View`: `Final`, 효과 성분, 선택 매트 중 필요한 진단 보기
- `Reset`: 자연스러운 기본값으로 복귀
- 애니메이션 가능한 숫자 조절값
- 해상도 대신 화면 높이에 비례하는 반경으로 1080p·4K·프록시의 체감 크기 유지
- 효과 강도가 0이면 계산을 건너뛰고 입력을 그대로 반환

## 5. 효과 사양

### 5.1 CBEF Halation

장면 기준 밝기에서 하이라이트를 부드러운 무릎 곡선으로 분리하고, 밝은 핵심을 보존한 채 경계 바깥으로 여러 크기의 확산을 생성합니다. 결과는 선형광에서 따뜻한 적·주황 성분으로 더하며 전체 화면 글로우와 붉은 테두리를 억제합니다.

| 조절값 | 역할 | 기본 방향 |
|---|---|---|
| Amount | 번짐 강도 | 은은함 |
| Radius | 번짐 범위 | 35mm 계열의 얇은 범위 |
| Threshold | 반응할 밝기 | 강한 하이라이트 중심 |
| Highlights Only | 밝은 경계 제한 | 켜짐 |
| Warmth | 적색·주황색 균형 | 따뜻하지만 피부 침범 억제 |
| Saturation | 번짐 색 농도 | 낮음 |
| Mix | 원본 혼합 | 100% 내부 기본 효과 |

초기 프리셋은 `Subtle 35`, `Warm Negative`, `Strong Edge`로 제한합니다.

### 5.2 CBEF Film Grain

외부 스캔 영상 없이 출력 타임라인의 정수 프레임 번호와 Seed로 결정되는 절차적 입자를 생성합니다. 서브프레임 시간은 가장 가까운 출력 프레임으로 양자화합니다. 같은 프레임을 다시 렌더하면 같은 결과가 나오고 이웃 프레임은 서로 다른 패턴을 가집니다. 단일 흰색 노이즈가 아니라 여러 입자 크기, 채널 간 상관, 명암별 감도를 조합하고 내부 로그 노출·농도 영역에서 영평균으로 합성합니다.

| 조절값 | 역할 | 기본 방향 |
|---|---|---|
| Format | 입자 계열 | `35mm Fine` |
| Amount | 전체 강도 | 은은함 |
| Size | 입자 크기 | 해상도 독립 |
| Softness | 입자 경계 | 약간 부드러움 |
| Chroma | 색 입자 비율 | 낮음 |
| Shadow / Midtone / Highlight | 명암별 반응 | 중간톤 중심, 암부 과밀 억제 |
| Seed | 패턴 변형 | 고정 기본값 |
| Mix | 원본 혼합 | 100% 내부 기본 효과 |

초기 프리셋은 `16mm`, `35mm Fine`, `35mm Fast`, `65mm Fine`으로 제한합니다. 특정 필름 제조사나 재고 이름은 사용하지 않습니다.

### 5.3 CBEF Optical Blur

일반 가우시안 흐림이 아니라 조리개 모양을 가진 공간적 렌즈 블러를 만듭니다. v1은 AI 깊이 지도 없이 전체 프레임에 균일하게 적용하며, 필요하면 Resolve의 윈도우·키로 영역을 제한합니다.

| 조절값 | 역할 | 기본 방향 |
|---|---|---|
| Blur | 흐림 반경 | 매우 작음 |
| Blades | 조리개 날 수 | 둥근 다각형 |
| Curvature | 날의 곡률 | 자연스러운 원형 |
| Rotation | 조리개 회전 | 0° |
| Anamorphism | 가로·세로 비율 | 구면 렌즈 |
| Highlight Response | 밝은 영역 퍼짐 | 절제됨 |
| Mix | 원본 혼합 | 낮은 체감 강도 |

초기 프리셋은 `Clean Soft`, `Round Bokeh`, `Anamorphic`입니다.

### 5.4 CBEF Lens Reflections

현재 프레임의 강한 광원을 분리해 화면 중심과 광원 사이의 광축을 따라 여러 고스트를 생성합니다. 고정 플레어 이미지를 얹지 않고 입력 하이라이트의 모양과 색을 반사 요소에 사용합니다.

| 조절값 | 역할 | 기본 방향 |
|---|---|---|
| Amount | 전체 반사 강도 | 은은함 |
| Threshold | 반응할 광원 밝기 | 강한 광원만 |
| Lens Model | 고스트 배열 | `Clean Prime` |
| Spread | 광축상 분산 거리 | 짧음 |
| Blur | 반사 요소의 초점 | 약간 흐림 |
| Chroma | 색 분산 | 낮음 |
| Anamorphism | 반사 요소 비율 | 구면 렌즈 |
| Mix | 원본 혼합 | 낮은 체감 강도 |

초기 프리셋은 `Clean Prime`, `Vintage Prime`, `Anamorphic`입니다.

### 5.5 CBEF Mist Diffusion

하이라이트 확산, 대비 변화, 암부 반응, 세부 질감 복원을 조합해 렌즈 앞 확산 필터의 성격을 만듭니다. 상표가 포함된 필터명은 사용하지 않습니다.

| 조절값 | 역할 | 기본 방향 |
|---|---|---|
| Mode | `Black` 또는 `White` | `Black` |
| Density | `1/8`, `1/4`, `1/2`, `1` | `1/8` |
| Diffusion | 전체 부드러움 | 낮음 |
| Bloom | 하이라이트 확산 | 낮음 |
| Contrast | 대비 감소량 | Black은 적고 White는 큼 |
| Texture | 세부 질감 보존 | 높음 |
| Mix | 원본 혼합 | 100% 내부 밀도 효과 |

Black 모드는 하이라이트 플레어와 암부 상승을 억제하고, White 모드는 더 넓은 확산과 파스텔 같은 대비 감소를 허용합니다.

## 6. 모듈 설계

```text
DaVinci Resolve 21 Free
        │
        ▼
OFX Adapter Module
  등록 · 파라미터 · 프레임 시간 · render scale · 호스트 표면
        │  RenderRequest와 실행 백엔드 주입
        ▼
Render Core Module
  효과 수학 · 색 인코딩 · 알파 계약 · 패스 구성
        │
        ├── CPU RenderBackend: 동기 기준 처리와 fallback
        └── Metal RenderBackend: 호스트 큐에 비동기 제출
```

렌더 코어의 외부 인터페이스는 개념적으로 다음 한 동작만 제공합니다.

```text
render(request, backend) → RenderSubmission
```

`RenderRequest`에는 효과 종류, 원본·목적 표면, 프레임 크기와 시간, render scale, `Working Mode`, 설정만 포함합니다. `RenderBackend`가 표면 저장 방식, 임시 버퍼, 패스 실행과 완료 시점을 캡슐화합니다. `RenderSubmission`은 성공 시 `Completed` 또는 `Enqueued`, 동기 입력 검증·resource 준비·pipeline 생성·command encoding 실패 시 `Failed(error)`를 반환합니다. `Completed`는 CPU destination write가 반환 전에 끝났음을 뜻합니다. `Enqueued`는 모든 Metal encoder가 종료되고 모든 command buffer가 주입된 host queue에 commit되었음을 뜻하며 GPU 완료를 기다리지 않습니다. `Failed`에서는 destination을 유효 결과로 취급하지 않습니다. `Enqueued` 반환 후 발생하는 비동기 GPU 실행 오류는 동기 `Failed`로 소급하지 않습니다. 효과 수학은 Metal 큐와 버퍼 형식을 알지 않으며 테스트도 같은 렌더 인터페이스를 통해 수행합니다.

### 소스 구조

```text
DaVinciFilmPlugin/
├── Makefile
├── README.md
├── CONTEXT.md
├── vendor/openfx/          # 필요한 헤더·지원 코드와 BSD 고지
├── include/cbef/           # 렌더 코어 인터페이스와 설정 타입
├── src/ofx/                # Resolve 어댑터와 5개 효과 등록
├── src/core/               # 공통 영상 처리 규칙
├── src/cpu/                # 기준 구현
├── src/metal/              # 실사용 Metal 구현
├── tests/                  # 프레임 기반 자동 검증
├── fixtures/               # 합성 차트와 승인용 작은 이미지
└── docs/
```

빌드는 전체 Xcode 프로젝트 없이 Apple Command Line Tools와 Makefile을 사용합니다. Blackmagic의 현재 공식 샘플이 이 환경에서 정상적으로 빌드되는 것을 확인했습니다. 결과물은 `/Library/OFX/Plugins/CBEFFilmEffects.ofx.bundle`에 설치합니다.

## 7. 처리·성능 원칙

- 할레이션·미스트·광학 블러는 이웃 픽셀에 의존하므로 공간 독립 효과로 선언하지 않습니다.
- v1은 타일 경계 오류를 피하기 위해 전체 프레임 처리를 우선하고, 이후 ROI 확장을 최적화합니다.
- Grain은 OpenFX에서 frame-varying 효과로 선언하고 이전·다음 프레임을 읽지 않습니다. 출력 타임라인 시간을 가장 가까운 정수 프레임으로 양자화해 패턴을 생성합니다.
- OFX 입력의 premultiplication 상태를 확인합니다. Premultiplied 입력은 알파가 작은 픽셀을 안전하게 처리하며 straight RGB로 변환하고, 공간 샘플은 알파 가중치로 모아 숨은 RGB의 번짐을 막습니다. 처리 후 원래 상태로 다시 premultiply하며 알파는 변경하지 않습니다. 알파가 0인 픽셀은 방사광이 없는 것으로 취급합니다.
- 4K 부동소수 프레임의 임시 버퍼를 재사용하고 패스 수를 제한합니다.
- 모든 효과는 CPU와 Metal이 동일한 수학적 처리 명세를 만족해야 합니다.
- M3 Pro 기준 개별 효과 목표는 1080p 24fps 이상, 4K 12fps 이상입니다. Film Grain은 4K 24fps 이상을 목표로 합니다.
- 다섯 효과를 동시에 적용한 체인의 실시간 재생은 v1 완료 조건이 아닙니다.

## 8. 자동 검증 기준

- 효과 강도가 0이면 RGB 최대 절대 오차 `1e-6` 이하, 알파는 동일합니다.
- CPU와 Metal 출력의 최대 절대 오차는 `2e-4` 이하입니다.
- 음수와 `1.0` 초과 입력에서 NaN·Inf·임의 클리핑이 없습니다.
- 광학 효과는 4K 결과 축소본과 1080p 직접 렌더의 에지 위치·반경·저주파 에너지가 일치하고, 적절히 저역 통과한 비교 영상의 `PSNR`이 `45dB` 이상입니다.
- Grain은 해상도 간 직접 PSNR을 비교하지 않습니다. 화면 높이 기준 입자 크기, 채널별 평균·분산, 공간 주파수 스펙트럼, 공간·채널 상관이 허용 범위 안에서 일치해야 합니다.
- 프레임 가장자리와 프록시·전체 해상도 전환에서 seam이나 크기 점프가 없습니다.
- 동일한 프레임·시간·Seed의 Grain은 항상 동일합니다.
- 같은 출력 프레임 안의 서브프레임 시간은 같은 Grain을 만들고 다음 정수 프레임에서는 패턴이 바뀝니다.
- 인접 Grain 프레임의 상관계수 절댓값은 `0.1` 미만입니다.
- 48프레임 Grain 평균의 채널별 편향 절댓값은 `5e-4` 미만입니다.
- 기본 Halation은 바깥으로 부드럽게 감소하고 어두운 링이나 원본 하이라이트 변색이 없습니다.
- Premultiplied·straight·알파 0 경계 fixture에서 보이지 않는 RGB 번짐이 없고 알파는 입력과 동일합니다.

## 9. Resolve 무료판 수동 QA

다음은 실제 Resolve 화면에서 반드시 확인합니다.

1. Resolve 재시작 후 다섯 효과가 한 그룹에 나타납니다.
2. Edit 페이지 클립과 Color 페이지 노드에서 효과를 적용할 수 있습니다.
3. Studio 배지, 워터마크, DCTL 요구가 없습니다.
4. 각 조절값과 프리셋이 즉시 화면에 반영됩니다.
5. 재생·일시정지·탐색·재렌더에서 Grain이 고정되거나 튀지 않습니다.
6. 1080p·4K·프록시에서 Halation·Mist·Blur 반경의 체감이 유지됩니다.
7. 흰 자막과 그래픽에서 붉은 테두리, 과도한 플레어, 색 번짐을 점검합니다.
8. 피부와 창문 하이라이트, 야간 전구, 네온, 역광 머리카락, 미세 질감, 흰 그래픽, 단일·다중·화면 밖 광원을 포함한 짧은 기준 릴을 정상 속도와 100% 정지 화면으로 확인합니다.

현재 작업 폴더에는 대표 영상이 없습니다. 자동 테스트용 합성 클립은 직접 만들고, 시각 승인 단계 전에는 위 장면을 포함한 짧은 기준 릴을 사용자 촬영본과 재배포 가능한 테스트 소스로 구성해야 합니다.

## 10. 구현 순서

### M0. 플러그인 골격

- 한 번의 빌드로 다섯 효과 ID를 등록합니다.
- 모든 효과가 입력을 그대로 반환하는 상태로 Resolve에서 로드되는지 확인합니다.
- 설치·삭제·재빌드 절차를 고정합니다.

### M1. 렌더 코어와 기준 테스트

- 작은 프레임 렌더 인터페이스를 확정합니다.
- CPU·Metal identity 처리와 오차 비교를 통과시킵니다.
- 세 가지 `Working Mode`, HDR, premultiplied·straight 알파, render scale fixture를 만듭니다.

### M2. Halation

- 매트·다중 반경 확산·색 반응을 구현합니다.
- 합성 edge와 실제 야간 광원에서 자동·수동 QA를 통과시킵니다.

### M3. Film Grain

- 시간 결정적 절차 그레인과 명암·채널 반응을 구현합니다.
- frame-varying 선언과 프레임 시간 양자화를 고정합니다.
- 평균·분산·주파수 스펙트럼·상관·캐시·재렌더 검증을 통과시킵니다.

### M4. Mist Diffusion

- Halation의 검증된 확산 기반을 재사용해 Black·White 반응과 밀도 프리셋을 구현합니다.
- 피부 세부와 암부 유지 차이를 승인합니다.

### M5. Optical Blur

- 조리개 형태와 해상도 독립 반경을 구현합니다.
- 프레임 경계·하이라이트·아나모픽 모드를 승인합니다.

### M6. Lens Reflections

- 하이라이트 분리와 광축상 고스트 생성을 구현합니다.
- 여러 광원과 움직이는 광원에서 플레어 고정·점프가 없는지 승인합니다.

### M7. 통합 마감

- 프리셋과 자연스러운 기본값을 실제 촬영본으로 조정합니다.
- 전체 장면 유형을 담은 짧은 기준 릴을 구성하고 효과별 승인 결과를 기록합니다.
- 개별 효과 성능 목표를 확인합니다.
- Resolve 무료판 전체 수동 QA를 통과시킵니다.

## 11. 첫 버전 완료 조건

- 다섯 효과가 Resolve 21 무료판에서 독립적으로 로드·적용·렌더됩니다.
- 색공간, HDR, 알파, 시간 결정성 자동 검증이 모두 통과합니다.
- M3 Pro에서 개별 효과 성능 목표를 충족합니다.
- 실제 촬영본에서 자연스러운 기본값의 시각 승인이 완료됩니다.
- Studio 기능, DCTL, 외부 유료 라이브러리, 상표 필터 프리셋에 의존하지 않습니다.

## 참고 자료

- [Blackmagic Resolve Studio 기능 비교](https://documents.blackmagicdesign.com/SupportNotes/DaVinci_Resolve_Studio_20_Features.pdf)
- [OpenFX Image Effect API](https://openfx.readthedocs.io/en/main/Reference/ofxImageEffectAPI.html)
- [Tiffen Black 계열 확산 특성](https://flysteadicam.tiffen.com/collections/tiffen-filters/products/tiffen-black-promist-filters)
- 로컬 Blackmagic OpenFX SDK: `/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX`
