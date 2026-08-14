# CBEF Film Effects v2: 유료급 품질 재설계 범위

작성일: 2026-08-12  
대상: `CBEF Halation`, `CBEF Film Grain`, `CBEF Lens Reflections`, `CBEF Mist Diffusion`, `CBEF Optical Blur`  
상태: 구현 착수 가능한 설계 기준  
결론: **현재 v1은 호스트 호환성과 수치 안전성은 확보했지만, 상용 고급 필터에 필요한 광학·필름 모델과 시각 승인 기준은 부족합니다. 파라미터 튜닝이 아니라 다섯 효과의 핵심 알고리즘과 공통 내부 구조를 v2로 교체해야 합니다.**

## 1. 이번 판단의 기준

여기서 `유료급`은 특정 제품의 내부 구현이나 화면을 복제한다는 뜻이 아닙니다. 다음 네 조건을 함께 만족하는 독립 구현을 뜻합니다.

1. 효과가 강해도 단순 블러·노이즈·오버레이로 보이지 않습니다.
2. 광원의 밝기·색·위치, 배경 밝기, 노출, 렌즈 중심, 화면 위치에 반응합니다.
3. 각 조절값이 물리적으로 일관된 방향으로 움직이고 진단 화면에서 설명 가능합니다.
4. CPU/Metal, 해상도, 프록시, 탐색 순서에 관계없이 같은 룩을 유지하며 실제 RAW/Log 기준 릴에서 시각 승인을 받습니다.

조사 근거는 [1차 자료 조사](../research/premium-film-effects-primary-sources.md)에 정리되어 있습니다. Kodak의 anti-halation 층과 RMS granularity/MTF 자료, Tiffen·Schneider·Hoya의 확산 필터 특성, Canon·ARRI의 내부 반사 설명, Nikon·ZEISS의 bokeh/수차 자료, Dehancer·FilmConvert·Blackmagic의 공개 사용자 제어를 **관찰 가능한 동작과 검증 항목의 근거**로만 사용합니다.

## 2. 현재 상태: 무엇이 통과했고 무엇이 통과하지 않았는가

### 2.1 이미 확보된 기반

현재 외부 렌더 인터페이스는 깊은 모듈에 가깝습니다. 호출자는 `render(request, backend)` 하나만 알면 되고, 호스트 표면·알파·작업 색공간·효과 설정을 한 요청에 전달합니다. CPU와 Metal은 이 seam의 두 실제 adapter입니다 ([RenderCore.h](../../include/cbef/RenderCore.h), 126–206행).

다음 기능 게이트는 유지해야 합니다.

- 32-bit float RGBA, 음수와 1.0 초과 HDR, straight/premultiplied alpha 처리
- Amount 또는 Mix 0의 bit-exact identity
- 렌더 윈도우 밖 메모리 보존
- 화면 높이 기준의 해상도 독립 크기
- 동일 Grain frame/seed의 결정성
- CPU/Metal 최대 절대 오차 `2e-4` 이하
- Resolve Free 21.0.4에서 다섯 효과 로드·적용·삭제·저장

현재 자동 계약은 위 항목을 상당히 잘 검증합니다. 예를 들어 Halation은 alpha/HDR/해상도/CPU-Metal parity를 검사하고 ([halation_render_contract.mm](../../tests/halation_render_contract.mm), 205–249행, 428–587행), Grain은 48프레임 평균·RMS·시간 상관·공간 스펙트럼을 검사합니다 ([film_grain_render_contract.mm](../../tests/film_grain_render_contract.mm), 209–345행). 이 기반은 삭제하지 않고 v2 품질 계약으로 확장합니다.

### 2.2 현재 PASS가 의미하지 않는 것

기존 RAW QA는 고정된 310×166 뷰어 캡처의 픽셀 차이만 측정했으며 스스로도 “float/Metal 계약을 대체하는 미학적 검증이 아니다”라고 명시합니다 ([raw-footage-effects-qa.md](../qa/raw-footage-effects-qa.md), 21–36행). 강한 설정 QA에서도 Halation Amount 100의 viewer MAE는 `0.529`, 최대 채널 변화는 `8`에 불과했고 Lens Reflections는 큰 흰 복제상을 만들었습니다 ([raw-footage-strong-effects-qa.md](../qa/raw-footage-strong-effects-qa.md), 14–34행).

따라서 현재의 `PASS`는 다음만 뜻합니다.

- 효과가 로드됩니다.
- 프레임을 변경합니다.
- 크래시·NaN·알파 파손 없이 CPU와 Metal이 비슷한 값을 만듭니다.

다음은 아직 증명되지 않았습니다.

- 필름 할레이션처럼 보이는지
- 입자가 스캔 필름의 노출·색층 반응처럼 보이는지
- Mist가 실제 광학 필터처럼 초점은 유지하고 미세 대비만 다듬는지
- Lens Reflections가 렌즈 내부 반사처럼 보이는지
- Optical Blur가 단순한 균일 조리개 convolution을 넘어 렌즈 성격을 갖는지

## 3. 코드 감사 요약

| 영역 | 현재 구현 | 품질 한계 | 우선순위 |
|---|---|---|---|
| Halation | 하이라이트 RGB를 3개 Gaussian 반경으로 blur하고 원본을 뺀 뒤 고정 warm gain 적용 | 먼저 백색/RGB 블룸이 생성되고 마지막에 착색되므로 따뜻한 흰 블룸처럼 보임. local edge halo와 global red glare가 분리되지 않음 | Must |
| Film Grain | Philox 기반 3-octave Gaussian lattice를 RGB에 상관 혼합하고 로그 노출 배율로 합성 | 결정성과 통계는 좋지만 고정 tone curve·고정 channel size·대칭 Gaussian 분포라 필름 record/dye-cloud와 노출별 구조가 단순함 | Must |
| Mist | positive image와 highlight matte를 2개 Gaussian lobe로 blur. Black/White는 부호·반경·대비 상수로 구분 | highlight glow, broad veil, detail MTF가 독립 모델이 아니며 `Texture`는 원본/대비 결과 단순 보간 | Must |
| Optical Blur | 이진 polygon aperture의 균일 convolution과 highlight 추가 | 화면 중앙/모서리 PSF가 같고 cat-eye·rim/center 분포·수차가 없음. depth 없이 DOF처럼 보일 위험 | Must |
| Lens Reflections | 전체 source matte를 화면 중심 반대편으로 3–5회 affine warp 후 Gaussian blur·고정 tint | 하이라이트의 원래 실루엣을 그대로 복제해 불투명 스티커가 됨. element별 aperture/ring/falloff/배경 적응이 없음 | Must |
| 파라미터 UI | `Double/Integer/Boolean/Choice`의 한 줄 flat list | Basic/Advanced 그룹, 동적 활성화, 점/색 제어, 물리적 도움말이 없음 | Must |
| 내부 구조 | `RenderCore.cpp` 1,951행과 `MetalRenderBackend.mm` 2,994행에 정의·수학·실행이 집중 | 효과 지식과 backend 지식의 locality가 낮고 CPU/Metal 수학을 두 군데서 수정해야 함 | Must |
| Metal 메모리 | 효과마다 full-frame shared buffer 다수 생성 | 4K Lens/Mist 임시 메모리 663,552,000B. v2 다중 패스를 그대로 추가하면 8K/12K와 18GB 장비에서 위험 | Must |

