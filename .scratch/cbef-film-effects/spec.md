# CBEF Film Effects 구현 명세

Status: ready-for-agent

## Problem Statement

DaVinci Resolve 무료판 사용자는 Studio 전용 기능, DCTL 또는 Fusion 매크로에 의존하지 않고도 자연스러운 필름 광학·질감 효과를 적용하고 싶습니다. 현재 개인 작업 환경에는 할레이션, 필름 그레인, 광학 블러, 렌즈 반사, Black·White 미스트 확산을 하나의 일관된 색 처리와 사용 방식으로 제공하는 설치형 효과 모음이 없습니다.

제품은 Apple M3 Pro와 macOS 26에서 실행되는 DaVinci Resolve 무료판 21용 개인용 macOS 빌드여야 합니다. 한 번 설치하면 다섯 효과가 독립적으로 나타나야 하며, 카메라 Log 변환은 Resolve가 담당해야 합니다. 구현자가 추가 제품 결정을 내리지 않고 작업하려면 프레임 렌더 계약, CPU·Metal 완료 의미, 색 인코딩 기준, 파라미터와 프리셋의 단일 정의, 필름 그레인의 결정성, 효과별 자동 판정치, 실제 Resolve 무료판 수동 승인 절차가 하나의 명세로 고정되어야 합니다.

## Solution

CBEF Film Effects는 Apple Silicon arm64용 네이티브 OpenFX 번들 하나로 빌드합니다. 번들은 다음 다섯 설치형 효과를 독립적인 effect ID로 등록합니다.

1. CBEF Halation
2. CBEF Film Grain
3. CBEF Optical Blur
4. CBEF Lens Reflections
5. CBEF Mist Diffusion

OFX Adapter Module은 Resolve의 플러그인 수명주기, 파라미터, 호스트 표면, 프레임 시간, render scale, premultiplication 정보와 Metal 명령 큐를 다룹니다. Render Core Module은 효과 정의와 기본값, 프리셋 확장, 색 변환, 알파 처리, 효과 수학, 패스 구성과 identity 판정을 소유합니다.

자동 검증은 Headless Render Contract 하나만 사용합니다. 완전히 해석된 렌더 요청과 CPU 또는 Metal RenderBackend를 입력받아 Completed, Enqueued 또는 Failed 상태와 목적 프레임을 관찰합니다. 내부 패스, 블러 함수, 난수 함수와 Metal kernel을 별도 테스트 seam으로 노출하지 않습니다.

실제 호스트 통합과 지각 품질은 Resolve Free Host Acceptance 하나로 확인합니다. 가짜 OFX 호스트는 만들지 않습니다. 설치·검색·Edit/Color 적용·Inspector·캐시·탐색·재생·실제 fps·기준 릴의 자연스러운 품질은 실제 Resolve 무료판에서만 승인합니다.

## User Stories

