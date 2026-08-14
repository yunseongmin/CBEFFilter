# CBEF Film Effects v2 구현 명세

Status: ready-for-agent

## Problem Statement

DaVinci Resolve 무료판 사용자는 Studio 전용 기능, DCTL 또는 Fusion 매크로 없이도 할레이션, 필름 그레인, 광학 블러, 렌즈 반사, Black·White 미스트 확산을 사용할 수 있어야 합니다. 현재 CBEF Film Effects v1은 Apple Silicon Mac의 Resolve 무료판에서 다섯 설치형 효과를 독립적으로 로드하고 렌더하며, HDR·알파·결정성·CPU/Metal 일치성을 검증하는 안정적인 기반을 갖추었습니다.

그러나 현재 효과 수학은 고급 필름·광학 효과가 보여야 하는 재료적 반응을 충분히 표현하지 못합니다. Halation은 RGB 하이라이트를 흐린 뒤 따뜻하게 착색하여 백색 블룸처럼 보이고, Lens Reflections는 장면의 밝은 실루엣을 불투명한 복제상처럼 만들 수 있습니다. Film Grain은 절차적 통계는 안정적이지만 stock response와 촬영 포맷·확대율이 결합되어 있으며, Mist는 glow·veil·detail이 분리되지 않았고, Optical Blur는 화면 전체에 같은 조리개 커널을 적용합니다. 기존 PASS는 효과가 실행되고 수치적으로 안전하다는 뜻이지, 실제 필름·필터·렌즈처럼 자연스럽다는 뜻이 아닙니다.

사용자는 강도를 높였을 때도 단순 블러·노이즈·오버레이로 무너지지 않고, 광원의 밝기·색·위치, 배경 밝기, 노출, 화면 위치와 작업 공간에 일관되게 반응하는 결과를 원합니다. 동시에 공개 자료가 제공하지 않는 필름·필터·렌즈 계수를 실제 물성처럼 주장해서는 안 됩니다. 따라서 v2는 물리적 구조와 관찰 가능한 방향성은 1차 자료에 근거하되, 실측 전 수치는 명확한 placeholder로 관리하고 실제 계측과 사용자 시각 승인을 분리해야 합니다.

## Solution

CBEF Film Effects v2는 기존 Apple Silicon arm64 네이티브 OpenFX 번들과 다섯 개의 안정적인 effect ID를 유지하면서, 효과 알고리즘과 내부 렌더 구조를 전면 교체합니다. 하나의 설치 패키지 안에서 다음 설치형 효과를 계속 독립적으로 제공합니다.

1. CBEF Halation
2. CBEF Film Grain
3. CBEF Optical Blur
4. CBEF Lens Reflections
5. CBEF Mist Diffusion

공통 색 처리, 광원 분석, 다중 스케일 산란, field-dependent PSF, 프레임 임시 메모리와 typed effect compilation을 하나의 깊은 렌더 코어 뒤에 숨깁니다. 외부 자동 테스트 경계는 기존의 `render(RenderRequest, RenderBackend) -> RenderSubmission` 하나를 유지합니다. CPU는 명세의 reference adapter로 먼저 구현하고, 승인된 reference behavior를 Metal adapter가 같은 품질 모드와 허용 오차 안에서 재현합니다.

Halation은 source/background-aware local halo와 global glare를 채널별 산란으로 분리합니다. Film Grain은 Stock Response와 Capture Format·확대율·처리·표시 배율을 분리하고 노출·color record별 RMS/MTF/covariance profile을 사용합니다. Mist는 Generic Black과 Generic White의 Glow·Veil·Detail을 별도 profile로 처리하고 강도 단계를 Grade로 표시합니다. Lens Reflections는 자동 광원 검출에 수동 광원과 외부 matte fallback을 추가하고, profile별 signed axis position을 가진 ghost element를 생성합니다. Optical Blur는 depth 없는 uniform defocus라는 정직한 제품 범위를 유지하면서 화면 위치별 PSF, cat-eye와 기본 수차를 추가합니다.

Inspector는 Basic, Advanced, Diagnostics 그룹으로 나눕니다. 기본 화면은 자연스러운 프리셋과 3~5개의 핵심 제어 및 Mix만 노출하고, 고급 profile 제어와 격리 출력은 필요할 때 펼칩니다. 카메라 Log 변환과 카메라 감지는 계속 Resolve가 담당하며 사용자는 실제 노드 입력과 일치하는 Working Mode를 명시합니다.

완료 여부는 Safety, Model, Parity, Aesthetic 네 gate로 판단합니다. 자동 계약만 통과하거나 화면 차이가 보이는 것만으로 완료하지 않습니다. 실제 설치, Inspector 동작, Edit/Color 적용, 재생, 렌더, 기본 프리셋의 자연스러움과 강한 설정의 설득력은 실제 DaVinci Resolve 무료판에서 승인합니다.

## User Stories