### 3.1 Halation의 직접 원인

현재 Halation은 밝기 매트를 만든 뒤 RGB 세 채널 전체를 같은 세 반경으로 흐립니다 ([RenderCore.cpp](../../src/core/RenderCore.cpp), 890–974행). 그 결과에 `{1.0, 0.55, 0.20}` 목표색 기반 gain과 saturation을 마지막에 적용합니다 (976–1009행). 즉, 모델의 본체는 `RGB highlight bloom`이고 red/orange는 후처리 tint입니다.

이 구조에서는 다음 문제가 필연적입니다.

- 중성 백색 광원은 먼저 세 채널이 함께 확산되므로 saturation이 낮을수록 흰 halo가 됩니다.
- `Warmth`와 `Saturation`으로 색만 바뀌고 채널별 확산 반경·흡수·민감도는 바뀌지 않습니다.
- 좁은 경계 halo와 넓은 중간톤 red glare를 독립적으로 제어할 수 없습니다.
- `highlights_only=false`는 모든 positive pixel을 source로 열기 때문에 전체 화면 warm glow가 될 수 있습니다 (791–802행).
- 현재 테스트는 중성 impulse에서 `R ≥ G ≥ B`만 검사합니다 ([halation_render_contract.mm](../../tests/halation_render_contract.mm), 155–202행). “붉은 성분이 충분한가”, “중심은 중성으로 유지되는가”, “local/global layer가 분리되는가”는 보장하지 않습니다.

### 3.2 Film Grain의 현재 강점과 한계

현재 Grain은 Philox counter RNG, frame/seed 결합, 3-octave lattice, shared/independent channel 혼합을 사용합니다 ([RenderCore.cpp](../../src/core/RenderCore.cpp), 565–681행). 단순 white noise overlay보다 훨씬 좋은 기반입니다. 또한 로그 노출에 영평균 multiplicative perturbation을 적용합니다 (1035–1113행).

그러나 `Format`은 네 개의 고정 직경·강도 상수, tone response는 `shadow/midtone/highlight` 3구간 고정 smoothstep, 모든 RGB record는 같은 입자 직경을 공유합니다. Kodak/Fujifilm이 사용하는 노출별 RMS granularity와 color record별 MTF 관점에서 보면 다음이 빠져 있습니다.

- 노출에 따른 입자 RMS·clumping·크기 변화 곡선
- color record별 입자 크기와 MTF
- dye-cloud 간 비대칭 분포와 포화 한계
- grain 자체와 원본 film-resolution/softness의 분리
- flat-field 여러 노출에서의 계측 기반 profile

### 3.3 Mist의 직접 원인

현재 Mist는 전체 positive image와 1–3 stop highlight matte를 각각 두 Gaussian lobe로 blur합니다 ([RenderCore.cpp](../../src/core/RenderCore.cpp), 1470–1537행). Black mode는 `max(blur-source, 0)`만 사용하고 White mode는 signed `blur-source`를 사용한 뒤 서로 다른 contrast 상수를 적용합니다 (1563–1596행).

이것은 Black/White 차이를 만들지만 실제 필터의 세 가지 현상, 즉 `국소 highlight glow`, `저주파 veil`, `고주파 detail/MTF 변화`를 분리하지 않습니다. `Texture`도 주파수 선택적 복원이 아니라 source와 contrasted 결과의 단순 보간입니다 (1591–1593행). 따라서 강한 White는 화면 전체 fog, 강한 Black은 일반 diffusion blur로 보이기 쉽습니다.

### 3.4 Optical Blur의 직접 원인

현재 kernel은 4×4 subpixel coverage로 polygon aperture를 만들고 모든 픽셀에 동일하게 convolution합니다 ([RenderCore.cpp](../../src/core/RenderCore.cpp), 684–775행). 에너지 보존과 aperture 형태는 검증되어 있지만 다음 렌즈 특성은 없습니다.

- 화면 위치별 cat-eye와 optical vignetting
- PSF center/rim 분포를 바꾸는 spherical aberration
- wavelength별 PSF와 longitudinal/lateral chromatic aberration
- field curvature/coma/astigmatism
- near/far 비대칭과 depth occlusion

v2에서도 depth 입력이 없으면 기능명을 `Depth of Field`로 확장하지 않습니다. `Optical Blur/Defocus`라는 정직한 범위 안에서 field-dependent PSF와 렌즈 성격을 고급화합니다.

### 3.5 Lens Reflections의 직접 원인

현재 모델은 3/5/4개의 `k`, energy, tint 상수를 갖습니다 ([RenderCore.cpp](../../src/core/RenderCore.cpp), 73–90행). source matte 전체를 화면 중심 반대 방향으로 affine mapping하고 (1279–1363행), 각 복제본을 동일 Gaussian으로 흐리고 고정 tint를 더합니다 (1365–1409행).

RAW 비교에서 얼굴 위에 원본 조명 실루엣이 흰 조각처럼 복제된 이유가 이것입니다. source isolation은 luminance threshold 하나뿐이고, aperture element mask·ring·radial falloff·coating response·background adaptation이 없습니다. 여러 광원의 matte를 한 장으로 warp하므로 각 광원에 독립적인 element chain을 만든다기보다 장면 하이라이트 전체를 축소·반전 복사합니다.

## 4. v2 아키텍처: 외부 seam은 유지하고 내부 모듈을 깊게 만든다

### 4.1 유지할 외부 인터페이스

외부 seam은 계속 다음 하나입니다.

```text
render(RenderRequest, RenderBackend) -> RenderSubmission
```

이 인터페이스는 호출자에게 높은 leverage를 제공합니다. OFX adapter와 모든 계약 테스트가 같은 seam을 사용하며 CPU/Metal 실행 차이를 숨깁니다. 삭제하면 검증·알파·메모리·제출 규칙이 모든 호출자에 다시 퍼지므로 이미 충분한 depth를 갖습니다.