1. Apple Silicon Mac 사용자로서, 하나의 번들로 다섯 효과를 설치하고 싶습니다. 그래야 설치와 업데이트를 한 단위로 관리할 수 있습니다.
2. Resolve 무료판 사용자로서, 다섯 효과를 효과 목록에서 각각 찾고 싶습니다. 그래야 필요한 시네마 마감 효과만 선택할 수 있습니다.
3. 컬러리스트로서, 각 효과를 독립 노드에 배치하고 싶습니다. 그래야 장면마다 처리 순서를 바꿀 수 있습니다.
4. Resolve 무료판 사용자로서, Studio 라이선스 없이 모든 효과를 미리 보고 싶습니다. 그래야 개인 작업에 추가 구독이 필요하지 않습니다.
5. Resolve 무료판 사용자로서, 워터마크 없이 효과가 적용된 영상을 렌더하고 싶습니다. 그래야 결과물을 실제 프로젝트에 사용할 수 있습니다.
6. 개인 사용자로서, DCTL이나 Fusion 매크로를 별도로 설치하지 않고 싶습니다. 그래야 하나의 일반적인 설치형 효과처럼 사용할 수 있습니다.
7. 편집자로서, Edit 페이지의 클립에 각 효과를 적용하고 싶습니다. 그래야 편집 흐름을 떠나지 않고 룩을 시험할 수 있습니다.
8. 컬러리스트로서, Color 페이지의 노드에 각 효과를 적용하고 싶습니다. 그래야 기존 그레이딩 파이프라인에 효과를 배치할 수 있습니다.
9. Log 촬영 사용자로서, 카메라 Log 변환을 Resolve Color Management 또는 CST에 맡기고 싶습니다. 그래야 플러그인에서 카메라별 변환을 중복하지 않습니다.
10. 컬러리스트로서, 실제 노드 입력과 일치하는 Working Mode를 선택하고 싶습니다. 그래야 장면 기준 빛 처리가 올바르게 동작합니다.
11. DWG / Intermediate 사용자로서, 이 인코딩을 직접 선택하고 싶습니다. 그래야 일반적인 Resolve 광색역 작업 흐름에서 효과를 사용할 수 있습니다.
12. DWG / Linear 사용자로서, 선형 입력을 직접 선택하고 싶습니다. 그래야 불필요한 transfer 왕복을 피할 수 있습니다.
13. Rec.709 / Gamma 2.4 사용자로서, 이 작업 공간을 직접 선택하고 싶습니다. 그래야 단순 Rec.709 프로젝트에서도 예측 가능한 결과를 얻습니다.
14. 처음 사용하는 사용자로서, Working Mode가 자동 추정되지 않는다는 안내를 보고 싶습니다. 그래야 잘못된 색 설정을 스스로 교정할 수 있습니다.
15. 사용자로서, 효과 강도나 Mix를 0으로 만들면 원본을 얻고 싶습니다. 그래야 효과를 안전하게 우회하거나 애니메이션할 수 있습니다.
16. 룩 개발 사용자로서, Final 결과뿐 아니라 효과 성분과 선택 매트를 보고 싶습니다. 그래야 Threshold와 반응 범위를 진단할 수 있습니다.
17. 편집자로서, 숫자 파라미터에 키프레임을 적용하고 싶습니다. 그래야 장면 안에서 효과를 변화시킬 수 있습니다.
18. 사용자로서, Reset을 누르면 자연스러운 기본값으로 돌아가고 싶습니다. 그래야 실험 후 안전한 시작점으로 복귀할 수 있습니다.
19. 사용자로서, 프리셋을 선택하면 정확히 정의된 파라미터 집합을 적용하고 싶습니다. 그래야 반복 가능한 룩을 만들 수 있습니다.
20. 사용자로서, 프리셋 적용 후 값을 바꾸면 Custom 표시를 보고 싶습니다. 그래야 저장된 프리셋과 현재 설정을 구분할 수 있습니다.
21. 컬러리스트로서, 프리셋을 바꿔도 Working Mode, Output View와 Mix가 유지되길 원합니다. 그래야 진단과 합성 설정을 잃지 않습니다.
22. HDR 작업 사용자로서, 음수 RGB가 임의로 0에 잘리지 않길 원합니다. 그래야 색변환의 유효한 signed 성분을 보존할 수 있습니다.
23. HDR 작업 사용자로서, 1.0 초과 RGB가 임의로 잘리지 않길 원합니다. 그래야 장면의 하이라이트 여유를 유지할 수 있습니다.
24. 알파 영상 사용자로서, straight-alpha 입력의 알파가 바뀌지 않길 원합니다. 그래야 합성 경계를 유지할 수 있습니다.
25. 알파 영상 사용자로서, premultiplied-alpha 투명 경계의 숨은 RGB가 번지지 않길 원합니다. 그래야 컬러 프린지 없이 합성할 수 있습니다.
26. 알파 영상 사용자로서, 완전히 투명한 영역에 새로운 방사광이나 그레인이 생기지 않길 원합니다. 그래야 투명 픽셀에서 오염이 발생하지 않습니다.
27. 프록시 사용자로서, 1080p·4K·프록시에서 효과 반경이 비슷하게 보이길 원합니다. 그래야 해상도를 바꿔도 룩이 유지됩니다.
28. 사용자로서, 프레임 가장자리에서 잘린 halo, blur seam 또는 반복 grain을 보지 않길 원합니다. 그래야 전체 프레임이 자연스럽게 보입니다.
29. 할레이션 사용자로서, 밝은 경계 주변에 얇고 따뜻한 번짐을 얻고 싶습니다. 그래야 전체 화면 글로우가 아닌 필름 같은 반응을 얻습니다.
30. 할레이션 사용자로서, 분리된 붉은 외곽선을 보지 않길 원합니다. 그래야 효과가 합성 티처럼 보이지 않습니다.
31. 할레이션 사용자로서, Amount·Radius·Threshold·Highlights Only·Warmth·Saturation을 조절하고 싶습니다. 그래야 장면별 하이라이트 반응을 맞출 수 있습니다.
32. 필름 그레인 사용자로서, 기본값에서 과하게 튀지 않는 미세한 입자를 얻고 싶습니다. 그래야 정상 속도 재생에서 자연스러운 질감이 됩니다.
33. 필름 그레인 사용자로서, 같은 프레임·Seed·설정을 다시 렌더하면 같은 패턴을 얻고 싶습니다. 그래야 캐시와 최종 렌더가 재현됩니다.
34. 필름 그레인 사용자로서, 다음 출력 프레임에서는 새로운 패턴을 얻고 싶습니다. 그래야 고정 노이즈처럼 보이지 않습니다.
35. 리타임 사용자로서, 같은 출력 프레임에 속하는 서브프레임 샘플은 같은 패턴을 얻고 싶습니다. 그래야 모션 샘플링 중 그레인이 흔들리지 않습니다.
36. 필름 그레인 사용자로서, 포맷·양·크기·부드러움·색 입자·명암별 반응을 조절하고 싶습니다. 그래야 촬영물에 맞는 입자 특성을 만들 수 있습니다.
37. 필름 그레인 사용자로서, 16mm·35mm Fine·35mm Fast·65mm Fine 프리셋을 사용하고 싶습니다. 그래야 필름 규격별 시작점을 빠르게 선택할 수 있습니다.
38. 필름 그레인 사용자로서, 격자·줄무늬·반복 텍스처·프레임 밝기 맥동을 보지 않길 원합니다. 그래야 절차적 입자가 합성 노이즈처럼 보이지 않습니다.
39. 광학 블러 사용자로서, 깊이 지도 없이 전체 프레임에 조리개 모양 블러를 적용하고 싶습니다. 그래야 Resolve 윈도우와 키로 적용 영역을 직접 정할 수 있습니다.
40. 광학 블러 사용자로서, Blades·Curvature·Rotation·Anamorphism을 조절하고 싶습니다. 그래야 렌즈 특성을 디자인할 수 있습니다.
41. 광학 블러 사용자로서, Blur가 0이면 원본을 얻고 싶습니다. 그래야 효과를 정확하게 우회할 수 있습니다.
42. 광학 블러 사용자로서, 일정한 밝기 영역에서 의도하지 않은 노출 변화를 보지 않길 원합니다. 그래야 블러가 영상의 에너지를 보존합니다.
43. 렌즈 반사 사용자로서, 현재 프레임의 실제 하이라이트 모양과 색을 이용한 ghost를 얻고 싶습니다. 그래야 고정 플레어 이미지보다 장면에 반응하는 결과가 됩니다.
44. 렌즈 반사 사용자로서, 고정된 flare bitmap이 얹힌 결과를 보지 않길 원합니다. 그래야 카메라 움직임과 광원 변화에 자연스럽게 반응합니다.
45. 렌즈 반사 사용자로서, 여러 광원이 각자의 광축 관계에 따라 ghost에 기여하길 원합니다. 그래야 복잡한 야간 장면도 자연스럽게 처리됩니다.
46. 렌즈 반사 사용자로서, 광원이 threshold를 통과할 때 ghost가 갑자기 튀지 않길 원합니다. 그래야 움직이는 광원에서 popping이 없습니다.
47. 렌즈 반사 사용자로서, Clean Prime·Vintage Prime·Anamorphic 프리셋을 사용하고 싶습니다. 그래야 서로 다른 렌즈 반사 성격을 빠르게 선택할 수 있습니다.
48. 미스트 확산 사용자로서, Black 또는 White 모드를 선택하고 싶습니다. 그래야 대비와 번짐 성격을 구분할 수 있습니다.
49. 미스트 확산 사용자로서, 1/8·1/4·1/2·1 밀도를 선택하고 싶습니다. 그래야 필터 밀도에 대응하는 단계적 강도를 얻을 수 있습니다.
50. Black 모드 사용자로서, 암부 상승과 넓은 flare가 상대적으로 억제되길 원합니다. 그래야 피부와 암부 세부를 유지할 수 있습니다.
51. White 모드 사용자로서, 더 넓은 diffusion과 더 큰 대비 감소를 얻고 싶습니다. 그래야 부드럽고 파스텔 같은 분위기를 만들 수 있습니다.
52. 미스트 확산 사용자로서, 세부 질감 보존량을 조절하고 싶습니다. 그래야 부드러움과 디테일 사이를 맞출 수 있습니다.
53. 사용자로서, CPU 기준 출력과 허용 오차 안에서 같은 Metal 출력을 얻고 싶습니다. 그래야 테스트와 실제 재생 결과가 일치합니다.
54. Resolve 사용자로서, Metal backend가 호스트 명령 큐를 불필요하게 기다리지 않길 원합니다. 그래야 미리보기 성능을 유지할 수 있습니다.
55. M3 Pro 사용자로서, 각 효과의 기본 프리셋이 정해진 성능 목표를 충족하길 원합니다. 그래야 실제 편집과 그레이딩에 사용할 수 있습니다.
56. 개발자로서, 각 효과를 독립적으로 검증하고 싶습니다. 그래야 다섯 효과 동시 실시간 성능을 첫 버전의 장애물로 만들지 않습니다.
57. 사용자로서, 피부·창문 하이라이트·전구·네온·역광 머리카락·미세 질감이 포함된 기준 릴을 확인하고 싶습니다. 그래야 다양한 장면에서 자연스러움을 판단할 수 있습니다.
58. 타이틀 작업 사용자로서, 흰 자막과 그래픽의 halo·flare·색 번짐을 확인하고 싶습니다. 그래야 고대비 그래픽의 결함을 발견할 수 있습니다.
59. 렌즈 반사 사용자로서, 단일·다중·화면 밖 광원에 대한 반응을 확인하고 싶습니다. 그래야 광원 배치에 따른 오류를 발견할 수 있습니다.
60. 유지보수자로서, 플러그인 버전과 동일한 설정으로 자동 테스트와 Resolve 수동 QA를 재현하고 싶습니다. 그래야 이후 변경의 회귀를 판단할 수 있습니다.

## Implementation Decisions

### 모듈과 seam