1. Apple Silicon Mac 사용자로서, 기존과 같은 하나의 번들로 다섯 효과를 설치하고 싶습니다. 그래야 업데이트와 백업을 한 단위로 관리할 수 있습니다.
2. Resolve 무료판 사용자로서, Studio 라이선스 없이 다섯 효과를 미리 보고 최종 렌더하고 싶습니다. 그래야 추가 구독 없이 개인 작업을 완성할 수 있습니다.
3. Resolve 무료판 사용자로서, 다섯 효과가 기존 이름과 위치에서 계속 보이길 원합니다. 그래야 v2 설치 후 효과를 다시 찾지 않아도 됩니다.
4. 컬러리스트로서, 다섯 효과를 독립 노드에 원하는 순서로 배치하고 싶습니다. 그래야 하나의 고정된 필름 룩 대신 장면별 파이프라인을 구성할 수 있습니다.
5. 편집자로서, Edit 페이지의 클립에 각 효과를 적용하고 싶습니다. 그래야 편집 흐름에서 빠르게 룩을 시험할 수 있습니다.
6. 컬러리스트로서, Color 페이지의 노드에 각 효과를 적용하고 싶습니다. 그래야 기존 그레이딩과 창·키를 함께 사용할 수 있습니다.
7. 개인 사용자로서, DCTL이나 Fusion 매크로를 별도로 설치하지 않고 싶습니다. 그래야 일반적인 설치형 효과처럼 관리할 수 있습니다.
8. 기존 v1 사용자로서, v1 번들을 별도로 백업하고 v2를 명확히 구분하고 싶습니다. 그래야 이전 결과가 필요할 때 수동으로 복구할 수 있습니다.
9. 기존 v1 사용자로서, v2 안에 숨은 legacy algorithm 스위치를 보지 않길 원합니다. 그래야 새 품질 기준과 오래된 구현이 섞이지 않습니다.
10. Log 촬영 사용자로서, 카메라 Log 변환을 Resolve Color Management 또는 CST에 맡기고 싶습니다. 그래야 플러그인이 카메라별 변환을 중복하지 않습니다.
11. 컬러리스트로서, 실제 노드 입력과 일치하는 Working Mode를 직접 선택하고 싶습니다. 그래야 광량 기반 효과의 threshold와 색이 예측 가능합니다.
12. DWG / Intermediate 사용자로서, 이 작업 공간을 명시적으로 선택하고 싶습니다. 그래야 일반적인 Resolve 광색역 워크플로에서 올바른 결과를 얻습니다.
13. DWG / Linear 사용자로서, 선형 입력 모드를 직접 선택하고 싶습니다. 그래야 불필요한 transfer 왕복을 피할 수 있습니다.
14. Rec.709 / Gamma 2.4 사용자로서, 단순한 SDR 프로젝트에서도 예측 가능한 결과를 얻고 싶습니다. 그래야 별도 광색역 설정 없이 사용할 수 있습니다.
15. 처음 사용하는 사용자로서, Working Mode가 카메라나 입력을 자동 감지하지 않는다는 설명을 보고 싶습니다. 그래야 잘못된 입력 가정을 스스로 수정할 수 있습니다.
16. HDR 작업 사용자로서, 1.0을 넘는 RGB가 조기에 잘리지 않길 원합니다. 그래야 밝은 광원의 에너지와 highlight latitude를 보존할 수 있습니다.
17. 광색역 작업 사용자로서, 음수 RGB가 임의로 0에 잘리지 않길 원합니다. 그래야 색 변환의 유효한 signed 성분을 보존할 수 있습니다.
18. 알파 영상 사용자로서, straight-alpha 입력의 알파가 bit-identical하게 유지되길 원합니다. 그래야 합성 경계가 변하지 않습니다.
19. 알파 영상 사용자로서, premultiplied-alpha의 숨은 RGB가 이웃으로 새지 않길 원합니다. 그래야 투명 경계에 색 프린지가 생기지 않습니다.
20. 알파 영상 사용자로서, 완전히 투명한 픽셀에 halo·grain·flare가 생기지 않길 원합니다. 그래야 합성 결과가 오염되지 않습니다.
21. 사용자로서, Mix 또는 효과의 핵심 강도를 0으로 만들면 원본을 정확히 얻고 싶습니다. 그래야 안전하게 우회하고 키프레임을 적용할 수 있습니다.
22. 프록시 사용자로서, 1080p·UHD·8K·Render Scale에서 효과의 체감 크기가 유지되길 원합니다. 그래야 편집과 최종 렌더의 룩이 달라지지 않습니다.
23. 사용자로서, 프레임 가장자리에서 halo·blur seam·ghost wrap을 보지 않길 원합니다. 그래야 화면 전체가 자연스럽게 이어집니다.
24. 처음 사용하는 사용자로서, 자연스러운 기본 프리셋과 적은 수의 Basic 제어만 먼저 보고 싶습니다. 그래야 복잡한 광학 지식 없이 시작할 수 있습니다.
25. 숙련 사용자로서, Advanced 그룹에서 source, shape, spectrum, lens와 quality를 세밀하게 조절하고 싶습니다. 그래야 장면별로 깊은 튜닝을 할 수 있습니다.
26. 룩 개발 사용자로서, Diagnostics 그룹에서 source mask와 effect-only layer를 보고 싶습니다. 그래야 선택 범위와 효과 성분을 객관적으로 조정할 수 있습니다.
27. 사용자로서, 진단 화면이 Final 결과가 아니라는 명확한 표시를 보고 싶습니다. 그래야 진단 출력을 최종 영상으로 착각하지 않습니다.
28. 사용자로서, 프리셋을 바꿔도 Working Mode, Output View와 Mix가 유지되길 원합니다. 그래야 색·진단·합성 설정을 잃지 않습니다.
29. 사용자로서, 프리셋을 수정하면 Custom 상태를 확인하고 싶습니다. 그래야 저장된 시작점과 현재 룩을 구분할 수 있습니다.
30. 사용자로서, 특정 profile에 필요하지 않은 제어는 비활성화되거나 숨겨지길 원합니다. 그래야 Inspector가 현재 효과와 관련된 값만 보여 줍니다.
31. 사용자로서, 파라미터 도움말에서 결과 방향과 권장 Working Mode를 확인하고 싶습니다. 그래야 수치를 추측하지 않고 조절할 수 있습니다.
32. 할레이션 사용자로서, 밝은 경계 바깥에 좁고 따뜻한 local halo를 얻고 싶습니다. 그래야 전체 화면 글로우가 아닌 필름층 산란처럼 보입니다.
33. 할레이션 사용자로서, 광원 주변에 넓고 약한 global glare를 local halo와 따로 조절하고 싶습니다. 그래야 가까운 테두리와 먼 산란을 균형 있게 만들 수 있습니다.
34. 할레이션 사용자로서, 중성 광원의 중심이 과도하게 붉어지거나 하얗게 부풀지 않길 원합니다. 그래야 highlight core가 유지됩니다.
35. 할레이션 사용자로서, 밝은 배경에서는 halo가 자연스럽게 묻히고 어두운 배경에서는 잘 보이길 원합니다. 그래야 스티커 같은 고정 농도로 보이지 않습니다.
36. 할레이션 사용자로서, 중성·tungsten·청색 LED·포화 적색 광원에 서로 설득력 있게 반응하길 원합니다. 그래야 고정 빨강 외곽선이 되지 않습니다.
37. 할레이션 사용자로서, Source Limit과 Source Smoothness를 조절하고 싶습니다. 그래야 threshold를 통과할 때 halo가 갑자기 켜지지 않습니다.
38. 할레이션 사용자로서, Local Radius와 Global Diffusion을 독립적으로 조절하고 싶습니다. 그래야 장면 크기에 맞는 산란 형태를 만들 수 있습니다.
39. 할레이션 사용자로서, Red Bias와 Blue Compensation을 profile-relative 제어로 사용하고 싶습니다. 그래야 공개 실측값인 것처럼 오해하지 않고 색 반응을 조절할 수 있습니다.
40. 할레이션 사용자로서, Halation Only, Local Only, Global Only와 Source Mask를 확인하고 싶습니다. 그래야 각 branch의 기여를 분리해 판단할 수 있습니다.
41. 할레이션 사용자로서, `No Remjet` 또는 `No Backing`이라는 근거 없는 프리셋을 보지 않길 원합니다. 그래야 rem-jet 부재와 anti-halation 부재를 혼동하지 않습니다.
42. 할레이션 사용자로서, 실측되지 않은 강한 룩은 Generic 또는 Uncalibrated로 표시되길 원합니다. 그래야 실제 stock 재현으로 오해하지 않습니다.
43. 필름 그레인 사용자로서, 같은 seed·frame·설정에서 같은 패턴을 얻고 싶습니다. 그래야 캐시와 최종 렌더를 재현할 수 있습니다.
44. 필름 그레인 사용자로서, 임의 순서로 탐색해도 같은 프레임의 패턴이 바뀌지 않길 원합니다. 그래야 random seek와 재렌더가 안정적입니다.
45. 필름 그레인 사용자로서, 이웃 프레임에서는 새로운 입자 구조를 얻고 싶습니다. 그래야 고정 노이즈처럼 화면에 붙지 않습니다.
46. 필름 그레인 사용자로서, Stock Response와 Capture Format을 따로 선택하고 싶습니다. 그래야 유제 반응과 확대에 따른 체감 입자 크기를 혼동하지 않습니다.
47. 필름 그레인 사용자로서, 촬영 포맷·스캔 샘플링·최종 표시 배율이 입자 크기에 일관되게 반영되길 원합니다. 그래야 해상도를 바꿔도 같은 필름 면적의 느낌이 유지됩니다.
48. 필름 그레인 사용자로서, 노출에 따라 RMS·입자 크기·clumping이 profile 곡선을 따라 변하길 원합니다. 그래야 균일 노이즈 오버레이처럼 보이지 않습니다.
49. 필름 그레인 사용자로서, R/G/B color record가 서로 다른 MTF와 covariance를 갖길 원합니다. 그래야 독립 RGB 점 노이즈나 단색 luma noise를 피할 수 있습니다.
50. 필름 그레인 사용자로서, Film Resolution과 Grain Softness를 따로 조절하고 싶습니다. 그래야 원본 해상감과 입자 선예도를 독립적으로 맞출 수 있습니다.
51. 필름 그레인 사용자로서, 음영·중간톤·하이라이트의 반응을 조절하고 싶습니다. 그래야 장면 노출에 맞는 질감을 만들 수 있습니다.
52. 필름 그레인 사용자로서, 순수 black과 white 부근에서 입자가 자연스럽게 감쇠하길 원합니다. 그래야 끝점에서 디지털 노이즈가 끓지 않습니다.
53. 필름 그레인 사용자로서, single-pixel sparkle·격자·반복 peak·밝기 맥동을 보지 않길 원합니다. 그래야 절차적 합성 흔적이 드러나지 않습니다.
54. 필름 그레인 사용자로서, 100% 확대와 정상 속도 재생에서 모두 자연스러운 입자를 얻고 싶습니다. 그래야 축소 미리보기의 착시로 품질을 판단하지 않습니다.
55. 필름 그레인 사용자로서, 측정 profile이 없는 제조사 stock 이름을 보지 않길 원합니다. 그래야 generic 성격과 실제 stock calibration을 구분할 수 있습니다.
56. 미스트 확산 사용자로서, Generic Black과 Generic White 계열을 선택하고 싶습니다. 그래야 상표를 모방하지 않고 관찰 가능한 성격 차이를 사용할 수 있습니다.
57. 미스트 확산 사용자로서, 강도 선택이 Density가 아닌 Grade로 표시되길 원합니다. 그래야 1/4이 1/8의 정확한 두 배라는 물리적 오해를 피할 수 있습니다.
58. Generic Black 사용자로서, highlight glow와 피부 완화는 얻되 broad veil과 black lift는 제한하고 싶습니다. 그래야 암부와 대비를 더 잘 유지할 수 있습니다.
59. Generic White 사용자로서, 더 넓은 white glow와 더 큰 veil·contrast 감소를 얻고 싶습니다. 그래야 부드럽고 대기감 있는 결과를 만들 수 있습니다.
60. 미스트 확산 사용자로서, Glow·Veil·Detail을 독립적으로 조절하고 싶습니다. 그래야 광원 번짐과 화면 대비와 피부 질감을 별도로 맞출 수 있습니다.
61. 미스트 확산 사용자로서, 눈·머리카락·직물의 중간 주파수 edge를 유지하고 싶습니다. 그래야 영상 전체가 초점 이탈처럼 보이지 않습니다.
62. 미스트 확산 사용자로서, Glow Only·Veil Only·Detail Difference·Source Mask를 보고 싶습니다. 그래야 각 branch가 의도대로 작동하는지 확인할 수 있습니다.
63. 미스트 확산 사용자로서, Grade를 올릴 때 glow·veil·detail 변화가 연속적이고 단조롭길 원합니다. 그래야 단계 전환에서 결과가 튀지 않습니다.
64. 미스트 확산 사용자로서, 중성 profile이 피부색을 과도하게 이동시키지 않길 원합니다. 그래야 확산 효과가 색 보정처럼 작동하지 않습니다.
65. 미스트 확산 사용자로서, 제조사 제품명이나 실제 필터 계측을 암시하지 않는 프리셋을 원합니다. 그래야 generic profile의 범위를 정확히 이해할 수 있습니다.
66. 렌즈 반사 사용자로서, 장면의 실제 광원 위치·크기·색·에너지에 반응하는 ghost를 얻고 싶습니다. 그래야 고정 flare bitmap처럼 보이지 않습니다.
67. 렌즈 반사 사용자로서, 여러 광원을 독립적인 source로 분석하길 원합니다. 그래야 장면 전체 하이라이트가 한 장의 복제상으로 변하지 않습니다.
68. 렌즈 반사 사용자로서, 자동 검출이 실패할 때 수동 광원 위치를 지정하고 싶습니다. 그래야 clipped 광원과 복잡한 야간 장면을 교정할 수 있습니다.
69. 렌즈 반사 사용자로서, 외부 matte로 반응할 광원을 제한하고 싶습니다. 그래야 자동 source isolation의 오검출을 확실히 우회할 수 있습니다.
70. 렌즈 반사 사용자로서, 광원과 optical center를 잇는 축을 따라 ghost가 연속적으로 이동하길 원합니다. 그래야 렌즈 내부 반사처럼 보입니다.
71. 렌즈 반사 사용자로서, 각 element가 profile별 signed axis position을 갖길 원합니다. 그래야 모든 ghost가 보편적인 `k=-1` 대칭으로 강제되지 않습니다.
72. 렌즈 반사 사용자로서, 일부 focused ghost가 광원 실루엣을 닮는 결과를 허용하고 싶습니다. 그래야 실제로 가능한 focused reflection을 무조건 결함으로 처리하지 않습니다.
73. 렌즈 반사 사용자로서, focused ghost에도 profile별 감쇠·defocus·spectral response·background adaptation이 적용되길 원합니다. 그래야 원본 광원이 불투명한 스티커처럼 복사되지 않습니다.
74. 렌즈 반사 사용자로서, aperture disc·ring·veil·streak를 element별로 분리해 만들고 싶습니다. 그래야 여러 형태가 하나의 Gaussian 복제로 축약되지 않습니다.
75. 렌즈 반사 사용자로서, 밝은 배경에서 ghost가 자연스럽게 묻히길 원합니다. 그래야 합성이 장면 대비와 무관하게 떠 보이지 않습니다.
76. 렌즈 반사 사용자로서, 화면 밖 광원이 정해진 reach 안에서만 기여하길 원합니다. 그래야 반대 edge wrap이나 임의 flare가 생기지 않습니다.
77. 렌즈 반사 사용자로서, Source Map·Ghost Paths·Elements Only와 element solo를 보고 싶습니다. 그래야 광원 검출과 profile geometry를 진단할 수 있습니다.
78. 렌즈 반사 사용자로서, 광원 threshold를 통과할 때 위치와 에너지가 갑자기 튀지 않길 원합니다. 그래야 움직이는 practical light에서 flicker가 없습니다.
79. 렌즈 반사 사용자로서, 실제 렌즈명·focal length·T-stop을 가장한 generic profile을 보지 않길 원합니다. 그래야 예술적 profile과 calibrated profile을 구분할 수 있습니다.
80. 광학 블러 사용자로서, 깊이 지도 없이 전체 프레임에 uniform optical defocus를 적용하고 싶습니다. 그래야 Resolve의 window와 key로 적용 영역을 직접 정할 수 있습니다.
81. 광학 블러 사용자로서, 화면 중앙과 모서리에서 서로 다른 PSF를 얻고 싶습니다. 그래야 전 화면 동일 convolution처럼 보이지 않습니다.
82. 광학 블러 사용자로서, 모서리에서 field와 azimuth에 따라 cat-eye 모양이 연속적으로 변하길 원합니다. 그래야 effective pupil clipping처럼 보입니다.
83. 광학 블러 사용자로서, Blades·Roundness·Rotation·Anamorphism을 조절하고 싶습니다. 그래야 조리개 성격을 디자인할 수 있습니다.
84. 광학 블러 사용자로서, Center/Rim Bias를 조절하고 싶습니다. 그래야 bokeh 중심과 외곽 에너지 분포를 맞출 수 있습니다.
85. 광학 블러 사용자로서, coma·astigmatism·chromatic aberration을 약하게 조절하고 싶습니다. 그래야 generic profile 안에서도 렌즈 성격을 만들 수 있습니다.
86. 광학 블러 사용자로서, channel별 PSF가 에너지를 보존하길 원합니다. 그래야 Defocus 자체가 노출을 바꾸지 않습니다.
87. 광학 블러 사용자로서, Preview·Balanced·Final 품질을 선택하고 싶습니다. 그래야 작업 속도와 최종 품질을 상황에 맞출 수 있습니다.
88. 광학 블러 사용자로서, 같은 품질과 설정에서 CPU와 Metal의 sample sequence가 일치하길 원합니다. 그래야 backend에 따라 bokeh가 바뀌지 않습니다.
89. 광학 블러 사용자로서, depth가 없을 때 Depth of Field나 실제 focus distance라는 주장을 보지 않길 원합니다. 그래야 uniform defocus의 범위를 정확히 이해할 수 있습니다.
90. 광학 블러 사용자로서, PSF Preview와 Highlight Source Map을 보고 싶습니다. 그래야 field behavior와 highlight response를 진단할 수 있습니다.
91. 개발자로서, 다섯 효과의 host 값을 하나의 typed effect variant로 컴파일하고 싶습니다. 그래야 backend가 문자열 ID와 UI 의미를 반복 해석하지 않습니다.
92. 개발자로서, 공통 Color Pipeline을 통해 transfer·gamut·exposure metric을 일관되게 처리하고 싶습니다. 그래야 효과마다 Working Mode 수학이 갈라지지 않습니다.
93. 개발자로서, 공통 Optics Primitives를 렌더 코어 뒤에 숨기고 싶습니다. 그래야 source isolation·산란·PSF·grain 계약을 CPU와 Metal이 공유할 수 있습니다.
94. 개발자로서, command 완료와 연결된 Frame Arena를 사용하고 싶습니다. 그래야 다중 패스에서 임시 메모리를 안전하게 재사용할 수 있습니다.
95. 개발자로서, runtime shader 문자열 대신 사전 컴파일된 Metal library를 사용하고 싶습니다. 그래야 실행 중 컴파일 비용과 거대한 중복 소스를 줄일 수 있습니다.
96. 개발자로서, CPU reference behavior를 먼저 승인한 뒤 Metal을 구현하고 싶습니다. 그래야 두 backend가 같은 잘못된 단순화를 공유하는 것을 방지할 수 있습니다.
97. 개발자로서, 기존 최상위 렌더 계약 하나로 자동 행동을 검증하고 싶습니다. 그래야 내부 함수가 공개 테스트 API로 굳지 않습니다.
98. 개발자로서, 내부 pass·kernel·profile loader를 새 public test seam으로 노출하지 않고 싶습니다. 그래야 구현을 바꿔도 외부 계약을 안정적으로 유지할 수 있습니다.
99. 유지보수자로서, 기존 ABI probe를 bundle regression 확인에 계속 사용할 수 있길 원합니다. 그래야 이를 새 제품 seam으로 오해하지 않고 로딩 회귀를 잡을 수 있습니다.
100. QA 담당자로서, Safety Gate에서 identity·HDR·alpha·render window·오류 계약을 확인하고 싶습니다. 그래야 시각 품질 전에 프레임 안전성을 보장할 수 있습니다.
101. QA 담당자로서, Model Gate에서 PSF·MTF·RMS·covariance·geometry·energy를 확인하고 싶습니다. 그래야 효과가 단순히 보이는 것을 넘어 정한 모델 행동을 지키는지 알 수 있습니다.
102. QA 담당자로서, Parity Gate에서 CPU/Metal·해상도·Render Scale·seek 순서를 비교하고 싶습니다. 그래야 실행 경로에 따라 룩이 바뀌지 않습니다.
103. 사용자로서, Aesthetic Gate에서 실제 RAW/Log 장면을 100% 확대와 정상 재생으로 비교하고 싶습니다. 그래야 수치만 맞는 부자연스러운 결과를 거부할 수 있습니다.
104. 사용자로서, 기본·강함·극단값을 각각 확인하고 싶습니다. 그래야 자연스러운 기본값뿐 아니라 알고리즘의 붕괴 지점도 찾을 수 있습니다.
105. 사용자로서, 피부·야간 practical·포화 LED·역광 머리카락·미세 질감·그래픽이 포함된 기준 릴을 보고 싶습니다. 그래야 장면별 실패를 놓치지 않습니다.
106. QA 담당자로서, 모든 수치 기준의 provenance가 standard·measured·internal tolerance·placeholder 중 하나로 표시되길 원합니다. 그래야 내부 목표를 실제 재료의 법칙으로 오해하지 않습니다.
107. QA 담당자로서, placeholder가 measured profile의 합격 근거로 사용되지 않길 원합니다. 그래야 실측 전 임시값이 제품 주장이 되지 않습니다.
108. 유지보수자로서, 외부 camera-original을 저장소에 재배포하지 않고 URL·hash·취득일·변환만 기록하고 싶습니다. 그래야 라이선스 위험 없이 QA를 재현할 수 있습니다.
109. 유지보수자로서, 자체 생성 synthetic fixture와 ground-truth mask를 저장소에서 재현하고 싶습니다. 그래야 저작권에 의존하지 않는 Model Gate를 운영할 수 있습니다.
110. 사용자로서, 실제 Resolve 무료판에서 설치·검색·Inspector·재생·저장·재열기·최종 렌더가 모두 승인되길 원합니다. 그래야 headless 테스트가 놓치는 호스트 문제를 방지할 수 있습니다.
111. M3 Pro 사용자로서, 각 효과가 UHD 시간·메모리 예산을 충족하길 원합니다. 그래야 고급 모델을 실제 편집과 그레이딩에 사용할 수 있습니다.
112. 사용자로서, 여러 효과를 독립적으로 품질 승인하고 싶습니다. 그래야 다섯 효과 동시 실시간 성능이 각 효과의 완성을 막지 않습니다.
113. 사용자로서, 권장 노드 순서를 확인하고 싶습니다. 그래야 광학 효과 뒤에 할레이션과 그레인을 배치하는 등 물리적 발생 순서에 가까운 결과를 얻습니다.
114. 사용자로서, calibration되지 않은 profile이 Generic 또는 Uncalibrated로 명확히 표시되길 원합니다. 그래야 실제 필름·필터·렌즈 재현과 혼동하지 않습니다.
115. 유지보수자로서, 특정 profile이 measured 상태로 승격될 때 측정 자산·조건·곡선 추출 이력을 추적하고 싶습니다. 그래야 profile의 출처와 재현성을 감사할 수 있습니다.
116. 사용자로서, 다섯 효과가 상용 제품을 복제하지 않고도 일관된 고급 품질을 제공하길 원합니다. 그래야 독립적인 개인용 무료판 보완 효과로 안심하고 사용할 수 있습니다.