### 4.2 새 내부 모듈과 seam

```text
OFX Adapter
  └─ flat host values
       ↓
Effect Catalog + Effect Compiler
  └─ CompiledEffect variant (typed, validated, normalized)
       ↓
Film/Optics Effect Modules
  ├─ HalationModel
  ├─ GrainModel
  ├─ MistModel
  ├─ OpticalDefocusModel
  └─ LensReflectionsModel
       ↓
Optics Primitives seam
  ├─ CPU adapter: reference float implementation
  └─ Metal adapter: production GPU implementation
       ↓
Frame Arena + Color Pipeline
```

#### A. Effect Catalog + Effect Compiler

작은 인터페이스:

```text
compile(effectId, hostSettings, frameContext) -> CompiledEffect | Error
```

구현 안에 숨길 것:

- string parameter ID 조회와 variant type 검사
- preset expansion
- display 값에서 normalized/scene-linear 값으로 변환
- density·format·lens profile curve expansion
- identity 판단
- diagnostic view와 quality mode 결정

현재는 `Settings.values`의 위치와 runtime variant를 여러 곳에서 다시 해석하고, `RenderPlan`이 다섯 효과의 parameter struct를 모두 동시에 보유합니다 ([RenderPlan.h](../../src/core/RenderPlan.h), 14–75행; [RenderCore.cpp](../../src/core/RenderCore.cpp), 1801–1869행). v2는 다음 typed variant로 바꿉니다.

```text
CommonPlan + variant<HalationPlan, GrainPlan, MistPlan,
                     OpticalDefocusPlan, LensReflectionsPlan>
```

효과별 plan은 이미 profile curve와 multi-lobe PSF를 펼친 **렌더 준비 상태**여야 합니다. backend가 UI 의미나 preset 이름을 알아서는 안 됩니다. 이 deep module 하나로 OFX, CPU, Metal, 테스트가 같은 해석을 공유해 locality가 생깁니다.

#### B. Color Pipeline

작은 내부 인터페이스:

```text
decodeToSceneLinear(rgb, WorkingSpace)
encodeFromSceneLinear(rgb, WorkingSpace)
exposureMetric(rgb, IsolationColorMode)
```

현재 `toDwg/fromDwg`와 DWG luminance 수학은 한 파일에 묻혀 있습니다 ([RenderCore.cpp](../../src/core/RenderCore.cpp), 485–550행). v2에서는 transfer와 gamut을 명시적으로 분리합니다.

Must:

- `DWG Intermediate`, `DWG Linear`, `Rec.709 Gamma 2.4` 유지
- scene-linear 광량 branch와 perceptual/detail branch를 효과 안에서 구분
- negative residual과 >1 HDR 원본 보존
- source isolation에 `Luminance`, `Max RGB`, `Per-channel` 모드 제공. 포화 blue LED가 DWG Y 계산에서 누락되지 않게 함
- 모든 효과의 작업 색공간 fixture를 한 모듈에서 재사용

Should:

- `ACEScct` 입력 추가. 단, OFX host metadata 자동 추정 없이 사용자가 명시
- Working Mode 불일치 경고용 Inspector help text

#### C. Optics Primitives

CPU와 Metal이라는 두 adapter가 실제로 존재하므로 이 seam은 정당합니다. 단, generic pass graph를 외부에 노출하는 얕은 모듈을 만들지 않습니다. 효과 모듈만 사용하는 다음 고수준 연산을 제공합니다.

```text
isolateSources(image, IsolationSpec) -> SourceLayers
scatterPyramid(layer, ScatterProfile) -> ScatterLayers
shapeFrequencyBands(image, FrequencyProfile) -> DetailLayers
projectAperture(source, FieldPsfProfile) -> ProjectedLayer
projectGhostElements(source, LensProfile) -> GhostLayers
synthesizeGrain(frame, GrainProfile) -> GrainLayers
```

각 호출은 alpha, edge extension, render scale, energy normalization을 내부에서 처리합니다. 테스트는 주로 최종 `render()` seam을 통과하고, primitive 자체 테스트는 CPU/Metal adapter의 수치 conformance에만 사용합니다.

#### D. Frame Arena

현재 Metal은 렌더마다 full-frame shared buffer를 여러 개 생성합니다 ([MetalRenderBackend.mm](../../src/metal/MetalRenderBackend.mm), 2367–2374행, 2466–2471행, 2706–2710행, 2835–2838행). v2는 command-buffer 완료와 연결된 in-flight arena를 사용합니다.

Must:

- 동일 command buffer 안에서 lifetime이 겹치지 않는 scratch aliasing
- wide scatter는 half/quarter/eighth-resolution RGBA16F 또는 R16F pyramid
- source matte는 단일 채널 R16F
- full-resolution 복제본 3–5개 금지
- command completion 전 재사용 금지
- 요청 실패 시 destination 유효 결과로 간주하지 않는 기존 계약 유지

목표 임시 메모리:

| 해상도 | Halation | Grain | Mist | Optical | Reflections |
|---|---:|---:|---:|---:|---:|
| UHD | <160 MiB | <64 MiB | <220 MiB | <192 MiB | <256 MiB |
| 8K | <640 MiB | <192 MiB | <880 MiB | <768 MiB | <1 GiB |

12K는 정확성·최종 렌더 대상이지 실시간 목표가 아닙니다. pyramid와 scratch aliasing으로 단일 효과 임시 메모리를 1.5GiB 아래로 유지하고, Resolve proxy/render scale에서 룩 크기가 바뀌지 않아야 합니다.

### 4.3 권장 소스 locality

| 새 위치 | 책임 |
|---|---|
| `src/core/EffectCatalog.cpp` | UI 정의·preset 표. 렌더 수학 없음 |
| `src/core/EffectCompiler.cpp` | host settings → typed `CompiledEffect` |
| `src/core/ColorPipeline.*` | working-space 변환과 exposure metric |
| `src/core/effects/HalationModel.*` | source/edge/global/spectral profile |
| `src/core/effects/GrainModel.*` | format·노출·record response profile |
| `src/core/effects/MistModel.*` | filter density와 glow/veil/detail profile |
| `src/core/effects/OpticalDefocusModel.*` | field PSF와 aberration profile |
| `src/core/effects/LensReflectionsModel.*` | source isolation과 ghost element profile |
| `src/cpu/CpuOpticsAdapter.*` | CPU reference primitives |
| `src/metal/MetalOpticsAdapter.mm` | queue/arena/pipeline orchestration |
| `src/metal/kernels/*.metal` | effect별 Metal kernel. C++ raw string에서 분리 |
| `tests/quality/` | model behavior, golden EXR, parameter sweep |
| `fixtures/quality/manifest.json` | source, license, color pipeline, frame/crop/hash |