- OFX Adapter Module은 효과 등록, 호스트 파라미터 변환, clip fetch, 프레임 시간, render scale, alpha metadata, render window와 Metal 명령 큐를 소유합니다.
- Render Core Module은 다섯 효과의 Effect Definition, 기본값, 프리셋 확장, 색 변환, 알파 처리, 패스 구성과 identity 판정을 소유합니다.
- CPU RenderBackend와 Metal RenderBackend는 같은 RenderBackend interface를 만족하는 실제 adapter입니다.
- 자동 검증은 Headless Render Contract 하나만 사용합니다.
- 실제 호스트 검증은 Resolve Free Host Acceptance 하나만 사용합니다.
- 효과 내부 blur, matte, random field와 ghost pass는 Render Core 구현에 숨깁니다.
- OFX Adapter는 파라미터 기본값이나 프리셋 숫자를 복제하지 않고 Render Core의 Effect Definition을 읽습니다.

번들·효과 식별자는 첫 공개되지 않은 개인용 빌드부터 안정적으로 유지합니다.

| 항목 | 값 |
|---|---|
| Bundle display name | CBEF Film Effects |
| Bundle identifier | com.cbef.filmeffects |
| Vendor | CBEF |
| Effect group | CBEF Film Effects |
| Halation effect ID | com.cbef.filmeffects.halation |
| Film Grain effect ID | com.cbef.filmeffects.filmgrain |
| Optical Blur effect ID | com.cbef.filmeffects.opticalblur |
| Lens Reflections effect ID | com.cbef.filmeffects.lensreflections |
| Mist Diffusion effect ID | com.cbef.filmeffects.mistdiffusion |
| Initial effect version | 1.0 |

각 효과는 OpenFX Filter context, float32 RGBA source/output을 선언합니다. Metal을 사용할 수 있으면 Metal RenderBackend를 선택하고, 그렇지 않으면 같은 계약을 구현한 CPU RenderBackend를 사용합니다.

### RenderRequest와 FrameSurface 계약

| 항목 | 계약 |
|---|---|
| Effect ID | 다섯 효과 중 정확히 하나 |
| Source surface | 읽기 전용 native-endian interleaved float32 RGBA |
| Destination surface | render window 안에서만 쓰는 native-endian interleaved float32 RGBA |
| Channel order | R, G, B, A |
| Render window | [x1, x2) × [y1, y2) 반개구간 |
| Frame time | OFX frame 단위의 유한 double |
| Render scale | 0보다 큰 유한 x/y scale |
| Working Mode | 지원하는 세 enum 중 하나 |
| Alpha association | Straight 또는 Premultiplied |
| Settings | Effect ID와 정확히 일치하는 typed settings |
| Output View | 효과별 정의된 enum |

- 모든 setting은 유한값이고 정의된 범위 안에 있어야 합니다. 잘못된 값을 몰래 clamp하지 않고 오류를 반환합니다.
- row stride는 byte 단위이며 width × 16 이상이고 4의 배수여야 합니다.
- data window는 정수 origin과 양수 width/height를 갖습니다.
- source와 destination data window는 같아야 합니다.
- render window는 destination data window 안에 완전히 포함되어야 합니다.
- source와 destination 메모리는 전체 또는 일부가 겹치면 안 됩니다. alias를 발견하면 렌더를 시작하지 않고 오류를 반환합니다.
- caller가 source, destination과 Metal 명령 큐를 소유합니다.
- CPU backend는 반환 시 destination을 읽을 수 있게 합니다.
- Metal backend에서는 명령 큐 완료 전 destination을 읽거나 해제하면 안 됩니다.
- backend가 임시 표면을 소유하고 완료 시점까지 유지합니다.
- render window 밖 destination byte는 바꾸지 않습니다.
- CPU surface는 base pointer와 stride를 사용합니다.
- Metal surface는 MTLBuffer, byte offset과 stride를 사용합니다.
- 알파는 색 transfer function의 영향을 받지 않습니다.

### Sampling과 edge

- Halation, Optical Blur와 Mist Diffusion의 공간 sampling은 data window edge에 clamp합니다.
- Lens Reflections의 transformed sample이 data window 밖이면 transparent black으로 처리합니다.
- Film Grain field는 프레임 밖까지 정의된 무한 절차 field이므로 edge extension을 사용하지 않습니다.
- 모든 공간 radius는 현재 출력 프레임 높이의 백분율입니다.
- 비정방 render scale에서는 x/y physical radius가 같아 보이도록 각 축 render scale을 적용합니다.

### Alpha 계약

- Final identity predicate는 색 decode, unpremultiply, alpha normalization과 효과 계산보다 먼저 평가합니다.
- Final에서 identity가 참이면 OFX Adapter는 가능한 경우 host identity를 반환합니다.
- Headless Render Contract의 identity 경로는 render window 안 source RGBA float bit pattern을 destination 대응 float에 그대로 복사합니다. source와 destination stride가 달라도 RGBA bit pattern은 같아야 하며 render window 밖 destination byte는 유지합니다.
- Identity 경로에서는 straight alpha 0의 hidden RGB를 0으로 만들지 않고 NaN·Inf 검사나 색 변환도 하지 않습니다.
- 비-identity 경로에서만 Straight 입력을 straight RGB로 처리합니다.
- 비-identity Premultiplied 입력은 alpha가 1e-6보다 클 때 straight RGB로 복원합니다.
- alpha가 1e-6 이하인 픽셀은 효과 source에서 제외합니다.
- 공간 convolution은 alpha-weighted normalized sampling을 사용합니다.
- 비-identity Straight 출력에서 alpha가 1e-6 이하인 RGB는 0으로 정리합니다.
- Premultiplied 출력은 원래 alpha로 다시 premultiply합니다.
- 모든 비-identity view에서도 출력 alpha float bit pattern은 입력과 같습니다.
- 음수 RGB는 효과 방사 분석에서 제외하지만 signed base 성분으로 보존합니다.

### RenderSubmission과 오류

- Completed는 destination write가 CPU에서 완료되어 현재 thread에서 관찰 가능함을 뜻합니다.
- Enqueued는 모든 Metal encoder가 종료되고 모든 command buffer가 주입된 queue에 commit되었음을 뜻합니다. 함수는 GPU 완료를 기다리지 않습니다. 같은 queue에서 이후 제출한 barrier가 완료되면 destination을 읽을 수 있습니다.
- Failed에서는 destination을 유효 결과로 취급하지 않습니다.
- 오류 종류는 Unsupported Effect ID, Invalid Dimensions, Invalid Stride, Mismatched Surface Bounds, Invalid Render Window, Invalid Frame Time, Unsupported Pixel Format, Unsupported Working Mode, Settings Type Mismatch, Setting Out of Range, Non-finite Setting, Aliased Surfaces, Backend Unavailable, Temporary Allocation Failed, Pipeline Creation Failed, Command Encoding Failed로 고정합니다.
- 유한 source 픽셀이 입력되면 출력도 유한해야 합니다.
- NaN 또는 Inf source 픽셀의 동작은 첫 버전 계약 밖이며, 이를 위해 전체 프레임을 사전 검사하지 않습니다.

### Effect Definition의 단일 source of truth

각 Effect Definition은 stable parameter ID, label, 도움말, type, unit, range, increment, default, animatable 여부, choice option, preset expansion, identity predicate와 Output View 목록을 한곳에서 소유합니다.

- OFX Adapter, Headless Render Contract fixture와 사용자 문서는 동일한 Effect Definition을 읽습니다.
- 프리셋 선택은 효과별 파라미터만 바꿉니다.
- Working Mode, Output View와 Mix는 프리셋 선택으로 바뀌지 않습니다.
- 프리셋이 제어하는 파라미터를 사용자가 바꾸면 preset은 Custom으로 표시됩니다.