## Implementation Decisions

### 제품·호스트 범위

- v2는 Apple Silicon arm64와 DaVinci Resolve 무료판을 위한 개인용 macOS 네이티브 OpenFX 빌드입니다.
- 하나의 설치 패키지 안에서 다섯 설치형 효과를 독립적으로 유지합니다. 일체형 룩이나 효과 chain으로 합치지 않습니다.
- 기존 다섯 effect ID와 bundle identifier를 안정적으로 유지하고 plugin major version을 2로 올립니다.
- v1 번들은 설치 전 별도 백업합니다. v2 안에는 legacy algorithm mode, 설정 자동 변환, backward-compatibility shim을 추가하지 않습니다.
- Studio 전용 기능, DCTL, Fusion 매크로와 워터마크 우회에 의존하지 않습니다.
- 카메라 Log 변환은 Resolve가 담당합니다. 플러그인은 카메라 모델, Log curve 또는 입력 색공간을 자동 감지하지 않습니다.
- 모든 효과는 explicit Working Mode를 유지합니다. v2 필수 모드는 DWG / Intermediate, DWG / Linear, Rec.709 / Gamma 2.4입니다.
- 사용자는 각 효과를 독립 노드에 배치합니다. 문서상 권장 순서는 Lens Reflections·Mist·Optical Blur 이후 Halation, 마지막 Film Grain입니다.