목표는 파일 수 증가 자체가 아니라 **한 효과의 알고리즘·profile·검증 지식이 한 곳에 모이는 locality**입니다. Metal resource 관리 변경이 Grain 수학을 건드리거나, Halation 파라미터 추가가 Mist branch를 수정하게 해서는 안 됩니다.

## 5. 효과별 v2 수정 범위

### 5.1 Halation v2

#### 목표 모델

```text
scene-linear input
→ source isolation (exposure + color + background)
→ edge-local source / broad source 분리
→ spectral scatter (R dominant, G/B controlled)
→ narrow edge halo + wide red glare
→ core protection + background adaptation
→ scene-linear composite
```

단일 warm tint를 폐기하고 다음 두 layer를 분리합니다.

1. **Local Halo**: 강한 광원·고대비 경계 바깥의 좁은 red-orange halo. edge-normal 방향으로 자연스럽게 퍼지되 외곽선처럼 일정 두께로 붙지 않습니다.
2. **Global Red Glare**: 광원과 밝은 중간톤 주변의 넓고 약한 red contamination. 배경이 밝을수록 시각적 impact가 줄어듭니다.

채널별 PSF는 최소한 `R radius > G radius > B radius`와 서로 다른 energy를 가져야 하며, 중성 광원의 중심은 core protection으로 중성을 유지합니다. `Blue Compensation`은 blue source가 무조건 꺼지거나 고정 빨강으로 바뀌지 않게 source layer 기여도를 조절합니다.

#### 파라미터 인터페이스

기존 ID를 가능한 한 유지하되 label과 내부 의미를 깊게 만듭니다.

| 그룹 | ID | 표시명 | 범위 / 기본 | 역할 |
|---|---|---|---|---|
| Basic | `amount` | Impact | 0–200 / 22 | 최종 local+global 에너지 |
| Basic | `threshold` | Source Limit | -2–8 stop / 2.0 | 발광 source 기준 |
| Basic | `radius` | Local Radius | 0–5 %H / 0.45 | 좁은 halo 크기 |
| Basic | `hue` | Halo Hue | -30–30° / 0 | red↔orange 미세 조절 |
| Source | `source_smoothness` | Source Smoothness | 0–100 / 45 | threshold knee |
| Source | `background_protection` | Background Protection | 0–100 / 60 | 밝은 배경에서 halo 억제 |
| Shape | `edge_width` | Edge Width | 0–2 %H / 0.12 | local source band |
| Shape | `global_diffusion` | Global Diffusion | 0–100 / 25 | 넓은 red glare |
| Spectrum | `red_bias` | Red Bias | 0–100 / 78 | red-sensitive layer energy |
| Spectrum | `blue_compensation` | Blue Compensation | 0–100 / 18 | blue/cyan source 보정 |
| Composite | `core_protection` | Core Protection | 0–100 / 85 | 흰 중심 재착색·clipping 방지 |

`warmth`, `saturation`, `highlights_only`는 v2에서 직접 UI에 유지하지 않습니다. 이 프로젝트는 공개 배포된 호환 제품이 아니므로 legacy algorithm mode를 추가하지 않고, v1 bundle을 별도 백업한 뒤 v2 profile로 교체합니다. 기존 effect identifier는 유지하고 plugin major version을 2로 올립니다.

#### 프리셋

- `35mm Subtle` (기본)
- `35mm Warm Negative`
- `16mm Edge Rich`
- `Large Format Clean`
- `No Backing / Strong` (설명에 “강한 anti-halation 부재 성격”, 특정 stock 정확 재현 아님 명시)

#### Must / Should / Could

Must:

- local/global layer와 source mask 진단 출력
- 채널별 radius/energy
- core/background protection
- neutral, tungsten, blue LED, saturated red source fixture
- 강한 설정에서도 white bloom이 아닌 red-orange edge 특성

Should:

- edge 방향성에 따른 local scatter 비대칭
- skin hue protection
- profile별 source sensitivity curve

Could:

- 31-sample spectral 모델
- 사용자 정의 layer response curve

#### 합격 기준

- 중성 점광원의 `Halation Only`에서 core 반경 내부 에너지는 전체 component의 10% 이하
- local halo의 red-channel 반경이 blue-channel 반경보다 최소 1.5배, local peak에서 `R/G ≥ 1.25`
- 넓은 global layer는 local peak의 35% 이하이면서 local 반경의 2.5배 이상까지 연속 감쇠
- Final에서 중성 highlight core의 chroma 이동 `ΔEITP ≤ 2` 또는 scene-linear neutral ratio 오차 2% 이하
- 동일 광원에서 밝은 배경의 halo 에너지가 어두운 배경보다 작고 parameter sweep 전체에서 불연속/popping 없음
- Amount 0 identity, HDR/negative/alpha, 해상도, CPU/Metal 기존 계약 유지
- 현재 공식 BRAW뿐 아니라 야간 practical, 역광 머리카락, saturated LED 세 장면에서 사용자 100% 확대 승인

### 5.2 Film Grain v2

#### 목표 모델

기존 Philox 결정성과 counter-based frame indexing은 유지합니다. noise generator를 버리는 것이 아니라 그 위의 film response를 교체합니다.

```text
scene linear
→ exposure/density coordinates
→ record별 film-resolution MTF
→ 노출별 RMS·diameter·clump curve
→ correlated R/G/B dye-cloud fields
→ 비대칭 density perturbation + saturation roll-off
→ 원 working space 복원
```

핵심 변경:

- 세 color record에 서로 다른 base diameter와 MTF
- `-8…+8 stop` 구간의 profile LUT로 RMS/size/clump 제어
- 완전 Gaussian이 아닌 제한된 비대칭 density distribution
- fine/medium/coarse grain population 혼합
- source image softness와 grain sharpness 분리
- black/white 끝점에서 hard clipping 없이 자연 감쇠

#### 파라미터 인터페이스

| 그룹 | ID | 표시명 | 범위 / 기본 | 역할 |
|---|---|---|---|---|
| Basic | `format` | Film Format | 8/16/35/65 계열 / 35 Fine | profile 선택 |
| Basic | `amount` | Amount | 0–200 / 28 | RMS scale |
| Basic | `size` | Grain Size | 25–400 / 100 | profile-relative diameter |
| Basic | `chroma` | Color Separation | 0–100 / 12 | record 독립성 |
| Structure | `film_resolution` | Film Resolution | 0–100 / 72 | 원본 MTF branch |
| Structure | `clump` | Clumping | 0–100 / 22 | coarse cluster 비중 |
| Structure | `softness` | Grain Softness | 0–100 / 28 | grain MTF |
| Exposure | `exposure_bias` | Exposure Bias | -4–4 stop / 0 | response curve 이동 |
| Exposure | `shadow` | Shadows | 0–200 / profile | 기존 ID 유지 |
| Exposure | `midtone` | Midtones | 0–200 / profile | 기존 ID 유지 |
| Exposure | `highlight` | Highlights | 0–200 / profile | 기존 ID 유지 |
| Motion | `seed` | Seed | 기존 범위 / 1337 | 결정적 변형 |