| ID | Type | Unit / Options | Min | Max | Default | Increment | Animatable |
|---|---|---|---:|---:|---:|---:|---|
| working_mode | Choice | DWG Intermediate, DWG Linear, Rec.709 Gamma 2.4 | — | — | DWG Intermediate | — | No |
| output_view | Choice | 효과별 정의 | — | — | Final | — | No |
| mix | Double | percent | 0 | 100 | 100 | 1 | Yes |
| preset | Choice | 효과별 preset + Custom | — | — | 효과별 기본 preset | — | No |

Host Reset은 기본 프리셋 확장, DWG Intermediate, Final, Mix 100을 복원합니다.

### Output View와 Mix 순서

1. 입력 RGB를 Working Mode에서 canonical linear DWG로 변환합니다.
2. 효과를 적용해 full effect result와 diagnostic 자료를 만듭니다.
3. Final일 때만 canonical linear DWG에서 original + (effected − original) × mix/100으로 혼합합니다.
4. 혼합 후 선택한 Working Mode로 encode합니다.
5. diagnostic Output View는 Mix를 무시합니다.
6. 효과 성분 view는 signed component를 선택한 Working Mode로 encode합니다.
7. matte view는 0~1 grayscale을 선택한 Working Mode로 encode합니다.
8. 모든 view에서 alpha는 입력과 같습니다.

Final이 아닐 때 OFX identity를 반환하지 않습니다.

모든 diagnostic 자료는 canonical linear DWG, straight RGB 상태에서 생성하고 Mix 적용 전에 고정합니다.

| 효과 / Output View | 정확한 표시값 |
|---|---|
| Halation Component | Warmth·Saturation·Amount까지 적용한 halo contribution, 즉 full Halation result에서 original을 뺀 signed RGB |
| Halation Highlight Matte | Highlights Only가 On이면 threshold knee matte, Off이면 Yanalysis가 0보다 크고 alpha가 1e-6보다 큰 픽셀은 1, 나머지는 0 |
| Grain Component | Amount·Format Strength·명암 반응·Chroma까지 적용한 Film Grain result에서 original을 뺀 signed RGB |
| Grain Luminance Response | Film Grain 식의 clamp(R/2, 0, 1)을 RGB 세 channel에 복제한 matte |
| Optical Blurred Image | aperture convolution까지 적용하고 Highlight Response는 더하지 않은 full RGB |
| Optical Highlight Component | highlight_response/100 × max(blur(highlight) − highlight, 0) |
| Lens Reflection Component | model·energy·tint·Chroma·Blur·Anamorphism·Amount까지 적용한 Reflection contribution |
| Lens Source Matte | threshold와 1-stop knee가 만든 source highlight matte |
| Mist Diffusion Component | Density·Mode·Diffusion·Bloom·Contrast·Texture까지 적용한 full Mist result에서 original을 뺀 signed RGB |
| Mist Highlight Matte | Mist bloom 계산에 사용한 smoothstep(1, 3, x) matte |

- Component view는 효과별 Amount 또는 Density factor 적용 후, 공통 Mix 적용 전 값입니다.
- Component view는 signed transfer로 Working Mode에 encode합니다.
- Matte view는 정의값을 0~1로 제한해 grayscale로 encode합니다.
- Optical Blurred Image는 component가 아닌 full-image view로 일반 Working Mode encode를 사용합니다.
- 모든 diagnostic view는 Mix를 무시하고 입력 alpha를 유지합니다.

### 색 처리 oracle

모든 효과의 canonical 내부 색공간은 linear DaVinci Wide Gamut, D65입니다.

DaVinci Wide Gamut의 CIE 1931 xy 좌표:

| 항목 | x | y |
|---|---:|---:|
| Red | 0.8000 | 0.3130 |
| Green | 0.1682 | 0.9877 |
| Blue | 0.0790 | -0.1155 |
| White | 0.3127 | 0.3290 |

Linear DWG RGB에서 XYZ D65로 가는 행렬:

|  |  |  |
|---:|---:|---:|
| 0.70062239 | 0.14877482 | 0.10105872 |
| 0.27411851 | 0.87363190 | -0.14775041 |
| -0.09896291 | -0.13789533 | 1.32591599 |

XYZ D65에서 linear DWG RGB로 가는 행렬:

|  |  |  |
|---:|---:|---:|
| 1.51667204 | -0.28147805 | -0.14696363 |
| -0.46491710 | 1.25142378 | 0.17488461 |
| 0.06484905 | 0.10913934 | 0.76141462 |

DWG / Intermediate는 A 0.0075, B 7.0, C 0.07329248, M 10.44426855, linear cut 0.00262409, encoded cut 0.02740668을 사용합니다.

- Linear L이 linear cut보다 크면 encoded V는 (log2(L + A) + B) × C입니다.
- 그 외에는 V = L × M입니다.
- Encoded V가 encoded cut보다 크면 L = 2^(V/C − B) − A입니다.
- 그 외에는 L = V/M입니다.
- cut 값에서는 선형 branch를 사용합니다.
- 음수 값은 선형 branch로 왕복합니다.

DWG / Linear의 transfer는 identity이며 DaVinci Wide Gamut 원색과 D65 white를 사용합니다.

Rec.709 / Gamma 2.4는 BT.1886 black-offset display model이 아니라 부호 보존 pure gamma 2.4 texture encoding으로 정의합니다.

- Decode는 sign(V) × abs(V)^2.4입니다.
- Encode는 sign(L) × abs(L)^(1/2.4)입니다.
- Rec.709 원색은 Red 0.6400/0.3300, Green 0.3000/0.6000, Blue 0.1500/0.0600, D65 White 0.3127/0.3290입니다.
- Linear Rec.709 RGB는 XYZ D65를 거쳐 canonical linear DWG로 변환하고 출력은 역순입니다.
- gamut clamp와 tone mapping은 하지 않습니다.

Linear Rec.709 RGB에서 XYZ D65로 가는 행렬:

|  |  |  |
|---:|---:|---:|
| 0.41239080 | 0.35758434 | 0.18048079 |
| 0.21263901 | 0.71516868 | 0.07219232 |
| 0.01933082 | 0.11919478 | 0.95053215 |

XYZ D65에서 linear Rec.709 RGB로 가는 행렬:

|  |  |  |
|---:|---:|---:|
| 3.24096994 | -1.53738318 | -0.49861076 |
| -0.96924364 | 1.87596750 | 0.04155506 |
| 0.05563008 | -0.20397696 | 1.05697151 |

- 음수 channel은 transfer와 matrix에서 부호를 보존합니다.
- 효과 방사에 사용할 positive image는 channel별 max(value, 0)입니다.
- signed negative residual은 효과 처리 후 다시 더합니다.
- 효과 분석용 luminance는 canonical linear DWG positive image에 DWG-to-XYZ 행렬의 Y row를 곱한 뒤 Yanalysis = max(Y, 0)으로 정의합니다. 이 clamp는 threshold, matte, luminance response와 contrast 계산에만 사용하며 출력 RGB, 원본 RGB, signed negative residual 또는 Final 합성 결과의 luminance에는 적용하지 않습니다.
- CPU encode/decode 왕복 최대 절대 오차는 2e-6입니다.
- Metal encode/decode 왕복 최대 절대 오차는 2e-5입니다.
- 전체 효과 CPU–Metal 최대 절대 오차는 2e-4입니다.

### CBEF Halation