### 테스트 seam과 모듈 경계

- 자동 행동 검증의 유일한 public seam은 기존 `render(RenderRequest, RenderBackend) -> RenderSubmission`입니다. 입력 요청, 반환 상태와 완료 후 destination frame에서 외부 행동을 관찰합니다.
- CPU RenderBackend와 Metal RenderBackend는 같은 seam의 두 실제 adapter입니다.
- 내부 effect compiler, color conversion, source isolation, scatter, PSF, grain synthesis, profile lookup, pass scheduling과 memory arena는 새 public test seam으로 노출하지 않습니다.
- 실제 설치·효과 검색·Edit/Color 적용·Inspector·캐시·탐색·재생·렌더·미학적 품질은 Resolve Free Host Acceptance에서만 승인합니다. 가짜 OFX 호스트를 만들지 않습니다.
- 기존 ABI probe는 bundle export·로딩 regression을 확인하는 보조 검사로 유지할 수 있지만 제품 행동을 정의하는 새 seam은 아닙니다.

### 렌더 코어 구조

- host의 flat parameter values는 렌더 시작 전에 validated, normalized, render-ready typed effect variant로 한 번만 컴파일합니다.
- typed effect variant는 공통 plan과 Halation, Grain, Mist, Optical Defocus, Lens Reflections 중 정확히 하나의 effect plan을 가집니다.
- backend는 parameter ID, preset 이름, UI label, 상표명 또는 Working Mode 의미를 다시 해석하지 않습니다.
- shared Color Pipeline은 transfer와 gamut 변환, scene-linear decode/encode, exposure metric과 signed negative residual 처리를 담당합니다.
- shared Optics Primitives는 source isolation, multi-scale scatter, frequency shaping, field PSF projection, ghost element projection과 grain synthesis를 담당하되 렌더 seam 뒤에 숨깁니다.
- shared Frame Arena는 command completion 전 자원을 재사용하지 않으며, lifetime이 겹치지 않는 scratch를 alias하고 저해상도 pyramid와 단일채널 matte를 사용합니다.
- 효과별 profile은 렌더 준비 시 펼쳐지며 CPU와 Metal이 동일한 profile data와 quality policy를 사용합니다.
- CPU 구현을 reference adapter로 먼저 완성하고 Model Gate와 Aesthetic Gate의 golden behavior를 승인한 뒤 Metal adapter를 구현합니다.
- Metal shader는 런타임 C++ raw string으로 컴파일하지 않고 사전 컴파일된 `.metal` library와 pipeline cache로 제공합니다.
- CPU와 Metal의 effect math는 독립적인 임의 상수 집합을 갖지 않습니다. profile schema, parameter layout, sample sequence와 provenance metadata를 공유합니다.