`Temporal Rate/Persistence`는 Must가 아닙니다. 필름 프레임의 입자는 매 frame 새로 나타나며 현재의 낮은 이웃 상관 계약이 맞습니다. 사용자가 의도적으로 느린 grain을 원할 때만 Could로 추가합니다.

#### 프리셋

- `8mm Coarse`
- `16mm Fine`
- `16mm Fast`
- `35mm Fine` (기본)
- `35mm Fast`
- `65mm Fine`

실측 stock 자료 없이 Kodak/Fujifilm 상품명을 preset 이름으로 사용하지 않습니다.

#### 합격 기준

- 동일 seed/frame/settings CPU 재렌더 bit-exact, Metal 최대 오차 `2e-4`
- 임의 frame 순서 `10, 2, 10, 9, 2`에서 같은 frame 결과 일치
- 인접 frame correlation 절댓값 `<0.1`, 96-frame 평균 bias `<5e-4 stop`
- -8…+8 stop flat field에서 각 profile의 RMS curve가 저장된 golden envelope ±7% 이내
- R/G/B covariance와 각 record PSD가 profile envelope ±1.5dB 이내
- 1080/4K/8K의 canonical diameter 오차 8% 이하, radial PSD median 차이 1.5dB 이하
- 강한 Amount에서도 RGB single-pixel sparkle, 반복 격자 peak, 8-bit viewer banding이 없음
- 피부, 하늘, 암부, 흰 벽을 포함한 100% 확대 정상 재생에서 사용자 승인

### 5.3 Mist Diffusion v2

#### 목표 모델

```text
scene-linear highlight source ─→ local glow PSF ┐
scene-linear full image ───────→ broad veil PSF ├→ mode/density response → composite
perceptual image ──────────────→ frequency detail┘
```

세 branch를 반드시 분리합니다.

1. `Glow`: highlight 주변의 국소 flare
2. `Veil`: 저주파 contrast와 black floor 변화
3. `Detail`: 피부의 미세 고주파를 완화하되 눈·머리카락 중간 주파수 edge acuity 유지

Black/White는 같은 식의 상수 차이가 아니라 서로 다른 calibrated response profile입니다.

- Black: 낮은 veil, 높은 black retention, 절제된 glow, 미세 detail 완화
- White: 넓은 white glow, 더 큰 veil과 contrast 감소, 더 강한 skin softness

#### 파라미터 인터페이스

| 그룹 | ID | 표시명 | 범위 / 기본 | 역할 |
|---|---|---|---|---|
| Basic | `mode` | Filter Type | Black/White / Black | profile family |
| Basic | `density` | Density | 1/8,1/4,1/2,1,2 / 1/8 | 비선형 profile 단계 |
| Basic | `diffusion` | Diffusion | 0–100 / profile | detail+veil 총 성격 |
| Basic | `bloom` | Highlight Glow | 0–100 / profile | local glow energy |
| Tone | `contrast` | Contrast Reduction | 0–100 / profile | local/global contrast |
| Tone | `black_retention` | Black Retention | 0–100 / mode profile | shadow floor 보호 |
| Detail | `texture` | Detail Retention | 0–100 / profile | 기존 ID, label 변경 |
| Highlight | `highlight_limit` | Highlight Limit | -2–8 stop / 1.5 | glow source |
| Highlight | `glow_tail` | Glow Tail | 0–100 / profile | PSF wide lobe |
| Color | `bloom_saturation` | Bloom Saturation | 0–100 / 85 | 색 보존/탈색 |

#### 프리셋

`Black 1/8…2`, `White 1/8…2`를 유지하되 각 density는 단순 선형 배수가 아닌 profile curve입니다. `Portrait Black 1/4`, `Atmosphere White 1/2`는 Should preset입니다.

#### 합격 기준

- 같은 density에서 White veil energy > Black veil energy, White shadow lift는 Black의 최소 1.7배
- Black 1/8의 2% gray patch lift는 입력 대비 2% 이하, Black 1도 8% 이하
- density 증가에 따라 glow 반경·energy·contrast 감소가 각각 단조 증가하며 preset 경계에서 jump 없음
- slanted-edge MTF에서 Black 기본은 0.1 cyc/px 85% 이상, White 기본은 75% 이상 유지
- skin high-frequency band는 감소하지만 eye/hair edge의 중간 주파수 energy는 기본 preset에서 80% 이상 유지
- neutral mode skin patch hue 이동 `ΔEITP ≤ 2`; Warm preset만 예외
- `Glow Only`, `Veil Only`, `Detail Difference`, `Source Mask`의 합이 Final과 수치적으로 일치
- UHD Metal median 83.33ms 이하. 현재 121.61ms이므로 품질 개선 전에 pyramid 경로로 성능 debt를 먼저 해소

### 5.4 Lens Reflections v2

#### 목표 모델

```text
source isolation
→ morphology + connected source regions/energy tiles
→ optical-center geometry
→ profile-defined ghost elements
→ aperture/ring/distortion/chromatic PSF per element
→ background-aware compositing + veil
```

초기 Metal 구현에서 완전한 connected-component tracker가 너무 비싸면 `energy tile pyramid + local maxima`로 source를 최대 8개까지 추출합니다. 각 source는 centroid, radius, energy, mean color를 갖고 frame마다 독립 계산합니다. 시간 smoothing으로 source를 추적하면 random seek 결정성이 깨질 수 있으므로 Must에서는 **동일 frame의 결과가 과거 frame 순서에 의존하지 않는 spatial detector**를 사용합니다. temporal hysteresis는 Could입니다.

각 lens profile은 element 배열을 내부 데이터로 소유합니다.

```text
GhostElement {
  axis_position, magnification, aperture_shape,
  ring_profile, blur, radial_distortion,
  spectral_tint, dispersion, energy, background_falloff
}
```

사용자에게 element 수십 개를 그대로 노출하지 않습니다. 작은 profile/amount/spread 인터페이스 뒤에 복잡성을 숨겨 depth와 leverage를 만듭니다.

#### 파라미터 인터페이스