| ID | Type | Unit | Min | Max | Default | Increment | Animatable |
|---|---|---|---:|---:|---:|---:|---|
| amount | Double | percent | 0 | 200 | 22 | 1 | Yes |
| radius | Double | frame-height percent | 0 | 5 | 0.65 | 0.05 | Yes |
| threshold | Double | stops over 18% | -2 | 8 | 2.0 | 0.1 | Yes |
| highlights_only | Boolean | on/off | — | — | On | — | No |
| warmth | Double | percent | 0 | 100 | 65 | 1 | Yes |
| saturation | Double | percent | 0 | 100 | 30 | 1 | Yes |

| Preset | Amount | Radius | Threshold | Highlights Only | Warmth | Saturation |
|---|---:|---:|---:|---|---:|---:|
| Subtle 35 | 22 | 0.65 | 2.0 | On | 65 | 30 |
| Warm Negative | 38 | 0.90 | 1.5 | On | 80 | 45 |
| Strong Edge | 70 | 1.25 | 1.0 | On | 70 | 55 |

- Output View는 Final, Halation Component, Highlight Matte입니다.
- Final에서 mix = 0 또는 amount = 0이면 identity입니다.
- threshold linear luminance는 0.18 × 2^threshold입니다.
- threshold knee는 고정 0.75 stop smoothstep입니다.
- Highlights Only가 꺼지면 positive image 전체를 source로 사용합니다.
- blur sigma는 radius의 0.35, 0.75, 1.5배이고 가중치는 0.50, 0.35, 0.15입니다.
- blurred highlight에서 원 highlight source를 빼고 양수 성분만 halo로 사용합니다.
- warmth 100의 목표 channel gain은 [1.0, 0.55, 0.20]이며 unit DWG luminance로 정규화합니다.
- warmth는 neutral gain과 목표 gain 사이, saturation은 halo luminance와 colored halo 사이를 보간합니다.
- halo를 amount/100 비율로 원본에 더합니다.

### CBEF Film Grain

| ID | Type | Unit / Options | Min | Max | Default | Increment | Animatable |
|---|---|---|---:|---:|---:|---:|---|
| format | Choice | 16mm, 35mm Fine, 35mm Fast, 65mm Fine | — | — | 35mm Fine | — | No |
| amount | Double | percent | 0 | 200 | 28 | 1 | Yes |
| size | Double | format-relative percent | 25 | 400 | 100 | 5 | Yes |
| softness | Double | percent | 0 | 100 | 28 | 1 | Yes |
| chroma | Double | percent | 0 | 100 | 12 | 1 | Yes |
| shadow | Double | percent | 0 | 200 | 40 | 1 | Yes |
| midtone | Double | percent | 0 | 200 | 100 | 1 | Yes |
| highlight | Double | percent | 0 | 200 | 25 | 1 | Yes |
| seed | Integer | integer | 0 | 2147483647 | 1337 | 1 | Yes |

| Format | 1080 높이의 기준 입자 지름 | Strength factor |
|---|---:|---:|
| 16mm | 1.80 px | 1.25 |
| 35mm Fine | 1.10 px | 1.00 |
| 35mm Fast | 1.40 px | 1.15 |
| 65mm Fine | 0.80 px | 0.75 |

| Preset | Format | Amount | Size | Softness | Chroma | Shadow | Midtone | Highlight | Seed |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 16mm | 16mm | 55 | 115 | 20 | 25 | 55 | 110 | 35 | 1337 |
| 35mm Fine | 35mm Fine | 28 | 100 | 28 | 12 | 40 | 100 | 25 | 1337 |
| 35mm Fast | 35mm Fast | 42 | 110 | 20 | 18 | 50 | 110 | 30 | 1337 |
| 65mm Fine | 65mm Fine | 18 | 90 | 35 | 8 | 30 | 90 | 20 | 1337 |

- Output View는 Final, Grain Component, Luminance Response입니다.
- Final에서 mix = 0 또는 amount = 0이면 identity입니다.

Frame index F는 양수 시간에서 floor(time + 0.5), 음수 시간에서 ceil(time − 0.5)로 계산합니다. 결과는 signed 64-bit 범위여야 하며 벗어나면 Invalid Frame Time으로 실패합니다. F는 two's-complement unsigned 64-bit bit pattern으로 해석합니다.

Philox4x32-10은 multiplier 0xD2511F53, 0xCD9E8D57과 Weyl increment 0x9E3779B9, 0xBB67AE85를 사용합니다. 한 round에서 M0×c0 = (hi0, lo0), M1×c2 = (hi1, lo1)일 때 새 counter는 (hi1 xor c1 xor k0, lo1, hi0 xor c3 xor k1, lo0)입니다. 첫 round는 입력 key를 사용하고 이후 각 round 전에 두 Weyl increment를 key에 더해 총 10 round를 실행합니다.

canonical lattice 좌표 ix와 iy는 signed 32-bit 정수이며 two's-complement bit pattern을 counter에 넣습니다.

- c0 = uint32_bits(ix)
- c1 = uint32_bits(iy)
- c2 = low32(uint64_bits(F))
- c3 = (layer_id << 24) | (octave_id << 16) | (channel_id << 8) | block_id
- k0 = uint32(seed)
- k1 = 0xCBEF2026 xor high32(uint64_bits(F))

layer_id는 shared field 0, independent field 1입니다. octave_id는 기준·2배·4배 octave에 각각 0, 1, 2입니다. shared field의 channel_id는 0, independent R/G/B field는 각각 1, 2, 3입니다.

lattice Gaussian 하나에는 block_id 0, 1, 2의 Philox 결과를 차례로 사용합니다. 각 결과 word 순서는 (r0, r1, r2, r3)이고 uniform 번호 j = 0…11은 block_id = floor(j/4), lane = j mod 4를 사용합니다. Uniform은 (word + 0.5)/2^32이고 Gaussian 근사는 12개 uniform의 합에서 6을 뺀 값입니다. 다른 word를 건너뛰거나 재사용하지 않습니다.

data window 높이를 H라 하고 픽셀 (x, y)의 canonical center를 X = (x − x1 + 0.5) × 1080/H, Y = (y − y1 + 0.5) × 1080/H로 정의합니다. Format 기준 지름을 Dformat이라 할 때 octave o의 canonical particle diameter는 Do = Dformat × (size/100) × 2^o이고 실제 출력 pixel 지름은 Do × H/1080입니다. lattice sampling 좌표는 (X/Do, Y/Do)입니다.

lattice interpolation은 각 축에 h(t) = t^2(3 − 2t)를 사용하는 separable C1 cubic interpolation입니다. Softness sigma는 octave별 canonical 단위로 0.75 × (softness/100) × Do이며 unit-sum Gaussian을 사용합니다. sigma가 0이면 convolution을 생략하고, 그 외에는 각 축 ceil(4 × sigma)까지 sampling합니다.

softened sample이 독립 unit-variance lattice 값 zj의 선형 결합 Σajzj이면 Σajzj / sqrt(Σaj^2)로 정규화합니다. 세 octave는 (0.65F0 + 0.25F1 + 0.10F2) / 0.703562363974로 혼합해 기대 RMS 1을 유지합니다.

x = log2(max(Yanalysis, 2^-16) / 0.18)일 때 WS = 1 − smoothstep(-5, -1, x), WH = smoothstep(1, 5, x), WM = max(0, 1 − max(WS, WH))입니다. R = (shadow × WS + midtone × WM + highlight × WH)/100으로 정의합니다. Format Strength factor를 Sf라 할 때 channel별 목표 log-exposure RMS는 sigma_stop = 0.08 × (amount/100) × Sf × R입니다. 기본 35mm Fine, 18% neutral에서는 R = 1이고 sigma_stop은 0.0224 stop입니다.