### 공통 색·알파·공간 계약

- 광량 기반 branch는 명시된 Working Mode에서 scene-linear canonical domain으로 변환해 계산하고 원래 Working Mode로 복원합니다.
- Grain은 별도의 exposure/density response domain에서 합성하되 공통 색 pipeline을 통해 입출력합니다.
- transfer와 gamut을 하나의 암묵적 gamma 이름으로 섞지 않습니다.
- 음수 RGB와 1.0 초과 HDR을 조기에 clamp하지 않습니다. 방사 source 분석에서 제외한 signed negative residual은 최종 합성에서 보존합니다.
- straight와 premultiplied alpha를 명시적으로 처리하고 출력 alpha bit pattern을 유지합니다.
- identity는 색 decode, unpremultiply, 분석과 효과 pass보다 먼저 판정합니다.
- 모든 spatial radius와 field coordinate는 data window와 render scale을 반영하는 canonical frame coordinate로 정의합니다.
- scatter와 blur는 data-window edge 계약을 따르고 ghost의 화면 밖 energy는 wrap하지 않습니다.
- diagnostic view는 Mix 전 straight canonical result에서 생성하며 입력 alpha를 유지합니다.

### 공통 Inspector·프리셋·프로파일

- 각 효과의 Inspector를 Basic, Advanced, Diagnostics로 나눕니다. 필요하면 Advanced 안에 Source, Shape, Spectrum, Lens, Tone, Detail, Quality 하위 그룹을 둡니다.
- Basic에는 Preset, 3~5개의 핵심 제어와 Mix를 우선 노출합니다.
- profile이나 mode에 해당하지 않는 제어는 host에서 비활성화하거나 숨깁니다.
- parameter metadata는 group, display order, 조건부 활성화, semantic role, display range, 정밀도와 도움말을 single source of truth로 가집니다.
- preset은 profile과 자연스러운 Basic 값을 선택하지만 Working Mode, Output View와 Mix를 바꾸지 않습니다.
- 측정되지 않은 필름·필터·렌즈에는 제조사명과 제품명을 쓰지 않고 Generic family 이름을 사용합니다.
- measured profile만 실제 stock·filter·lens 이름과 실제 단위 제어를 사용할 수 있습니다. 사용 전 자산 권리와 추적성을 확인합니다.
- 모든 model pass number는 `standard`, `measured`, `internal tolerance`, `placeholder` 중 하나의 provenance를 가집니다.
- `standard`는 표준이 직접 정의하는 측정이나 불변조건, `measured`는 고정된 자산과 조건에서 얻은 profile envelope, `internal tolerance`는 회귀와 backend 일치를 위한 프로젝트 한계, `placeholder`는 calibration 전 임시 목표입니다.
- placeholder는 실제 필름·필터·렌즈의 물성이나 상용 품질 보증으로 표현하지 않으며 measured profile 승인에 사용할 수 없습니다.

### Halation v2

- 기존 RGB 공통 blur 후 warm tint 모델을 교체합니다.
- source isolation은 exposure, source color와 background brightness를 고려하고 threshold 전환을 부드럽게 만듭니다.
- Local Halo와 Global Glare를 별도 branch로 계산합니다. 두 branch는 실제 필름의 독립된 물리층이라고 주장하지 않는 저차 근사입니다.
- channel/record별 scatter kernel과 energy를 profile에 저장합니다. 실측 전 기본 profile은 Generic Warm Halation으로 표시합니다.
- highlight core protection과 background adaptation을 필수로 적용합니다.
- Blue Compensation은 공개 stock 상수가 아니라 source detection과 예술적 반응을 조절하는 profile-relative control입니다.
- Final, Halation Only, Local Only, Global Only, Source Mask 진단 출력을 제공합니다.
- `No Remjet`, `No Backing` 또는 rem-jet 부재가 강한 halation을 뜻한다고 암시하는 프리셋을 금지합니다.
- 강한 미측정 룩이 필요하면 `Strong Halo (Uncalibrated)`처럼 provenance를 이름에 드러냅니다.
- 실측 전 channel radius ratio와 energy ratio는 placeholder sanity envelope일 뿐 실제 stock 기준이 아닙니다.

### Film Grain v2