| 그룹 | ID | 표시명 | 범위 / 기본 | 역할 |
|---|---|---|---|---|
| Basic | `lens_model` | Lens Profile | Clean/Vintage/Anamorphic / Clean | element set |
| Basic | `amount` | Global Brightness | 0–200 / 12 | 전체 에너지 |
| Basic | `threshold` | Source Brightness | -2–8 stop / 3 | source limiter |
| Basic | `spread` | Element Spread | 0–200 / 65 | 광축 위치 scale |
| Source | `source_gamma` | Source Gamma | 0.25–4 / 1 | source energy 압축 |
| Source | `source_smoothness` | Source Smoothness | 0–100 / 50 | threshold knee |
| Source | `source_morphology` | Source Morphology | -100–100 / 0 | 작은 광원 erode/dilate |
| Source | `source_color_mode` | Source Color | Preserve/Neutral/Tint / Preserve | element 입력색 |
| Lens | `center_x`,`center_y` | Optical Center X/Y | -100–100 / 0 | 광축 pivot |
| Lens | `blur` | Global Blur | 0–3 %H / 0.3 | element focus |
| Lens | `anamorphism` | Anamorphism | 0.5–3 / profile | ovality |
| Lens | `chroma` | Dispersion | 0–100 / profile | wavelength separation |
| Composite | `background_adaptation` | Background Adaptation | 0–100 / 65 | 밝은 배경에서 sticker 억제 |
| Composite | `veil` | Veiling Glare | 0–100 / profile | 저주파 flare |

focal length/T-stop 숫자는 calibrated real-lens profile이 없으면 가짜 물리 제어가 됩니다. Must에서는 정규화된 Lens Profile과 element controls를 사용하고, 실측/공식 profile을 확보한 뒤 Should에서 실제 단위 control을 도입합니다.

#### 합격 기준

- 이동 point light sweep에서 모든 ghost centroid가 source–optical-center 선에서 1.5px 또는 frame diagonal 0.05% 이내
- source 위치가 1px 움직일 때 ghost 위치·energy가 연속적으로 변하고 frame-to-frame flash/popping 없음
- Elements Only에서 source의 흰 사각 실루엣이 불투명하게 그대로 복제되지 않음. 각 element는 aperture/ring/falloff profile을 가짐
- 동일 source의 밝은 배경 component energy가 어두운 배경보다 낮음
- 각 profile의 element energy 합은 profile budget ±3%, Final에서 비의도 clipping 증가율 0.1%p 이하
- neutral source에서 profile tint/dispersion이 지정 envelope 안에 있고, saturated source color mode가 정상 작동
- 화면 밖 source는 명시한 reach 안에서만 기여하고 반대 edge로 wrap하지 않음
- UHD Metal median 83.33ms 이하, temporary <256MiB

### 5.5 Optical Blur v2

#### 제품 범위 결정

Must는 **uniform defocus + field-dependent lens PSF**입니다. depth map 없이 초점 거리와 전경/배경 occlusion을 정확히 만들 수 없으므로 `Depth of Field`라고 부르지 않습니다.

다음은 v2 Must입니다.

- aperture blades/roundness/rotation/anamorphism
- center/rim brightness 분포
- field position에 따른 cat-eye와 energy normalization
- 약한 spherical aberration, coma/astigmatism, chromatic aberration
- highlight response와 일반 image response 분리

다음은 Should입니다.

- Resolve mask/second clip을 이용한 selective blur
- near/far 2-layer matte mode

다음은 Could입니다.

- 외부 depth map과 occlusion-aware splatting
- calibrated real-lens profile과 focal length/T-stop/focus distance

#### 파라미터 인터페이스

| 그룹 | ID | 표시명 | 범위 / 기본 | 역할 |
|---|---|---|---|---|
| Basic | `lens_profile` | Lens Profile | Clean/Portrait/Vintage/Anamorphic | PSF coefficient set |
| Basic | `blur` | Defocus | 0–4 %H / 0.15 | CoC radius |
| Basic | `highlight_response` | Highlight Gain | 0–200 / 15 | highlight PSF energy |
| Basic | `anamorphism` | Anamorphism | 0.5–3 / profile | ovality |
| Aperture | `blades` | Blades | 3–16 / 9 | 기존 ID |
| Aperture | `curvature` | Roundness | 0–100 / 90 | 기존 ID, label 개선 |
| Aperture | `rotation` | Rotation | -180–180° / 0 | 기존 ID |
| Character | `bokeh_bias` | Center / Rim | -100–100 / 0 | spherical aberration 근사 |
| Character | `cat_eye` | Cat-eye | 0–100 / profile | field aperture clipping |
| Character | `coma` | Coma | 0–100 / profile | field asymmetry |
| Character | `chromatic_aberration` | Chromatic Aberration | 0–100 / profile | channel별 PSF |
| Quality | `quality` | Quality | Preview/Balanced/Final | deterministic tap budget |

#### 구현 전략

- 작은 radius: full-resolution deterministic gather kernel
- 큰 radius: source mip prefilter + blue-noise stratified aperture samples
- Final: 128개 이상 고정 sample, Balanced: 64, Preview: 24. 동일 quality에서는 CPU/Metal sample sequence 공유
- screen tile별 field PSF coefficient를 계산하되 tile 경계는 interpolation해 seam 제거
- channel PSF energy를 각각 1로 normalize하고 highlight gain만 노출 변화 허용

#### 합격 기준

- 모든 field tile/channel의 PSF energy `1.0 ± 0.5%`
- aperture analytic mask IoU 0.97 이상
- center point와 corner point의 cat-eye axis ratio가 profile target ±5%, tile boundary centroid jump 0.25px 이하
- neutral edge의 chromatic centroid separation이 parameter 0에서 0.05px 이하, sweep에서 단조 증가
- constant field는 highlight gain 0에서 `1e-5` 이하로 보존
- 1080/4K/8K normalized second moment 오차 3% 이하
- Final quality에 반복 pattern, harsh polygon ring, double line, edge smear seam 없음
- UHD Metal median 83.33ms 이하, temporary <192MiB

## 6. 공통 UI와 프리셋 재설계

현재 `ParameterType`은 네 종류뿐이고 ([RenderCore.h](../../include/cbef/RenderCore.h), 40–61행), OFX adapter는 이를 순서대로 flat하게 정의합니다 ([CBEFFilmEffects.cpp](../../src/ofx/CBEFFilmEffects.cpp), 90–145행). premium 알고리즘을 그대로 펼치면 조절값이 15개 이상이 되어 인터페이스가 구현만큼 복잡한 얕은 모듈이 됩니다.

Must:

- 모든 효과의 첫 화면은 `Preset`, 3–5개 Basic control, `Mix`만 보이게 함
- `Source`, `Shape/Lens`, `Color`, `Advanced`, `Diagnostics` 그룹
- mode/profile에 해당하지 않는 control은 disable/secret 처리
- parameter hint에 단위뿐 아니라 결과 방향과 권장 작업 공간 표시
- diagnostic 선택 시 `Final이 아닌 진단 출력`임을 label로 명시
- stable parameter ID와 plugin major version 2

이를 위해 `ParameterDefinition`에 다음 metadata를 추가합니다.

```text
group_id, display_order, enabled_when, secret_when,
display_min/max, semantic_role, precision
```

OFX adapter는 이 metadata를 host parameter group/page와 동적 enabled state로 옮기는 얇은 adapter여야 합니다. 효과별 UI 규칙은 Effect Catalog에 둬 locality를 유지합니다.

프리셋은 `하나의 강도 묶음`이 아니라 내부 profile을 선택하고 Basic control을 자연스러운 값으로 설정해야 합니다. 특정 제조사/stock 이름은 측정 profile이 없으면 사용하지 않습니다.

## 7. CPU/Metal parity 전략

### 7.1 교체 순서

각 효과는 반드시 다음 순서로 진행합니다.

1. 물리/시각 계약과 synthetic fixture를 먼저 고정
2. typed plan과 CPU reference 구현
3. CPU model behavior + golden EXR 승인
4. Metal adapter 구현
5. parameter pairwise matrix CPU/Metal parity
6. 실제 Resolve Free 수동 QA
7. Metal performance/temporary memory gate

CPU와 Metal을 동시에 독립 구현하면 두 구현이 같은 단순화를 공유해도 테스트가 통과하는 문제가 생깁니다. 먼저 CPU가 **명세의 reference adapter**가 되어야 합니다.

### 7.2 현재 테스트에서 확대할 부분

현재 parity는 효과별 대표 설정 한두 개를 검사합니다. v2는 다음 matrix를 pairwise 조합으로 생성합니다.

- 모든 Working Mode
- 각 preset/profile
- 각 숫자 parameter의 min/default/strong/max
- odd size, non-zero data window, cropped render window, render scale 0.5/1/2
- straight/premultiplied/alpha 0/부분 alpha
- negative, neutral, >1 HDR, saturated RGB
- 모든 diagnostic view
- Preview/Balanced/Final quality

수치 gate:

- deterministic effect CPU/Metal linear max abs `≤2e-4`, mean abs `≤2e-5`
- 같은 quality의 PSF centroid `≤0.1px`, energy `≤0.5%`
- Grain same frame/seed max abs `≤2e-4`; CPU same-render bit exact
- identity는 기존대로 bit exact

Metal이 fast approximation을 쓰더라도 profile behavior gate를 함께 통과해야 합니다. 단순 pixel parity만 맞고 CPU reference 자체가 미학적으로 틀린 상태를 허용하지 않습니다.

## 8. 성능·메모리 위험과 대응

현재 M3 Pro 실측은 다음과 같습니다 ([최종 M7 performance](../evidence/v2-final-20260812/performance/m7-performance.md)).

| 효과 | UHD median | 임시 peak | 현재 상태 |
|---|---:|---:|---|
| Halation | 78.79ms | 530.8MB | 시간 한계에 근접 |
| Grain | 9.34ms | 109.2MB | 여유 있음 |
| Optical Blur | 30.02ms | 265.4MB | 중간 |
| Lens Reflections | 78.19ms | 663.6MB | 시간·메모리 한계 |
| Mist | 121.61ms | 663.6MB | 시간 실패 |

v2가 full-resolution pass를 그대로 추가하면 실패합니다. 따라서 성능은 마지막 최적화가 아니라 각 효과 설계의 Must입니다.

| 위험 | 대응 |
|---|---|
| multi-lobe wide blur 비용 | half/quarter/eighth-resolution pyramid, radius에 따라 level 선택 |
| full-frame RGBA32F scratch | R16F matte, RGBA16F scatter, scratch aliasing |
| Lens ghost마다 full warp+blur | source tile pyramid + destination gather + element batch kernel |
| 큰 aperture의 O(radius²) tap | mip-prefiltered fixed-budget stratified samples |
| runtime Metal source compile | `.metal` library 사전 빌드 및 pipeline cache |
| 매 frame allocation | command completion 연동 in-flight arena |
| CPU reference 과도한 시간 | 내부 multi-thread, 작은 golden fixture 중심; Metal이 실사용 adapter |

성능 완료 기준:

- 1080p 각 효과 median `≤41.67ms`
- UHD 각 효과 median `≤83.33ms`, Grain `≤41.67ms`
- 10 warm frames 이후 steady allocation delta `≤8MiB`
- UHD temporary 표의 효과별 budget 이하
- 다섯 효과 연쇄 실시간은 v2 완료 조건이 아니지만 4K 24fps deliver render가 안정적으로 끝나야 함

## 9. 품질 검증 체계

### 9.1 기준 릴

현재 한 개 BRAW 샷은 backlight/practical에는 좋지만 전체 품질 판단에는 부족합니다. 다음 fixture와 footage를 manifest로 고정합니다.

| 소스 | 검증 |
|---|---|
| -10…+10 stop neutral/RGB ramp | limiter, HDR, grain response, gamut |
| 흰 사각형·얇은 선·점광원 | Halation edge/core, Mist/PSF |
| 중앙→모서리→화면 밖 point-light animation | ghost path, cat-eye, temporal continuity |
| slanted edge·Siemens star·fine textile | MTF와 detail retention |
| 9개 노출×neutral/R/G/B flat fields | Grain RMS/PSD/covariance |
| point-light grid | Optical field PSF |
| skin + hair + eye + practical | Mist/halation/grain aesthetic |
| saturated blue/red LED | source color behavior |
| alpha checker/semi-transparent edge | spill과 premultiplication |
| 공식 BRAW/Log 실제 장면 5종 이상 | Resolve host와 최종 시각 승인 |

`fixtures/quality/manifest.json`은 원본 URL/라이선스, SHA-256, 해상도, frame, input transform, timeline space, output transform, crop을 기록합니다. 다운로드 재배포가 불명확한 camera original은 저장소에 넣지 않고 fetch 지침과 hash만 둡니다.

### 9.2 네 단계 gate

1. **Safety Gate**: identity, finite HDR, alpha, memory window, error contract
2. **Model Gate**: 위 효과별 PSF/MTF/RMS/geometry/energy 기준
3. **Parity Gate**: CPU/Metal, resolution, render scale, seek order
4. **Aesthetic Gate**: 실제 RAW/Log 100% 확대와 정상 재생, 사용자 blind A/B 승인