q = chroma/100, shared unit-RMS field를 Gs, 서로 독립인 channel field를 Gi,c라 하면 Gc = sqrt(1 − q) × Gs + sqrt(q) × Gi,c입니다. 각 channel의 기대 RMS는 1이고 서로 다른 channel의 기대 상관계수는 1 − q입니다. positive channel의 log exposure에 delta_c = sigma_stop × Gc를 더해 P'c = Pc × 2^delta_c로 복원합니다. Pc = 0이면 P'c = 0이며 signed negative residual과 alpha는 바꾸지 않습니다.

### CBEF Optical Blur

| ID | Type | Unit | Min | Max | Default | Increment | Animatable |
|---|---|---|---:|---:|---:|---:|---|
| blur | Double | frame-height percent | 0 | 4 | 0.15 | 0.01 | Yes |
| blades | Integer | blade count | 3 | 16 | 9 | 1 | Yes |
| curvature | Double | percent | 0 | 100 | 90 | 1 | Yes |
| rotation | Double | degrees | -180 | 180 | 0 | 1 | Yes |
| anamorphism | Double | horizontal/vertical ratio | 0.5 | 3.0 | 1.0 | 0.01 | Yes |
| highlight_response | Double | percent | 0 | 200 | 15 | 1 | Yes |

| Preset | Blur | Blades | Curvature | Rotation | Anamorphism | Highlight Response |
|---|---:|---:|---:|---:|---:|---:|
| Clean Soft | 0.15 | 9 | 90 | 0 | 1.0 | 15 |
| Round Bokeh | 0.30 | 12 | 100 | 0 | 1.0 | 25 |
| Anamorphic | 0.25 | 8 | 70 | 0 | 2.0 | 35 |

- Output View는 Final, Blurred Image, Highlight Component입니다.
- Final에서 mix = 0 또는 blur = 0이면 identity입니다.
- aperture kernel은 regular polygon과 circle 사이를 Curvature로 보간합니다.
- Rotation은 kernel geometry에 적용하고 Anamorphism은 horizontal/vertical radius 비율입니다.
- kernel은 최소 4×4 subpixel coverage sampling으로 만들고 weight 합을 1로 정규화합니다.
- Highlight Response matte pivot은 linear Y 0.72이고 knee는 1 stop입니다.
- Highlight Response는 blur(highlight) − highlight의 양수 성분만 추가하며 response 100은 이를 1배 더합니다.

### CBEF Lens Reflections

| ID | Type | Unit / Options | Min | Max | Default | Increment | Animatable |
|---|---|---|---:|---:|---:|---:|---|
| amount | Double | percent | 0 | 200 | 18 | 1 | Yes |
| threshold | Double | stops over 18% | -2 | 8 | 2.5 | 0.1 | Yes |
| lens_model | Choice | Clean Prime, Vintage Prime, Anamorphic | — | — | Clean Prime | — | No |
| spread | Double | percent | 0 | 200 | 65 | 1 | Yes |
| blur | Double | frame-height percent | 0 | 3 | 0.30 | 0.05 | Yes |
| chroma | Double | percent | 0 | 100 | 8 | 1 | Yes |
| anamorphism | Double | horizontal/vertical ratio | 0.5 | 3.0 | 1.0 | 0.01 | Yes |

| Preset | Amount | Threshold | Lens Model | Spread | Blur | Chroma | Anamorphism |
|---|---:|---:|---|---:|---:|---:|---:|
| Clean Prime | 18 | 2.5 | Clean Prime | 65 | 0.30 | 8 | 1.0 |
| Vintage Prime | 35 | 1.5 | Vintage Prime | 90 | 0.55 | 22 | 1.0 |
| Anamorphic | 30 | 2.0 | Anamorphic | 110 | 0.40 | 28 | 2.0 |

- Output View는 Final, Reflection Component, Source Matte입니다.
- Final에서 mix = 0 또는 amount = 0이면 identity입니다.
- highlight threshold는 0.18 × 2^threshold이고 source matte knee는 1 stop입니다.
- source highlight image 전체를 affine transform하며 connected-component tracking은 사용하지 않습니다.
- 광학 중심은 프레임 중심입니다.
- source 좌표 p의 ghost 좌표는 중심 c에 대해 c − k × spread/100 × (p − c)입니다.
- 각 ghost는 source highlight를 forward mapping하는 energy-conserving resampling으로 생성합니다. 완전히 화면 안에 있는 source의 ghost luminance 합은 affine scale과 관계없이 source highlight luminance 합과 같아야 합니다. 화면 밖으로 나간 energy는 버리고 반대 edge로 wrap하지 않습니다.
- 출력 높이를 H라 할 때 Gaussian sigma는 sigma_y = H × blur/100, sigma_x = sigma_y × anamorphism입니다. Gaussian은 화면 x/y 축에 정렬하고 각 kernel의 weight 합을 1로 정규화합니다. Blur 0은 convolution을 생략합니다.
- Energy-conserving affine mapping 후 Gaussian을 적용하고, 이어서 tint와 model energy를 적용합니다.
- model energy는 각 ghost에 곱한 뒤 합하며 Chroma 처리까지 끝난 합에 amount/100을 한 번만 곱합니다. 이 결과가 Reflection contribution입니다.

| Model | k 배열 | 상대 energy | tint 배열 |
|---|---|---|---|
| Clean Prime | 0.35, 0.80, 1.25 | 0.50, 0.32, 0.18 | warm, cool, amber |
| Vintage Prime | 0.20, 0.48, 0.82, 1.15, 1.55 | 0.24, 0.23, 0.21, 0.18, 0.14 | amber, green, blue, orange, cyan |
| Anamorphic | 0.30, 0.72, 1.10, 1.45 | 0.34, 0.30, 0.22, 0.14 | blue, amber, cyan, orange |

Tint 기준 linear DWG gain은 warm [1.00, 0.92, 0.78], cool [0.78, 0.92, 1.00], amber [1.00, 0.72, 0.48], green [0.72, 1.00, 0.82], blue [0.65, 0.82, 1.00], orange [1.00, 0.65, 0.45], cyan [0.65, 1.00, 0.90]입니다. 각 gain은 unit DWG luminance로 정규화합니다. Chroma는 neutral gain과 tint 사이를 보간합니다. 각 model energy 합은 1이며 Amount가 최종 contribution을 조절합니다.

### CBEF Mist Diffusion

| ID | Type | Unit / Options | Min | Max | Default | Increment | Animatable |
|---|---|---|---:|---:|---:|---:|---|
| mode | Choice | Black, White | — | — | Black | — | No |
| density | Choice | 1/8, 1/4, 1/2, 1 | — | — | 1/8 | — | No |
| diffusion | Double | percent | 0 | 100 | 18 | 1 | Yes |
| bloom | Double | percent | 0 | 100 | 12 | 1 | Yes |
| contrast | Double | percent | 0 | 100 | 8 | 1 | Yes |
| texture | Double | percent | 0 | 100 | 90 | 1 | Yes |