- 기존 counter-based Philox frame/seed 결정성과 render-order independence를 유지합니다.
- Grain profile을 Stock Response, Capture Format, Processing Modifier와 Display Scale로 분리합니다.
- Stock Response는 density/exposure에 따른 RMS, color record별 MTF, covariance와 distribution 성격을 소유합니다.
- Capture Format은 exposed image dimensions 또는 gate, scan sampling과 final magnification을 통해 체감 grain scale을 결정합니다.
- Processing Modifier는 measured calibration이 없으면 generic modifier로만 제공하며 실제 push/pull stock 재현을 주장하지 않습니다.
- Film Resolution branch와 grain sharpness/softness branch를 분리합니다.
- fine·medium·coarse population과 제한된 clumping을 사용하고, 완전 독립 RGB single-pixel noise를 피합니다.
- 노출 끝점에서 hard clipping 없이 grain contribution이 자연스럽게 감쇠합니다.
- 동일 seed·frame·settings는 CPU 재렌더에서 bit-identical해야 하며 frame access order에 의존하지 않습니다.
- 제품명 profile은 곡선 원본 revision, record, sampling, digitization error와 권리 정보를 추적할 수 있을 때만 허용합니다.
- RMS, PSD, covariance를 서로 대체하지 않습니다. RMS는 표준 개념을 참조하고 PSD/covariance는 synthetic grain 품질의 내부 검사로 구분합니다.

### Mist Diffusion v2

- UI의 `Density`를 `Grade`로 변경합니다. 1/8·1/4·1/2·1·2는 선형 광학 배수가 아니라 profile strength 단계입니다.
- filter family는 trademark-free `Generic Black`, `Generic White`를 사용합니다.
- Glow, Veil, Detail을 서로 독립적인 branch로 처리합니다.
- Generic Black은 같은 내부 Grade의 Generic White보다 broad veil과 black lift가 작고 low-frequency black retention이 높아야 합니다.
- Generic White는 더 넓은 highlight glow와 더 큰 veil·contrast reduction을 허용합니다.
- Detail branch는 고주파 skin texture를 완화하되 eye·hair·fabric의 중간 주파수 edge acuity를 가능한 한 보존합니다.
- Grade 간 반경·에너지 비율은 실측 전 선형으로 고정하지 않습니다.
- profile calibration은 lens, focal length, T-stop, focus distance, source luminance/angle, sensor, decode, exposure와 white balance를 기록한 동일 조건 비교를 요구합니다.
- Final, Glow Only, Veil Only, Detail Difference, Source Mask 진단 출력을 제공합니다.

### Lens Reflections v2

- 전체 highlight matte를 여러 번 affine warp하는 현재 모델을 폐기하고 source별 element chain을 구성합니다.
- 자동 source isolation은 scene-linear luminance, Max RGB 또는 per-channel 반응을 선택할 수 있고, source별 centroid, extent, channel energy와 clipping flag를 생성합니다.
- 자동 검출은 같은 프레임만으로 결정되며 과거 프레임의 상태에 의존하지 않습니다.
- Manual Source 지정과 외부 matte 입력을 필수 fallback으로 제공합니다. 자동 검출만으로 정답을 보장하지 않습니다.
- 각 lens profile은 ghost element마다 signed axis position `k`, magnification, defocus, aperture clipping, ring/falloff, spectral attenuation, dispersion, energy와 background adaptation을 소유합니다.
- optical-axis collinearity와 연속성은 공통 불변조건이지만 모든 element의 `k=-1`을 가정하지 않습니다.
- focused source-like ghost는 허용합니다. 결함은 source resemblance 자체가 아니라 모든 source를 같은 불투명 warp로 복사하거나 profile·attenuation·defocus·background adaptation 없이 붙이는 것입니다.
- source pattern을 보존하는 focused element와 aperture-shaped defocused element를 진단 출력과 QA에서 모두 허용합니다.
- generic profile은 Clean, Vintage, Anamorphic 같은 artistic family로 표시하며 실제 렌즈명·focal length·T-stop 정확 재현을 주장하지 않습니다.
- Final, Source Map, Ghost Paths, Elements Only와 element solo 진단 출력을 제공합니다.

### Optical Blur v2

- v2 필수 범위는 depth가 없는 uniform defocus와 field-dependent generic PSF입니다.
- depth map 없이 Depth of Field, real focus distance, near/far occlusion 또는 실제 rack focus를 주장하지 않습니다.
- aperture blades, roundness, rotation, anamorphism과 highlight response를 유지합니다.
- screen field와 azimuth에 따라 effective pupil clipping과 cat-eye를 계산하고 tile 간 PSF coefficient를 연속적으로 보간합니다.
- Center/Rim Bias, coma/astigmatism과 chromatic aberration은 generic artistic controls로 제공합니다.
- 각 channel PSF는 에너지를 정규화하고 optical vignetting과 highlight gain을 별도 제어로 구분합니다.
- 작은 radius는 deterministic full-resolution gather, 큰 radius는 prefiltered source와 고정 sample budget을 사용할 수 있습니다.
- Preview, Balanced, Final은 deterministic quality policy를 사용하며 같은 quality에서 CPU와 Metal sample sequence를 공유합니다.
- selective matte 또는 외부 depth 입력은 필수 범위가 아닙니다. 추후 추가하더라도 depth와 occlusion 계약이 생기기 전에는 DOF로 이름 붙이지 않습니다.
- Final, PSF Preview, Highlight Source Map과 필요 시 field diagnostic을 제공합니다.

### 성능·메모리

- wide scatter는 half·quarter·eighth-resolution pyramid를 사용하고 source matte는 단일채널 half precision을 우선합니다.
- full-resolution RGBA 복제본을 element 수만큼 생성하지 않습니다.
- Frame Arena는 command buffer 완료와 lifetime이 연결된 in-flight allocation을 사용하고 안정 상태에서 프레임별 불필요한 allocation을 피합니다.
- UHD 기본 프리셋의 Metal median 목표는 각 효과 83.33ms 이하, Film Grain 41.67ms 이하입니다.
- 1080p 기본 프리셋의 Metal median 목표는 각 효과 41.67ms 이하입니다.
- UHD 임시 메모리 목표는 Halation 160MiB 미만, Grain 64MiB 미만, Mist 220MiB 미만, Optical 192MiB 미만, Lens Reflections 256MiB 미만입니다.
- 8K와 12K는 정확성과 최종 렌더 안정성 대상이며 실시간 재생을 완료 조건으로 두지 않습니다.
- 다섯 효과 동시 UHD 실시간 재생은 v2 완료 조건이 아닙니다.

### 기준 자산과 provenance

- P0 fixture는 저장소에서 자체 생성 가능한 scene-linear EXR 또는 동등한 float source로 만듭니다.
- synthetic suite는 exposure/color ramp, flat fields, point source sweep, point grid, slanted edge, thin line, signage/LED pattern, alpha edge와 field PSF source를 포함합니다.
- 각 fixture manifest는 generator version, color encoding, resolution, frame/crop, expected mask와 metric provenance를 기록합니다.
- 외부 BRAW·ARRIRAW·X-OCN·R3D camera-original은 `.gitignore`된 local asset cache에 보관합니다.
- 저장소에는 외부 원본의 공식 URL, SHA-256, 취득일, 다운로드 당시 약관, clip/frame, decode와 color transform만 기록합니다.
- 다운로드 가능하다는 이유만으로 재배포 권리를 가정하지 않습니다.
- non-commercial dataset은 별도 상업 허가 없이 shipped fixture나 공개 QA archive에 포함하지 않습니다.
- 실물 film·mist·lens calibration asset은 stock/filter/lens, lab/scan 또는 camera, focal length, aperture, focus, source, exposure, white balance와 processing 조건을 함께 기록합니다.

## Testing Decisions

### 테스트 철학과 경계