스크린샷 MAE는 Safety/host proof에만 사용하고 Aesthetic Gate의 합격 근거로 사용하지 않습니다.

### 9.3 시각 승인 방식

- 동일 frame의 `Baseline`, `Effect Only`, `Mask/Elements`, `Final`을 16-bit half EXR 또는 float capture로 저장
- 기본/강함/극단값을 분리하되 preset 승인은 기본값으로 수행
- 100% pixel view와 최종 시청 배율 둘 다 검토
- 최소 5개 실제 장면에서 같은 preset이 무너지지 않아야 함
- 가능하면 사용자가 보유한 상용 필터 결과와 이름을 가린 A/B를 시행하되, black-box 참고만 하고 pixel 복제나 내부 구현 추정은 하지 않음
- 합격 질문은 “효과가 보이는가”가 아니라 “광원/노출/배경이 바뀌어도 재료·렌즈의 같은 성격으로 보이는가”로 고정

## 10. 우선순위와 마일스톤

### Must: v2 출시 전 필수

- typed Effect Compiler, Color Pipeline, Optics Primitives, Frame Arena
- Basic/Advanced/Diagnostics UI grouping
- Halation local/global spectral 재설계
- Grain exposure/record/MTF profile 재설계
- Mist glow/veil/detail 및 Black/White 별도 profile
- Lens source isolation + element profiles + background adaptation
- Optical field PSF + cat-eye + 기본 수차
- 모든 효과 CPU reference와 Metal adapter
- UHD timing/memory, RAW/Log aesthetic gate

### Should: Must가 안정된 뒤 같은 v2 주기에서 권장

- ACEScct working mode
- Halation skin protection과 profile curve 확장
- Mist focal-context qualitative profile
- Lens manual optical center와 selective source controls
- Optical selective matte / near-far 2-layer
- 더 많은 legally usable reference footage

### Could: v2 완료를 막지 않음

- spectral 31-sample Halation
- Grain temporal rate/persistence
- connected-component temporal tracking
- real-lens calibrated focal length/T-stop controls
- external depth map DOF
- profile import/editor

### 구현 마일스톤

| 순서 | 산출물 | 완료 조건 |
|---|---|---|
| P0 | v2 quality contract + fixture manifest | 모든 model gate가 실패 상태로 재현되고 기준 릴 준비 |
| P1 | 공통 deep modules와 UI metadata | v1 safety/parity regression green, effect별 typed plan 사용 |
| P2 | Halation v2 | 흰 bloom 문제 해결, local/global/spectral gate와 RAW 승인 |
| P3 | Mist v2 + shared scatter pyramid | Black/White 구분, UHD 83.33ms, skin/MTF 승인 |
| P4 | Grain v2 | 노출별 RMS/PSD/record gate와 시간 결정성 승인 |
| P5 | Lens Reflections v2 | white sticker 제거, source sweep/element/배경 gate 승인 |
| P6 | Optical Blur v2 | field PSF/cat-eye/aberration gate 승인 |
| P7 | preset tuning + 통합 Resolve QA | 다섯 기본 preset blind review 및 4K deliver 완료 |

Halation과 Mist를 먼저 하는 이유는 사용자가 이미 품질 결함을 확인했고, 두 효과가 source isolation과 multi-scale scatter를 공유해 P2의 구현이 P3에 높은 leverage를 제공하기 때문입니다. Grain은 현재 기반이 가장 강하고 성능 여유가 있어 세 번째입니다. Lens Reflections는 source/element 모델을 새로 만들 범위가 크며, Optical Blur의 field PSF와 aperture primitive를 재사용할 수 있도록 P5/P6를 연속 배치합니다.

## 11. 파일별 예상 수정 범위

| 기존 파일 | 수정 범위 |
|---|---|
| `include/cbef/RenderCore.h` | 외부 render seam 유지. UI metadata/typed compile 결과의 public 노출은 최소화 |
| `src/core/RenderCore.cpp` | catalog, compiler, color, effect model, CPU adapter로 분해. effect-specific render 함수 제거 |
| `src/core/RenderPlan.h` | all-effects struct 제거, typed variant plan으로 교체 |
| `src/metal/MetalRenderBackend.mm` | shader raw string 제거, arena/pipeline orchestration만 유지 |
| `src/ofx/CBEFFilmEffects.cpp` | group/page/enabled metadata adapter, v2 version, richer help text |
| `tests/*_render_contract.mm` | 기존 safety 계약 유지, v2 model/parity matrix로 교체·확장 |
| `tests/m7_performance_benchmark.mm` | quality mode, per-effect scratch budget, 8K correctness case 추가 |
| `docs/PLAN.md`, `README.md`, `CONTEXT.md` | v2 알고리즘·권장 노드 순서·작업 공간·제한 갱신 |

예상 규모는 “몇 개 상수 조정”이 아니라 내부 렌더 구조와 다섯 알고리즘을 교체하는 대형 변경입니다. 구현은 각 P 단계별로 CPU reference → Metal → Resolve QA를 끝낸 뒤 다음 효과로 넘어가야 합니다. 다섯 효과를 한꺼번에 수정하고 마지막에 비교하면 원인 locality와 시각 승인 이력이 사라집니다.

## 12. 최종 완료 정의

v2는 다음 조건을 모두 만족해야 완료입니다.

- 현재 사용자가 지적한 Halation의 따뜻한 흰 bloom이 red-orange local halo + wide glare 구조로 교체됨
- Lens Reflections에서 흰 광원 실루엣 복제/sticker 현상이 사라짐
- Film Grain이 exposure zone과 color record에 따라 구조적으로 달라짐
- Black/White Mist가 highlight, veil, black retention, detail MTF 모두에서 구분됨
- Optical Blur가 중앙/모서리에서 다른 field PSF와 자연스러운 lens character를 가짐
- 모든 Basic control이 직관적이며 복잡한 profile 구현은 Advanced 뒤에 숨겨짐
- CPU/Metal, 1080/4K/8K, render scale, alpha/HDR/negative, seek order gate 통과
- M3 Pro의 UHD 개별 효과 성능·메모리 budget 통과
- Resolve Free에서 공식 RAW/Log 기준 릴의 기본 preset이 정상 속도와 100% 확대 모두 사용자 승인을 받음

이 완료 정의를 통과하기 전에는 `유료급`, `필름 에뮬레이션`, `실제 렌즈 프로파일` 같은 표현을 제품 설명에 사용하지 않습니다. 그 전 단계의 정확한 표현은 `v2 물리 반응 기반 필름·광학 효과`입니다.