| Preset | Mode | Density | Diffusion | Bloom | Contrast | Texture |
|---|---|---|---:|---:|---:|---:|
| Black 1/8 | Black | 1/8 | 18 | 12 | 8 | 90 |
| Black 1/4 | Black | 1/4 | 28 | 18 | 12 | 85 |
| Black 1/2 | Black | 1/2 | 42 | 28 | 18 | 78 |
| Black 1 | Black | 1 | 60 | 42 | 26 | 68 |
| White 1/8 | White | 1/8 | 22 | 20 | 18 | 82 |
| White 1/4 | White | 1/4 | 35 | 32 | 28 | 75 |
| White 1/2 | White | 1/2 | 50 | 48 | 40 | 65 |
| White 1 | White | 1 | 70 | 65 | 55 | 55 |

- Output View는 Final, Diffusion Component, Highlight Matte입니다.
- Final에서 mix = 0이거나 Diffusion, Bloom과 Contrast가 모두 0이면 identity입니다.

계산은 canonical linear DWG의 positive image P에서 수행하고 signed negative residual은 마지막에 그대로 더합니다.

| Density | Radius factor fr | Energy factor fe |
|---|---:|---:|
| 1/8 | 0.80 | 0.25 |
| 1/4 | 0.95 | 0.50 |
| 1/2 | 1.10 | 0.75 |
| 1 | 1.25 | 1.00 |

Mode radius factor mr은 Black 1.00, White 1.25입니다. 출력 높이를 H, Diffusion 값을 d라 할 때 diffusion sigma는 r = H × ((0.10 + 1.40 × d/100) / 100) × fr × mr입니다.

Gsigma(X)는 edge 계약을 적용한 unit-sum Gaussian convolution입니다. Diffusion blur B는 0.70 × Gr(P) + 0.30 × G2.5r(P)입니다. Black mode의 raw diffusion은 max(B − P, 0), White mode는 signed B − P입니다. 최종 diffusion contribution은 raw diffusion × (d/100) × fe입니다.

분석 luminance Y에 대해 x = log2(max(Y, 2^-16)/0.18), Highlight Matte M = smoothstep(1, 3, x)입니다. S = M × P에 대한 raw bloom Bh는 max(0.65 × G1.5r(S) + 0.35 × G4r(S) − S, 0)입니다. 최종 bloom contribution은 Bh × (bloom/100) × fe입니다.

원 positive image에 Diffusion과 Bloom contribution을 더한 RGB, 즉 Q = P + diffusion contribution + bloom contribution으로 정의합니다. YQ = max(luminance(Q), 2^-16)이고 mode별 contrast denominator D는 Black 200, White 125입니다. Contrast slope는 s = max(0.20, 1 − fe × contrast/D), 목표 luminance는 YC = 0.18 × 2^(s × log2(YQ/0.18))입니다. Q가 0이 아니면 C = Q × YC/YQ, 아니면 C = 0입니다.

t = texture/100일 때 detail-restored positive result는 R = t × P + (1 − t) × C입니다. Texture 100은 positive source를 완전히 복원하고 Texture 0은 diffusion·bloom·contrast 결과를 그대로 사용합니다. 최종 effected RGB는 R에 원래 signed negative residual을 더한 값입니다.

## Testing Decisions

모든 좋은 자동 테스트는 내부 함수의 호출 여부가 아니라 Headless Render Contract에 입력한 요청과 완료 후 목적 프레임에서 관찰되는 외부 행동을 검증합니다. 기존 코드는 아직 없으므로 유사 테스트의 prior art도 없습니다. 공식 Blackmagic OpenFX 예제의 호스트 연결 방식은 구현 참고 자료일 뿐 테스트 seam으로 복제하지 않습니다.

### Headless Render Contract 공통 검증

- CPU fixture는 padding이 있는 row stride와 non-zero data-window origin을 포함합니다.
- Metal fixture는 실제 MTLBuffer와 테스트 소유 MTLCommandQueue를 사용합니다.
- Enqueued 반환 뒤 같은 queue에 sentinel command buffer를 제출해 완료를 기다린 후 결과를 읽습니다.
- production Metal 경로에는 테스트용 wait를 넣지 않습니다.
- 다섯 Effect Definition의 parameter ID는 각 효과 안에서 중복되지 않아야 합니다.
- 모든 default와 preset expansion은 범위 안에 있어야 합니다.
- default settings는 기본 preset expansion과 같아야 합니다.
- 잘못된 Effect ID/settings 조합, alias surface, 잘못된 stride와 render window는 정의된 오류로 실패해야 합니다.
- render window 밖 destination sentinel byte는 유지되어야 합니다.
- Final identity는 render window 안 모든 RGBA float bit pattern이 source와 정확히 같아야 합니다. 이 fixture에는 alpha 0이면서 non-zero hidden RGB인 Straight 픽셀을 반드시 포함합니다.
- finite HDR fixture에서 출력은 모두 finite여야 합니다.
- CPU–Metal 최대 절대 오차는 2e-4 이하여야 합니다.
- 출력 alpha는 입력과 bit-identical이어야 합니다.
- transparent edge의 RGB leak은 1e-6 이하여야 합니다.
- 세 Working Mode의 동일 XYZ fixture 결과를 canonical DWG로 비교한 최대 절대 오차는 3e-4 이하여야 합니다.

### 해상도 비교

- fixture 값 범위는 0~1로 제한합니다.
- 4K 결과를 Lanczos-3으로 1080p에 축소합니다.
- 양쪽 결과에 sigma 1.0 pixel Gaussian low-pass를 적용합니다.
- peak 1.0 기준 PSNR을 계산합니다.
- Halation, Optical Blur, Lens Reflections와 Mist Diffusion은 PSNR 45dB 이상이어야 합니다.
- 효과 half-maximum radius 차이는 프레임 높이의 0.1% 이하여야 합니다.
- 저주파 효과 energy 차이는 3% 이하여야 합니다.
- Film Grain은 직접 PSNR 비교에서 제외합니다.

### 효과별 자동 판정

Halation:

- threshold knee 아래 neutral patch의 matte 최대값은 1e-6 이하여야 합니다.
- highlight edge 바깥 profile은 peak 이후 단조 비증가해야 하며 허용 역행은 1e-5입니다.
- halo contribution은 -1e-6보다 작아서는 안 됩니다.
- neutral fixture의 기본 halo는 R ≥ G ≥ B여야 합니다.
- 기본 highlight core의 luminance 변화는 2% 이하여야 합니다.
- 프레임 edge와 중앙 halo의 같은 거리 profile 차이는 3% 이하여야 합니다.

Film Grain:

- 같은 요청의 CPU 재실행은 bit-identical이어야 합니다.
- 같은 정수 프레임으로 양자화되는 subframe은 같은 field를 만들어야 합니다.
- 이웃 프레임 상관계수 절댓값은 0.1 미만이어야 합니다.
- 48프레임 18% gray fixture의 channel별 평균 bias는 5e-4 미만이어야 합니다.
- 측정 log-exposure RMS는 Film Grain 계약의 sigma_stop으로 계산한 목표의 ±5%여야 합니다.
- 1080p와 4K의 canonical particle diameter 차이는 ±8%여야 합니다.
- 두 해상도 radial power spectrum 차이는 normalized 0.05~0.45 Nyquist 구간에서 median 1.5dB 이하여야 합니다.
- horizontal/vertical spectrum energy 차이는 1.5dB 이하여야 합니다.
- 기대 channel correlation과 측정값 차이는 0.05 이하여야 합니다.
- 비-DC spectrum spike는 local radial median보다 6dB 이상 높아서는 안 됩니다.

Optical Blur:

- Highlight Response 0에서 aperture kernel 합은 1 ± 1e-5여야 합니다.
- kernel centroid는 중심에서 0.05 pixel 이내여야 합니다.
- constant image 변화는 1e-5 이하여야 합니다.
- measured second-moment anamorphism은 설정값의 ±2%여야 합니다.
- binary aperture mask와 analytic target mask의 IoU는 0.95 이상이어야 합니다.
- Highlight Response 증가에 따라 highlight component energy가 감소해서는 안 됩니다.

Lens Reflections:

- threshold knee 아래 source matte는 1e-6 이하여야 합니다.
- ghost centroid는 정의 위치에서 CPU 0.25, Metal 0.5 canonical pixel 이내여야 합니다.
- model별 ghost energy 비율은 정의값의 ±3%여야 합니다.
- Amount 증가에 따라 total reflection energy가 감소해서는 안 됩니다.
- threshold를 작은 간격으로 통과하는 연속 fixture에서 프레임 간 reflection energy 점프는 입력 highlight energy 변화의 1.25배를 넘지 않아야 합니다.
- off-screen sample이 반대 edge에 wrap되어 나타나서는 안 됩니다.

Mist Diffusion:

- Density 단조 검증은 opaque linear-DWG 중앙 impulse, Black mode, Diffusion 50, Bloom 0, Contrast 0, Texture 0에서 Density만 바꿉니다. 중앙 3×3을 제외한 Diffusion Component의 absolute luminance 합은 1/8 < 1/4 < 1/2 < 1이어야 합니다.
- White/Black 반경 검증은 같은 impulse, Density 1/4, Diffusion 50, Bloom 0, Contrast 0, Texture 0에서 Mode만 바꿉니다. 중앙 core를 제외한 양수 radial profile의 half-maximum radius 비 White/Black은 최소 1.20이어야 합니다.
- shadow lift 검증은 opaque 5% neutral gray에서 Black 1/8과 White 1/8 기본 프리셋을 비교하며 Black은 White의 60% 이하여야 합니다.
- 기본 Black 1/8의 0.25 cycle/pixel MTF 보존율은 0.80 이상이어야 합니다.
- 기본 White 1/8의 같은 MTF 보존율은 0.65 이상이어야 합니다.
- Texture 증가에 따라 measured MTF가 감소해서는 안 됩니다.

### 자동 성능 측정

기준은 Apple M3 Pro, 기본 프리셋, Final, Mix 100입니다.

- 3프레임 warm-up 후 10프레임을 측정합니다.
- Metal median render time을 사용합니다.
- 1080p 개별 효과는 41.67ms 이하여야 합니다.
- 4K 개별 효과는 83.33ms 이하여야 합니다.
- 4K Film Grain은 41.67ms 이하여야 합니다.
- 4K에서 플러그인 소유 임시 메모리 peak는 효과 instance당 1GiB 이하여야 합니다.
- 최대 파라미터의 성능은 완료 조건이 아니지만 정확성과 메모리 안전성은 유지해야 합니다.

### Resolve Free Host Acceptance

수동 성능 QA 기준 환경은 Apple M3 Pro 18GB, macOS 26, DaVinci Resolve Free 21, Metal GPU mode, render cache off, optimized media off, proxy mode off, scopes off, single viewer, 24fps timeline으로 고정합니다. 해상도 체감 비교 시나리오에서만 proxy mode를 half와 quarter로 각각 바꾸고, 측정이 끝나면 off로 복원합니다.

기준 프로젝트에는 1920×1080/24와 3840×2160/24 timeline을 두며 각 기준 구간은 10초입니다.

필수 증거:

1. OS·Resolve·플러그인 버전과 build identifier
2. 설치된 bundle hash
3. 다섯 효과가 같은 group에 표시된 screenshot
4. Edit 페이지 적용 screenshot
5. Color 페이지 적용 screenshot
6. 각 효과의 기본 Inspector screenshot
7. 각 프리셋 적용 전후 파라미터 screenshot
8. Studio badge·watermark·DCTL 요구가 없음을 보여주는 screenshot 또는 recording
9. Film Grain 재생·정지·scrub·재렌더 screen recording
10. 1080p·4K·proxy 비교 frame export
11. 기준 릴의 효과별 before/after frame
12. 효과별 pass/fail 표와 사용자 시각 승인

수동 fps 절차:

1. 각 효과를 개별 노드 또는 클립에 기본 프리셋으로 적용합니다.
2. 첫 재생은 shader와 cache warm-up으로 제외합니다.
3. 같은 10초 구간을 세 번 재생합니다.
4. Resolve viewer가 보고한 fps의 세 실행 median을 기록합니다.
5. 1080p median은 24fps 이상이어야 합니다.
6. 4K median은 12fps 이상이어야 합니다.
7. Film Grain 4K median은 24fps 이상이어야 합니다.
8. 한 실행에서 목표의 90% 미만 상태가 1초 넘게 지속되면 실패합니다.
9. 다섯 효과 동시 chain fps는 기록할 수 있지만 완료 gate가 아닙니다.

기준 릴은 피부와 창문 하이라이트, 야간 practical light, neon과 포화 LED, 역광 머리카락, 저조도 shadow, 미세 texture, 흰 자막과 그래픽, 프레임 edge highlight, 단일·다중·화면 밖 광원, 느린 pan과 정지 shot을 모두 포함합니다.

자연스러운 기본값의 최종 pass/fail은 사용자 시각 승인으로 결정하며 자동 metric으로 대체하지 않습니다.

## Out of Scope

- DaVinci Resolve Studio 전용 기능
- DCTL과 Fusion 매크로
- 카메라별 Log 변환, 카메라 자동 감지와 Working Mode 자동 추정
- Windows, Linux, Intel Mac과 universal2
- 공개 배포, 코드 서명, 공증, 설치 프로그램과 자동 업데이트
- VHS 손상, Gate Weave와 Flicker
- temporal repair, noise reduction, object removal와 face correction
- AI 효과와 depth-map Optical Blur
- 외부 film scan texture
- 제조사 film stock 이름과 상표가 있는 diffusion filter preset
- Blackmagic 또는 필터 제조사 내부 구현 복제
- 다섯 효과 동시 4K 실시간 재생 보장
- 첫 버전의 tile/ROI 최적화
- 가짜 OFX host와 내부 pass별 공개 테스트 interface

## Further Notes

- DaVinci Wide Gamut 원색, 행렬과 DaVinci Intermediate transfer는 Blackmagic Design의 공식 DaVinci Wide Gamut Intermediate 문서를 oracle로 사용합니다: https://documents.blackmagicdesign.com/InformationNotes/DaVinci_Resolve_17_Wide_Gamut_Intermediate.pdf
- Rec.709 원색과 D65는 ITU-R BT.709를 기준으로 합니다: https://www.itu.int/rec/R-REC-BT.709-6-201506-I/en
- Gamma 2.4 mode는 의도적으로 pure gamma texture encoding으로 한정하며 BT.1886 black-level 변형과 구분합니다.
- 구현 중 기본값이나 프리셋 수치가 기준 릴에서 실패하면 구현에서 몰래 바꾸지 않습니다. 명세 수치, 자동 fixture와 수동 증거를 함께 갱신합니다.
- Headless Render Contract 통과는 Resolve Free 호환성을 대신하지 않습니다.
- Resolve Free Host Acceptance의 시각 승인은 CPU–Metal parity와 수치 검증을 대신하지 않습니다.
- 구현 티켓은 M0 골격, M1 Render Contract·색·알파, M2 Halation, M3 Film Grain, M4 Mist Diffusion, M5 Optical Blur, M6 Lens Reflections, M7 통합 QA 순서를 유지합니다.