- 좋은 자동 테스트는 내부 함수 호출 여부가 아니라 최상위 렌더 요청과 완료 후 destination frame에서 관찰되는 외부 행동을 검증합니다.
- 자동 테스트의 primary seam은 기존 `render(RenderRequest, RenderBackend) -> RenderSubmission` 하나입니다.
- 내부 primitive 단위의 public seam은 추가하지 않습니다. CPU/Metal adapter conformance가 필요해도 production render 경계를 통해 검증하는 것을 우선합니다.
- 실제 Resolve Free Host Acceptance는 설치·UI·호스트 상태·재생·미학을 검증하는 유일한 host surface입니다.
- 기존 효과별 render contract, Metal queue completion, Grain 통계, 해상도 비교와 performance benchmark를 prior art로 확장합니다.
- 기존 ABI probe는 bundle regression일 뿐 host acceptance나 product behavior의 대체물이 아닙니다.

### Safety Gate

- Final identity는 render window 안 RGBA float bit pattern이 source와 정확히 같고 render window 밖 destination byte를 보존해야 합니다.
- padding이 있는 row stride, non-zero data-window origin, odd dimensions와 cropped render window를 포함합니다.
- finite negative·neutral·1.0 초과 HDR 입력에서 출력은 finite여야 하며 의도치 않은 clamp가 없어야 합니다.
- straight와 premultiplied alpha, alpha 0과 부분 alpha를 모두 검사하고 출력 alpha는 bit-identical이어야 합니다.
- transparent edge의 RGB spill과 완전히 투명한 영역의 신규 효과 성분이 허용 한계 이하여야 합니다.
- invalid effect/settings, non-finite setting, 잘못된 stride·bounds·render window, aliased surfaces와 backend failure가 정의된 오류로 실패해야 합니다.
- Metal의 Enqueued 반환 뒤 같은 queue의 completion signal 이후에만 결과를 읽고 production 경로는 GPU 완료를 기다리지 않습니다.
- Preview·Balanced·Final과 모든 diagnostic view에서 메모리 범위와 alpha 계약을 유지합니다.

### Model Gate 공통

- 모든 metric은 provenance를 기록하고 placeholder를 measured truth로 해석하지 않습니다.
- standard가 측정 방법만 정의하는 경우 프로젝트의 pass threshold를 표준값이라고 부르지 않습니다.
- mathematical invariant는 constant-field preservation, finite energy, no-wrap, PSF normalization, monotonic controls와 diagnostic layer reconstruction을 포함합니다.
- measured profile gate는 고정된 자산 hash와 acquisition manifest가 있을 때만 활성화합니다.
- generic profile은 synthetic ground truth와 internal golden envelope로 회귀를 막되 실제 재료 정확 재현이라고 주장하지 않습니다.

### Halation Model Gate

- Source Mask는 threshold 아래의 neutral patch를 억제하고 threshold sweep에서 불연속적으로 튀지 않아야 합니다.
- Local Only와 Global Only의 합은 Halation Only와 정한 internal tolerance 안에서 일치해야 합니다.
- neutral highlight core의 재착색과 에너지 증가는 core protection의 internal tolerance 안에 있어야 합니다.
- 같은 source에서 밝은 배경의 visible halo impact는 어두운 배경보다 낮아야 합니다.
- local halo는 core 바깥에서 연속적으로 감쇠하고 hard red outline 또는 white bloom으로 붕괴하지 않아야 합니다.
- channel radius·energy 비율은 measured profile이 없을 때 placeholder sanity envelope로만 검사합니다.
- neutral, tungsten, blue LED와 saturated red source를 각각 포함합니다.

### Film Grain Model Gate

- 동일 seed·frame·settings의 CPU 재실행은 bit-identical해야 합니다.
- 임의 seek 순서와 subframe quantization에서 같은 output frame의 field가 일치해야 합니다.
- 인접 프레임 상관, 다중 프레임 mean bias, flat-field RMS, radial PSD, anisotropy, RGB covariance와 non-DC peak를 측정합니다.
- exposure/color flat-field suite에서 Stock Response별 RMS와 record response가 profile envelope 안에 있어야 합니다.
- Capture Format, scan sampling과 display scale 변경이 canonical grain scale에 일관되게 반영돼야 합니다.
- 1080p·UHD·8K에서 particle diameter와 PSD의 해상도 일관성을 검사합니다.
- Film Resolution 변화와 Grain Softness 변화가 서로 다른 관찰 가능한 결과를 만들어야 합니다.
- 같은 seed/frame의 CPU/Metal 결과를 비교하고 ensemble statistics와 pixel parity를 별도 기록합니다.

### Mist Model Gate

- Glow Only, Veil Only와 Detail Difference가 Final contribution을 internal tolerance 안에서 재구성해야 합니다.
- 같은 Grade에서 Generic White의 broad veil은 Generic Black보다 크고 Generic Black의 low-frequency black retention은 더 높아야 합니다.
- Grade 증가에 따라 glow radius·encircled energy·veil·detail softening이 profile이 정의한 방향으로 연속적으로 변해야 합니다.
- 동일 촬영 조건의 measured profile이 없을 때 Black/White 비율과 MTF pass number는 placeholder로 유지합니다.
- point-source PSF, dark patch lift, local contrast, slanted-edge relative MTF, skin high-frequency band와 eye/hair mid-frequency edge를 분리 측정합니다.
- 중성 profile의 hue shift는 display transform과 peak luminance가 고정된 경우에만 display-referred color metric을 사용합니다.

### Lens Reflections Model Gate

- synthetic multi-source fixture의 자동 검출에 precision/recall, centroid error, source energy error와 threshold continuity를 기록합니다.
- Manual Source와 external matte가 자동 검출을 확실히 대체하거나 제한해야 합니다.
- 모든 ghost centroid는 source와 optical center가 정의하는 축에 놓이고 source 이동에 연속적으로 반응해야 합니다.
- profile별 signed `k`와 magnification은 각 profile의 golden envelope로 검증하며 보편적인 `k=-1`을 요구하지 않습니다.
- focused source-like ghost와 aperture-shaped defocused ghost를 모두 유효한 element 형태로 허용합니다.
- 각 element의 energy, falloff, background adaptation과 no-wrap을 검사합니다.
- 밝은 signage, clipped white, saturated R/G/B LED, fine LED array, bright window와 specular source를 분리 fixture로 둡니다.
- 과거 frame에 의존하지 않는 동일-frame 결정성과 random seek 안정성을 검사합니다.

### Optical Blur Model Gate

- field·azimuth·defocus와 channel을 sweep해 PSF energy, centroid, second moment, axis ratio와 center/rim profile을 기록합니다.
- constant field는 highlight gain 0에서 정한 internal tolerance 안에 보존돼야 합니다.
- center에서 corner로 이동할 때 cat-eye와 aberration이 연속적으로 변화하고 tile seam이 없어야 합니다.
- aperture geometry는 analytic target과 비교하되 IoU threshold는 internal tolerance로 표시합니다.
- chromatic aberration 0에서 channel centroid가 정렬되고 parameter sweep에서 separation이 단조 증가해야 합니다.
- 1080p·UHD·8K와 Render Scale에서 normalized second moment와 field behavior를 비교합니다.
- 동일 quality에서 CPU와 Metal의 sample sequence, PSF centroid와 energy가 internal parity tolerance 안에 있어야 합니다.
- depth/occlusion fixture는 depth 기능이 실제 scope에 추가되기 전에는 합격 기준이나 DOF 주장에 사용하지 않습니다.

### Parity Gate

- 모든 Working Mode, profile/preset, diagnostic view와 quality mode를 pairwise matrix에 포함합니다.
- 숫자 parameter의 min·default·strong·max와 mode/profile 조합을 표본화합니다.
- deterministic effect의 CPU/Metal 최대·평균 절대 오차를 기록하며 threshold는 internal tolerance로 관리합니다.
- PSF centroid·energy, Grain same-frame field, resolution scaling과 render-scale behavior를 pixel difference와 별도로 비교합니다.
- identity는 tolerance 비교가 아니라 bit-exact로 유지합니다.
- fast Metal approximation도 pixel parity뿐 아니라 같은 Model Gate를 통과해야 합니다.

### Aesthetic Gate와 Resolve Free Host Acceptance

- 실제 Resolve 무료판에서 bundle 설치, 다섯 효과 검색, Edit/Color 적용, Inspector grouping, parameter enable/disable, preset·reset·Custom 상태를 확인합니다.
- Studio badge, watermark, DCTL 요구 없이 preview와 deliver가 완료돼야 합니다.
- 프로젝트 저장·종료·재열기, cache clear, random seek, reverse seek, scrub와 반복 render를 확인합니다.
- Baseline, Effect Only, Mask/Elements와 Final을 float 또는 16-bit half reference로 비교합니다.
- 기본·강함·극단값을 분리하고 기본 프리셋의 승인과 stress behavior의 승인을 혼동하지 않습니다.
- 최소 다섯 실제 RAW/Log 장면에서 100% pixel view와 최종 시청 배율, 정지와 정상 재생을 모두 확인합니다.
- 기준 릴은 피부·눈·머리카락, 창문·야간 practical, tungsten, saturated LED·neon, 역광, shadow, fine textile, 흰 그래픽, frame-edge와 off-screen source를 포함합니다.
- 사용자가 보유한 상용 효과와 blind A/B를 할 수 있지만 품질 기준 참고로만 사용하고 pixel 복제나 내부 구현 추정은 하지 않습니다.
- 스크린샷 차이·MAE·SSIM만으로 Aesthetic Gate를 통과시키지 않습니다.
- 최종 합격 질문은 광원·노출·배경과 화면 위치가 바뀌어도 같은 재료·렌즈 성격으로 보이는지입니다.

### 성능·메모리 Gate

- 기준 장비와 Resolve 설정, plugin build identifier, bundle hash, warm-up, 반복 횟수와 median 계산 방식을 manifest에 고정합니다.
- 개별 효과 기본 프리셋의 1080p·UHD Metal render time과 scratch peak를 측정합니다.
- 10개 warm frame 이후 steady allocation delta를 측정하고 command completion 전 arena 재사용이 없는지 확인합니다.
- 8K·12K는 정확성, finite output와 memory safety를 검증하되 실시간 threshold를 적용하지 않습니다.
- 최대 parameter는 실시간 완료 조건이 아니지만 crash·NaN·메모리 범위 위반을 허용하지 않습니다.

### Reference Asset Licensing Gate

- 자체 생성 fixture는 생성 절차와 source를 저장소에서 재현할 수 있어야 합니다.
- 외부 camera-original은 local-only cache에 보관하고 저장소에는 URL·hash·취득일·약관·frame/crop·decode 정보만 기록합니다.
- 다운로드 페이지가 존재한다는 사실을 재배포 허가로 해석하지 않습니다.
- non-commercial license 자산은 별도 허가 없이 shipped fixture, 공개 golden crop 또는 상용 QA archive로 사용하지 않습니다.
- measured profile은 reference asset의 권리와 provenance가 확인되지 않으면 Generic 상태를 벗어날 수 없습니다.

## Out of Scope

- DaVinci Resolve Studio 전용 기능, DCTL과 Fusion 매크로
- 카메라별 Log 변환, 카메라 자동 감지, Working Mode 자동 추정
- Windows, Linux, Intel Mac과 universal2 빌드
- 공개 배포, 코드 서명, 공증, installer와 자동 업데이트
- v2 내부의 legacy v1 algorithm mode, 자동 설정 migration과 backward-compatibility shim
- VHS 손상, Gate Weave, Flicker, dust/scratch, temporal repair와 noise reduction
- object removal, face correction, AI 기반 효과
- 실제 측정 없이 제조사 film stock·diffusion filter·lens 이름을 사용한 profile
- `No Remjet`, `No Backing` 또는 rem-jet 부재가 강한 halation을 뜻한다고 주장하는 프리셋
- 외부 film scan texture를 그대로 얹는 방식
- depth 입력 없는 실제 Depth of Field, near/far occlusion, rack focus와 focus-distance claim
- v2 필수 범위의 external depth map DOF와 occlusion-aware splatting
- calibrated real-lens focal length·T-stop·focus distance 제어
- 31-sample full spectral Halation, lens prescription 기반 full ray tracing과 profile editor
- 과거 frame 상태에 의존하는 temporal source tracking
- 다섯 효과 동시 UHD 24fps 실시간 재생 보장
- 가짜 OFX host, 내부 pass별 public 테스트 API와 새 공개 primitive seam
- 저작권 또는 라이선스가 확인되지 않은 camera-original·chart·dataset의 저장소 재배포
- 상용 플러그인의 내부 구현 추정, proprietary profile 추출과 pixel-level 복제

## Further Notes

- 이 명세는 기존 v1 구현 명세를 대체하는 v2 기능 명세이며, 구현 티켓을 생성하거나 소스 코드를 수정하지 않습니다.
- 공통 용어는 [프로젝트 CONTEXT](../../CONTEXT.md)를 따릅니다.
- 제품·색·패키지·렌더 경계 결정은 [ADR 0001](../../docs/adr/0001-native-openfx-effect.md), [ADR 0002](../../docs/adr/0002-resolve-owns-camera-colour-transform.md), [ADR 0003](../../docs/adr/0003-independent-effects-in-one-package.md), [ADR 0004](../../docs/adr/0004-apple-silicon-personal-build.md), [ADR 0005](../../docs/adr/0005-host-adapter-and-render-core.md)를 유지합니다.
- 현재 구현 계약과 수치 prior art는 [v1 구현 명세](../cbef-film-effects/spec.md)를 참고합니다.
- 효과별 물리 현상과 상용 제어의 1차 자료는 [유료급 필름·광학 효과 1차 자료 조사](../../docs/research/premium-film-effects-primary-sources.md)에 정리되어 있습니다.
- 공개 자료의 주장 범위, No Remjet 교정, Grain 축 분리, Mist Grade, signed ghost `k`, fixture 라이선스와 metric provenance는 [v2 심층 근거 보강](../../docs/research/premium-film-effects-deep-evidence.md)을 우선합니다.
- 현재 코드 감사, 성능 debt와 초기 아키텍처 범위는 [v2 유료급 품질 재설계 범위](../../docs/design/premium-film-effects-revision-scope.md)를 참고하되, 심층 근거 문서와 충돌하는 수치·이름은 이 명세가 교정합니다.
- 실제 RAW QA의 한계와 강한 설정에서 확인한 결함은 [RAW 효과 QA](../../docs/qa/raw-footage-effects-qa.md)와 [강한 효과 RAW QA](../../docs/qa/raw-footage-strong-effects-qa.md)를 참고합니다.
- 표준과 제조사 자료는 측정 정의와 관찰 가능한 방향성의 근거입니다. 공개 자료가 제공하지 않는 pass threshold를 표준 또는 실제 재료의 진실로 표현하지 않습니다.
- profile calibration으로 기본값이나 pass envelope를 바꿀 때는 구현 상수만 조용히 수정하지 않습니다. 명세, provenance, fixture manifest, automated gate와 Resolve evidence를 함께 갱신합니다.
- Headless Render Contract 통과는 Resolve 무료판 호환성과 Aesthetic Gate를 대신하지 않습니다. 사용자 시각 승인도 Safety·Model·Parity Gate를 대신하지 않습니다.
- 다음 흐름은 `/to-tickets`로 이 명세를 blocking edge가 있는 tracer-bullet 구현 티켓으로 나누는 것입니다. 이 명세 작성 단계에서는 티켓을 만들지 않습니다.
