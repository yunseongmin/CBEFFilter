# CBEF Film Effects v2 심층 근거 보강

- 작성일: 2026-08-12
- 목적: 기존 [1차 자료 조사](premium-film-effects-primary-sources.md)와 [v2 재설계 범위](../design/premium-film-effects-revision-scope.md)에서 **구현·합격 기준을 실제로 바꾸는 근거 공백**만 보강한다.
- 출처 원칙: 제조사 기술자료·공식 제품 문서·표준 원문 페이지·원 연구 논문/공식 데이터셋·카메라 제조사 다운로드 페이지만 사용한다.
- 표기: **직접**은 출처가 명시한 사실, **추론**은 직접 사실에서 도출한 설계 판단, **미해결**은 공개 자료로 확정할 수 없는 항목이다.
- 제한: 공개 자료는 관찰 가능한 응답과 측정 방법의 근거일 뿐이다. 제조사의 비공개 필름/필터/렌즈 내부 계수나 상용 플러그인의 구현을 추정하지 않는다.

## 1. Executive delta: 기존 v2 설계에서 달라지는 것

### 1.1 확인(Confirm)

1. **Halation을 RGB 공통 blur 뒤의 tint로 만들면 부족하다는 방향은 유지한다.** Kodak의 현행 처리 자료는 노출광 기준으로 blue-sensitive emulsion → yellow filter → green-sensitive emulsion → interlayer → red-sensitive emulsion → base → anti-halation 구조를 명시한다. 따라서 층·파장·산란을 전혀 구분하지 않는 warm bloom보다 층별 응답 모델이 타당하다. 단, 이 층 순서만으로 채널별 반경과 에너지 숫자까지 결정할 수는 없다. ([Kodak ECN-2 Processing, Module 7](https://www.kodak.com/content/products-brochures/Film/Processing-KODAK-Motion-Picture-Films-Module-7.pdf))
2. **Grain은 노출과 color record에 따라 다뤄야 한다.** Kodak 현행 Vision3 자료는 density에 따라 읽는 RMS granularity 곡선, RGB sensitometric curve, RGB MTF curve를 각각 제공하고, 48 μm aperture로 granularity를 읽는 방법을 설명한다. ([50D 5203/7203](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-50D-5203-7203-technical-information.pdf), [250D 5207/7207](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-250D-5207-7207-technical-information.pdf), [200T 5213/7213](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-200T-5213-7213-technical-information.pdf), [500T 5219/7219](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-500T-5219-7219-technical-information.pdf))
3. **Mist의 glow/veil/detail 분리는 유지한다.** Tiffen은 Pro-Mist가 fine detail을 부드럽게 하고 contrast를 낮추며 highlight에 localized flare를 더하고, Black Pro-Mist는 유사한 효과에서 contrast 감소를 덜 하고 blacks를 더 유지한다고 직접 구분한다. ([Tiffen Pro-Mist 비교](https://tiffen.com/collections/explore-pro-mist%C2%AE-and-black-pro-mist-camera-filters))
4. **Lens ghost와 bokeh를 field/source 반응형으로 만들 방향은 유지한다.** 물리 기반 flare 연구는 각 ghost가 특정 렌즈 표면 쌍의 반사 경로에서 나오며 aperture clipping과 코팅·파장 응답을 거친다고 모델링한다. Nikon은 실제 렌즈의 spherical aberration, coma, astigmatism, field curvature, chromatic aberration을 wavefront로 측정하고 그 데이터를 image simulation에 사용한다고 설명한다. ([Hullin et al., Physically-Based Real-Time Lens Flare Rendering](https://resources.mpi-inf.mpg.de/lensflareRendering/), [Nikon OPTIA](https://www.nikon.com/company/technology/stories/1909_optia/))

### 1.2 변경(Change)

1. **`No Remjet / Strong` 또는 `No Backing` 프리셋을 삭제·개명한다.** 2026년 Kodak Vision3 50D·250D·200T·500T 기술자료는 모두 “anti-halation undercoat replaces the traditional remjet backing layer”라고 명시한다. 즉 rem-jet 부재는 anti-halation 부재와 동의어가 아니다. 공개 실측 없이 `No Remjet = 강한 halation`을 제품 규칙으로 만들 수 없다. 권장 명칭은 `Strong Halo (Uncalibrated)`이며, 실제 backing 제거 촬영을 확보하기 전에는 stock 성격을 주장하지 않는다. ([Kodak Vision3 기술자료 4종](https://www.kodak.com/en/motion/page/filmmaker-resources/))
2. **Grain의 `Format`과 `Stock Response`를 분리한다.** 같은 500T 5219/7219가 65 mm, 35 mm, 16 mm, Super 8로 공급되며 제품 기술곡선은 emulsion stock 기준이다. 따라서 stock/노출/처리가 density-RMS·MTF·색 기록 응답을 정하고, 포맷은 촬영 면적과 최종 표시 크기까지의 확대율을 통해 체감 grain scale을 정하는 별도 축으로 취급해야 한다. ([Kodak 500T 기술자료](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-500T-5219-7219-technical-information.pdf), [Kodak Motion Picture Products Catalog](https://www.kodak.com/content/pdfs/motion/Kodak-Motion-Picture-Products-Price-Catalog-US.pdf))
3. **일반 lens ghost에 `k = -1` 대칭을 강제하지 않는다.** BracketFlare 논문은 paraxial transfer matrix에서 일반적으로 `h₁ = k h₀`이며 source–ghost 선이 optical center를 지난다고 도출한 뒤, 조사한 스마트폰 주 카메라의 focused reflective spot에서는 `k ≈ -1`을 관찰했다. 이는 모든 다요소 시네 렌즈와 모든 ghost element의 보편 상수가 아니다. v2는 profile element별 signed `axis_position(k)`를 유지하고, collinearity/연속성만 공통 불변조건으로 둔다. ([Dai et al., CVPR 2023](https://openaccess.thecvf.com/content/CVPR2023/papers/Dai_Nighttime_Smartphone_Reflective_Flare_Removal_Using_Optical_Center_Symmetry_Prior_CVPR_2023_paper.pdf))
4. **Focused ghost가 source 실루엣을 닮는 것 자체를 실패로 판정하지 않는다.** BracketFlare는 focused reflective flare가 밝은 source의 패턴을 보존할 수 있고 LED 배열의 세부까지 나타날 수 있다고 보고한다. 실패 기준은 “복제상 존재”가 아니라, 모든 source를 같은 불투명 warp로 복사하거나 profile·defocus·spectral attenuation·background adaptation 없이 붙이는 것이다. ([Dai et al., CVPR 2023](https://openaccess.thecvf.com/content/CVPR2023/papers/Dai_Nighttime_Smartphone_Reflective_Flare_Removal_Using_Optical_Center_Symmetry_Prior_CVPR_2023_paper.pdf))
5. **Mist의 `Density`를 물리 광학 밀도처럼 취급하지 말고 `Grade`로 표시한다.** Tiffen, Hoya, Schneider의 1/8·1/4·1/2·1·2 표기는 제품 계열의 strength 단계이며, 공개 자료에는 제조사 간 공통 전달함수나 선형 배수 정의가 없다. 서로 다른 제조사의 white/black 계열을 하나의 숫자 축으로 정밀 대응시키지 않는다. ([Tiffen Diffusion Guide](https://tiffen.com/pages/diffusion-guide), [Hoya White Mist](https://hoyafilterusa.com/products/hoya-white-mist), [Schneider Hollywood Black Magic](https://schneiderkreuznach.com/application/files/8516/8024/4715/Fact_Sheet_Hollywood_Black_Magic_Schneider-Kreuznach.pdf))

### 1.3 약화(Weaken)

다음 수치는 **좋은 초기 engineering target일 수는 있으나 외부 근거로 “실제 필름/필터/렌즈 기준”이라고 주장할 수 없다.** 측정 fixture를 확보할 때까지 `provisional`로 표시한다.

| 현재 v2 수치 | 판정 | 이유 |
|---|---|---|
| Halation `R radius / B radius ≥ 1.5`, `R/G ≥ 1.25`, core energy ≤10% | placeholder | Kodak 공개 자료는 층 순서·sensitometry·MTF는 제공하지만 현행 stock의 halation-only spectral PSF를 제공하지 않는다. |
| Mist White shadow lift ≥ Black의 1.7배, Black 1/8 lift ≤2%, Black 1 lift ≤8% | placeholder | 제조사 자료는 상대적 방향만 설명하며 transfer curve나 black-lift 수치를 공개하지 않는다. |
| Mist MTF 0.1 cyc/px에서 Black 85%, White 75% | placeholder | 카메라·렌즈·조리개·초점·샘플링 조건 없는 normalized digital MTF 수치는 실제 필터 자료와 직접 연결되지 않는다. |
| Ghost collinearity 1.5 px/대각 0.05%, element energy ±3% | internal tolerance | 물리 불변조건을 자동화하는 유용한 회귀 한계지만 외부 표준값은 아니다. |
| Optical PSF energy ±0.5%, cat-eye axis ratio ±5% | internal tolerance | energy normalization은 방어 가능한 불변조건이나 허용오차와 profile target은 프로젝트가 정한 값이다. |
| `ΔEITP ≤ 2` | 조건부 | ΔEITP 계산 자체는 ITU-R BT.2124에 근거하지만 scene-referred 신호에는 nominal peak display luminance가 필요하다. 작업 선형값에 바로 적용하면 안 된다. ([ITU-R BT.2124](https://www.itu.int/rec/R-REC-BT.2124-0-201901-I/en)) |
| CPU/Metal max abs `2e-4`, SSIM `0.999` | internal regression | 구현 parity와 변경 탐지에는 적절하지만 실제 광학 충실도나 미학을 보증하지 않는다. |

### 1.4 미해결(Unresolved)

- 현행 Vision3 stock별 halation-only **spectral PSF/LSF, 총 산란 에너지, 노출별 반경**은 공개 1차 자료에서 확인하지 못했다.
- Tiffen Pro-Mist/Black Pro-Mist 또는 Hoya White/Black Mist의 **동일 광학 조건 MTF, PSF, veiling glare transfer curve**는 제조사 공개 자료에서 확인하지 못했다.
- 공개 camera-original 샘플은 workflow 평가 목적을 명시하지만, 대부분 **저장소 재배포·golden crop 공개** 권리는 명시하지 않는다. 원본은 로컬 QA 자산으로만 쓰고 manifest에는 URL·hash·변환만 기록해야 한다.
- calibrated real-lens flare/PSF profile을 만들 lens prescription 또는 field PSF 측정 세트는 확보되지 않았다. 따라서 `Vintage`, `Clean`, `Anamorphic`은 generic artistic profile이며 실제 렌즈명·focal length·T-stop 정확 재현으로 광고할 수 없다.

## 2. Halation: 층 구조가 증명하는 것과 증명하지 않는 것

### 2.1 직접 근거

- Kodak ECN-2 처리 문서의 color negative 단면은 red-sensitive emulsion이 base 바로 위에 있고 anti-halation 구조가 base 뒤쪽에 있음을 보여 준다. ([Kodak ECN-2 Processing, Module 7](https://www.kodak.com/content/products-brochures/Film/Processing-KODAK-Motion-Picture-Films-Module-7.pdf))
- Kodak은 현행 Vision3 네 stock에서 traditional rem-jet 대신 anti-halation undercoat를 사용한다고 명시한다. 따라서 현재 stock을 `rem-jet 유무`만으로 halation 강도 분류하면 안 된다. ([50D](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-50D-5203-7203-technical-information.pdf), [250D](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-250D-5207-7207-technical-information.pdf), [200T](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-200T-5213-7213-technical-information.pdf), [500T](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-500T-5219-7219-technical-information.pdf))
- Kodak의 색층 설명은 top/blue, middle/green, bottom/red-sensitive layer와 각 층에서 형성되는 dye를 설명한다. 이것은 reverse/scattered light가 만나는 층 순서를 논할 근거지만, 산란광의 파장 분포나 각 층의 재노출량을 숫자로 주지는 않는다. ([Kodak, Exploring the Color Image](https://www.kodak.com/content/products-brochures/Film/Exploring-the-Color-Image.pdf))
- photographic emulsion의 MTF를 absorption/scattering coefficient와 radiative transfer로 계산한 원 연구는 base–air interface의 halation이 측정 MTF 차이에 기여한다고 보고한다. 이는 halation을 장거리 산란 tail이 포함된 image-spread 문제로 다룰 근거다. ([Wolfe, Marchand & DePalma, JOSA 1968](https://opg.optica.org/abstract.cfm?uri=josa-58-9-1245))

### 2.2 설계 추론

1. `local halo + global glare` 두 branch는 유효한 저차 근사지만, 둘이 실제 stock의 두 독립 물리층이라고 표현하지 않는다.
2. RGB 3개 Gaussian의 고정 순서를 “spectral film truth”로 고정하지 않는다. `FilmResponseProfile`이 채널/record별 energy와 scatter kernel을 담되 기본값은 `generic warm halation`으로 표기한다.
3. source color가 saturated blue일 때 red halo가 얼마인지 공개 자료만으로 확정할 수 없으므로 `Blue Compensation`은 물리 상수가 아니라 artistic/source-detection control이다.
4. 측정 전 합격 기준은 비율보다 구조적 불변조건으로 바꾼다: core 재착색 방지, source threshold 연속성, local/global 진단 합성 일치, HDR energy 유한성, 해상도/Render Scale 불변성.

### 2.3 권장 수정

- 프리셋: `35mm Subtle`, `16mm Edge Rich`, `No Backing / Strong` 대신 `Generic Subtle`, `Generic Edge Rich`, `Strong Halo (Uncalibrated)`.
- 파라미터 도움말: `Red Bias`에 “공개 stock 측정값이 아닌 profile-relative control”을 명시한다.
- golden envelope: 촬영/스캔 reference 확보 전에는 R/G/B 비율을 승인 수치가 아니라 넓은 sanity bound로만 사용한다.
- 실제 halation calibration fixture는 동일 stock의 정상 anti-halation 구조와 의도적으로 backing 조건을 바꾼 대조군을 같은 처리·스캔으로 촬영해야 한다. stock·lab·scanner가 다르면 차이를 halation 하나로 귀속하지 않는다.

## 3. Film Grain: stock, exposure, format을 분리한다

### 3.1 직접 근거

- ISO 10505:2009는 photographic film의 intrinsic RMS granularity를 developed image-forming centres 분포가 만든 density fluctuation으로 정의하며, color/dye materials도 포함한다. Wiener/noise power spectrum은 이 표준 범위 밖이다. 즉 RMS와 PSD는 서로 대체가 아니라 보완 지표다. ([ISO 10505:2009](https://www.iso.org/standard/50747.html))
- Kodak Vision3 자료의 granularity curve는 density에서 characteristic curve를 따라 granularity sigma를 읽고 1,000을 곱하는 절차를 명시한다. 또한 sensitometric/diffuse RMS 장비 차이로 곡선 형상이 조금 달라질 수 있으며, 표시값은 production coating의 대표값이지 개별 roll의 보증 규격이 아니라고 경고한다. ([Kodak Vision3 500T](https://www.kodak.com/content/pdfs/motion/KODAK-VISION3-500T-5219-7219-technical-information.pdf))
- 네 stock의 기술자료는 RGB sensitometry, RGB MTF, spectral sensitivity/dye-density curve를 각각 제시한다. 따라서 단일 luma grain curve만으로 stock response를 대표하면 공개 자료의 구조보다 얕다. ([Kodak Vision3 기술자료 4종](https://www.kodak.com/en/motion/page/filmmaker-resources/))
- 500T 5219/7219는 여러 gauge로 판매되므로 emulsion response와 final display에서의 확대율을 분리할 수 있다. ([Kodak Motion Picture Products Catalog](https://www.kodak.com/content/pdfs/motion/Kodak-Motion-Picture-Products-Price-Catalog-US.pdf))

### 3.2 설계 변경

```text
StockResponse = density→RMS + record MTF + record covariance/profile
CaptureFormat = exposed image dimensions/gate + scan sampling + final magnification
Processing = normal/push/pull calibration variant (측정 전에는 generic modifier)
Display = output resolution + viewing scale
```

- UI의 기존 `Format`은 `Capture Format`으로 좁히고, 별도 `Grain Class/Stock Response`를 둔다.
- grain diameter는 `%H` 하나가 아니라 `reference film-plane frequency → scan pixel frequency → output frequency` 변환을 거친다.
- Kodak 그래프를 내부 profile로 digitize할 경우 문서 revision, curve 색/record, sampling point, digitization error를 JSON metadata에 저장한다. 제품명 profile은 이 추적성이 있을 때만 사용한다.
- `-8…+8 stop` LUT는 편리한 내부 좌표일 뿐 Kodak 그래프의 직접 x축이 아니다. scene exposure → negative density mapping을 stock sensitometry로 먼저 정의한다.
- PSD, RGB covariance, temporal determinism은 digital synthesis 품질에 필요한 프로젝트 지표다. Kodak RMS와 동일한 물리량이라고 쓰지 않는다.

### 3.3 방어 가능한 QA

- **RMS**: flat field ROI에서 mean 제거 후 표준편차를 측정하되, aperture/ROI/filtering을 manifest에 고정한다. 원 필름 ISO/Kodak 수치와 digital output RMS를 직접 동치화하지 않는다.
- **MTF/SFR**: ISO 12233:2024는 digital camera의 resolution과 SFR 측정 방법을 규정한다. 자체 생성 slanted edge로 상대 MTF 변화를 재되 `ISO 12233 compliant`라고 표시하려면 유료 원문 전체 조건을 구현·검증해야 한다. ([ISO 12233:2024](https://www.iso.org/standard/88626.html))
- **PSD/covariance**: 필름 표준의 대체가 아니라 synthetic grain의 single-pixel sparkle, 반복 peak, channel independence를 잡는 내부 검사로 유지한다.
- **합격 한계**: 실측 curve가 없을 때 ±7%, ±1.5 dB 같은 숫자는 regression envelope다. “Kodak tolerance”로 표현하지 않는다.

## 4. Black/White Mist: 제조사가 말한 상대 방향까지만 사용한다

### 4.1 직접 근거

- Tiffen은 Pro-Mist가 fine detail softening, contrast reduction, localized highlight flare를 만들고 Black Pro-Mist는 contrast를 덜 낮추며 blacks를 더 유지한다고 설명한다. ([Tiffen Pro-Mist/Black Pro-Mist](https://tiffen.com/collections/explore-pro-mist%C2%AE-and-black-pro-mist-camera-filters))
- Tiffen의 자체 4K diffusion test는 제품을 `Black Halation`, `White Halation`, `Optical Resolution` 등으로 분류하고 density별 영상을 제공하지만 MTF/PSF 숫자나 표준화된 transfer curve를 제공하지 않는다. ([Tiffen Diffusion Guide](https://tiffen.com/pages/diffusion-guide))
- Hoya는 White Mist가 Black Mist보다 stronger diffusion/halation이라고 설명한다. 이 비교는 Hoya 제품군 내부의 정성 설명이며 Tiffen Pro-Mist grade와 수치 대응하지 않는다. ([Hoya White Mist](https://hoyafilterusa.com/products/hoya-white-mist), [Hoya 공식 비교](https://hoyafilterusa.com/blogs/news/diffusion-filter-tests))
- Schneider Hollywood Black Magic은 micro-lenslets와 carbon particles, highlight glow, rich blacks/colors 유지, sharp in-focus image 위의 controlled soft overlay를 설명하고 1/8~2 strength를 나열한다. 공개 fact sheet에는 MTF, PSF, black-lift 수치가 없다. ([Schneider fact sheet](https://schneiderkreuznach.com/application/files/8516/8024/4715/Fact_Sheet_Hollywood_Black_Magic_Schneider-Kreuznach.pdf))
- Schneider는 focal length, F-stop, subject light가 diffusion의 체감 강도에 영향을 준다고 명시한다. 따라서 filter-only profile을 한 카메라/렌즈 조건의 단일 kernel로 확정하면 안 된다. ([Schneider Diffusion and Mist](https://schneiderkreuznach.com/en/cine-optics/filters/cine-filters/diffusion-and-mist))

### 4.2 주장할 수 없는 것

- `black particles가 일정 비율로 shadow를 흡수한다`, `white particles는 특정 PSF를 만든다` 같은 모든 제품 공통의 미세구조·전달함수.
- grade 1/4가 grade 1/8의 정확히 2배라는 선형성.
- Black과 White의 shadow lift ratio 1.7, 특정 spatial frequency의 MTF 85%/75%가 제조사 재현 기준이라는 주장.
- 서로 다른 회사의 `Black Mist`, `Black Pro-Mist`, `Hollywood Black Magic`이 같은 curve family라는 주장.

### 4.3 권장 수정

- UI는 `Filter Family: Generic Black / Generic White`, `Grade`를 사용한다. 상표명 preset은 실제 동일 제품 측정과 법무 검토 전까지 사용하지 않는다.
- 기본 model gate는 방향성으로 둔다: 같은 내부 grade에서 Generic White의 broad veil이 Generic Black보다 크고, Generic Black의 low-frequency black retention이 더 높아야 한다.
- 강도 단조성은 유지하되 인접 grade 간 비율은 실측 후 정한다.
- MTF는 lens-only baseline 대비 filter-on ratio, flare는 point source PSF/encircled energy, veil은 dark patch lift와 local contrast로 분리 측정한다.
- physical reference 촬영 시 focal length, T-stop, focus distance, source luminance/angle, sensor, debayer, exposure, WB를 고정·기록한다.

## 5. Lens ghost와 robust source isolation

### 5.1 반사 기하

- 물리 기반 flare rendering은 각 lens surface의 curvature, thickness, refractive index, coating을 따라 ray를 전달하고 두 surface에서 반사되는 ghost path를 열거한다. aperture에서 막힌 ray와 sensor에 도달하는 ray를 구분해야 하므로 단순 2D 중심 대칭 sprite보다 lens profile 의존성이 크다. ([Hullin et al. project/paper](https://resources.mpi-inf.mpg.de/lensflareRendering/))
- BracketFlare의 paraxial 식은 focused reflection의 image height가 source height에 선형이며 optical center를 지나는 것을 보인다. 논문이 관찰한 `k=-1`은 세 smartphone main camera의 특정 focused reflective flare prior다. ([Dai et al., CVPR 2023](https://openaccess.thecvf.com/content/CVPR2023/papers/Dai_Nighttime_Smartphone_Reflective_Flare_Removal_Using_Optical_Center_Symmetry_Prior_CVPR_2023_paper.pdf))

### 5.2 source isolation 근거와 한계

- BracketFlare는 정상 노출만으로 clipped source pattern을 복원하지 않고, 같은 ISO에서 3 EV step의 bracket 중 저노출 이미지를 사용해 brightest source pattern을 얻는다. 논문의 단일 입력 prior도 per-channel 강한 gamma로 near-saturated region을 찾지만, 복잡한 배경과 여러 광원에서 bright spot detection이 오검출될 수 있음을 문제로 제시한다. ([Dai et al., CVPR 2023](https://arxiv.org/abs/2303.15046))
- Flare7K는 light source, reflective flare, glare/shimmer, streak annotation을 분리한다. 이는 진단 layer 구조의 좋은 참고지만 synthetic/phone-night domain이며, 저장소 라이선스는 non-commercial use만 허용한다. 상용 제품 fixture로 포함하거나 재배포하려면 별도 허가가 필요하다. ([Flare7K paper](https://proceedings.neurips.cc/paper_files/paper/2022/file/1909ac72220bf5016b6c93f08b66cf36-Paper-Datasets_and_Benchmarks.pdf), [공식 저장소](https://github.com/ykdai/Flare7K), [S-Lab License 1.0](https://raw.githubusercontent.com/ykdai/Flare7K/main/LICENSE))

### 5.3 권장 설계

1. `isolateSources`는 scene-linear `maxRGB`, luminance, per-channel mask를 선택할 수 있게 하고 hard clipping 이전 데이터를 우선한다.
2. energy tile/local maxima만 쓰더라도 각 source에 centroid, second moment/shape, channel energy, saturation/clipping flag를 저장한다.
3. spatial detector는 random seek 결정성을 위해 과거 frame에 의존하지 않는다. temporal smoothing은 optional preview이며 render 결과 계약에서는 끈다.
4. 자동 검출만으로 정답을 보장할 수 없으므로 `Manual Source`/matte input을 Should가 아니라 **Must fallback**으로 올린다.
5. profile element의 위치는 signed `k`, magnification, defocus, aperture clipping, spectral attenuation으로 표현한다. 모든 element에 같은 180° flip을 강제하지 않는다.
6. source pattern 보존은 허용하되 전체 highlight matte 한 장을 여러 번 affine warp하는 현재 방식은 폐기한다.

### 5.4 권장 QA

- synthetic multi-source sequence에 exact source labels를 제공하고 precision/recall, centroid error, energy error, threshold sweep continuity를 측정한다.
- clipped white, saturated R/G/B LED, large signage, fine LED array, bright window, specular metal을 별도 fixture로 둔다.
- ghost 공통 규칙은 axis collinearity, position/energy continuity, finite energy, edge no-wrap다. profile별 k와 shape는 measured/golden envelope로 분리한다.
- `Elements Only`에서 focused source-like ghost와 aperture-shaped defocused ghost를 둘 다 허용한다.

## 6. Field-dependent PSF, cat-eye, aberration, bokeh

### 6.1 직접 근거

- Nikon OPTIA는 real lens의 wavefront aberration을 측정하고 spherical aberration, coma, astigmatism, field curvature, chromatic aberration 정보를 image simulator에 사용한다. 객관 측정과 사람의 bokeh 평가를 함께 사용한다. ([Nikon OPTIA](https://www.nikon.com/company/technology/stories/1909_optia/))
- ZEISS는 aperture shape가 large defocus point source에서 잘 보이고, spherical aberration의 correction 상태가 foreground/background blur를 다르게 하며, longitudinal chromatic aberration의 fringe 방향도 focus 앞뒤에서 달라진다고 설명한다. ([ZEISS Depth of Field and Bokeh](https://lenspire.zeiss.com/photo/app/uploads/2018/04/Article-Bokeh-2010-EN.pdf))
- measured-PSF 연구는 PSF를 defocus, field, azimuth의 함수로 측정·파라미터화한다. 최근 blur-field 연구도 image-plane location, focus, depth에 따른 5D PSF dataset을 제공한다. 이는 단일 전 화면 kernel보다 field-dependent representation이 맞다는 직접 근거다. ([Realistic Image Degradation with Measured PSF](https://arxiv.org/abs/1801.02197), [Learning Lens Blur Fields](https://arxiv.org/abs/2310.11535))
- detailed lens prescription과 distributed ray tracing을 쓰는 original camera model은 backplane irradiance와 geometric/radiometric lens behavior를 함께 계산한다. 실제 렌즈명을 주장하려면 이런 prescription 또는 측정 PSF가 필요하다. ([Kolb, Mitchell & Hanrahan, A Realistic Camera Model](https://graphics.stanford.edu/papers/camera/))

### 6.2 설계 판단

- 현재 `uniform defocus + field-dependent generic PSF` 범위는 정직하다. depth input 없이 DOF, near/far occlusion, real focus distance를 주장하지 않는다.
- `cat_eye`는 단순 corner oval scale이 아니라 field/azimuth에 따라 이동·clipping되는 effective pupil 근사로 구현한다. 각 tile PSF의 energy는 normalize하되 optical vignetting을 별도 control로 분리한다.
- `bokeh_bias`는 실측 전 UI에서 `Center/Rim Bias`로 유지하고 “spherical aberration correction”이라고 단정하지 않는다.
- channel별 PSF는 가능하지만 실제 lens profile 주장은 wavelength/field/focus 측정 후에만 한다.
- generic `Clean/Portrait/Vintage/Anamorphic` profile은 artistic family다. 렌즈 제조사나 모델명을 붙이지 않는다.

### 6.3 QA

- synthetic PSF grid로 field/azimuth/defocus를 sweep하고 energy, centroid, second moment, axis ratio, radial/rim profile을 저장한다.
- tile interpolation seam은 centroid/second-moment continuity로 측정한다. 0.25 px 같은 한계는 내부 tolerance로 표시한다.
- constant-field 보존과 PSF energy conservation은 방어 가능한 수학 불변조건이다.
- “좋은 bokeh”는 단일 객관 수치로 대체하지 않는다. Nikon/ZEISS가 쓰는 것처럼 measured/simulated PSF와 blind visual review를 함께 둔다.

## 7. Reference QA 자산: 다운로드, 용도, 라이선스

### 7.1 제조사 camera-original

| 우선 | 자산 / 정확한 페이지 | 직접 허용·용도 설명 | 저장소 정책 |
|---:|---|---|---|
| P0 | [Blackmagic RAW Camera Original Files](https://www.blackmagicdesign.com/products/blackmagicraw) | 페이지가 camera-original 3개 clip의 직접 download를 제공한다. BRAW codec/SDK의 free·license-free 설명은 **codec에 대한 것**이며 clip 저작물의 재배포 허가와 동일하지 않다. | 로컬 다운로드·내부 QA. repo에는 URL, hash, clip/frame, decode 설정만 기록. |
| P0 | [ARRI Sample Footage 기술문서/링크](https://www.arri.com/resource/blob/31926/05d8d8bd82fde9008a7c7af3b72cfeaf/2021-09-arri-sample-footage-technical-information-linked-cam-dl-pages-as-well-data.pdf) | ARRI가 ARRICORE/ARRIRAW/HDE/ProRes workflow, color pipeline, grading, metadata 테스트용이라고 명시하고 FTP/Frame.io 링크를 제공한다. | 평가 목적에 맞춰 내부 사용. 재배포 권리는 별도 확인 전 금지. |
| P1 | [Sony VENICE 2 X-OCN Sample Files](https://pro.sony/en_DK/cinematography/cinematography-tips/x-ocn-8k-downloads) | Sony가 X-OCN workflow를 test/evaluate하도록 9개 scene download를 제공하며 무료 등록이 필요하다. | 내부 QA, URL/hash만 commit. 등록 시 표시 약관을 캡처·보관. |
| P1 | [RED Sample R3D Files](https://www.reddigitalcinema.com/sample-r3d-files) | 각 clip은 로그인/약관 동의 뒤 다운로드한다. 예: [KOMODO-X 6K DANCER-3](https://www.reddigitalcinema.com/download/sample-r3d-file-komodo-x-6k-s35-dancer-3). | 클릭 동의 license를 자산 manifest에 기록. 재배포 금지, internal QA only로 취급. |
| P2 | [Nikon Z Cinema RAW sample](https://www.nikonusa.com/content/Zcinema-raw-file-downloads) | Nikon이 R3D NE sample footage download를 제공한다. | 사용 전 페이지/다운로드 약관을 자산별 보관. |

**중요:** “다운로드 가능”은 “프로젝트 저장소에 재배포 가능”과 다르다. 외부 원본은 `.gitignore`된 asset cache에 두고 SHA-256과 취득일을 기록한다.

### 7.2 charts와 합성 fixture

- P0는 저작권·라이선스 불확실성이 없는 **자체 생성** linear EXR fixture다: exposure/color flat fields, slanted edge, point-light sweep, point-grid, large signage/LED matrix, alpha edge, depth/near-far synthetic layers.
- ISO 12233 이름·chart artwork를 복제하지 않고 자체 edge geometry를 쓴다. SFR 측정 원칙은 ISO 12233:2024를 참조하되 compliance를 주장하지 않는다. ([ISO 12233:2024](https://www.iso.org/standard/88626.html))
- skin/ColorChecker fixture는 chart 이미지의 재배포 권리를 자동 가정하지 않는다. 실물 chart를 자체 촬영하거나 명시적 라이선스가 있는 데이터만 사용한다.
- Flare7K는 non-commercial license이므로 상용 plugin의 shipped fixture가 아니라 연구 비교 후보로만 둔다. 별도 상업 허가 없이는 사용하지 않는다. ([Flare7K license](https://raw.githubusercontent.com/ykdai/Flare7K/main/LICENSE))

## 8. 객관 QA metric: 방어 가능한 항목과 placeholder

| 대상 | 방어 가능한 metric | 방어 가능한 범위 | 아직 필요한 calibration |
|---|---|---|---|
| Halation | source-mask precision/recall, core chroma, channel radial profile, encircled energy, threshold continuity | 자체 synthetic ground truth와 동일 profile 회귀 | 실제 stock별 channel ratio, radius, exposure response |
| Grain | density/luma RMS, radial PSD, RGB covariance, determinism, resolution scaling | ISO 10505의 RMS 개념 + digital synthesis 내부 검사 | film-plane→scan→display mapping, stock curve digitization/scan 측정 |
| Mist | filter-on/off MTF ratio, point-source PSF/encircled energy, dark-patch lift, local contrast, hue shift | 동일 촬영 조건의 상대 측정 | family/grade별 실제 필터 촬영 |
| Ghost | source detection PR/centroid, optical-axis residual, k continuity, per-element energy, no-wrap | synthetic profile과 source sweep | real lens별 k/shape/spectral profile |
| Optical | PSF energy, centroid, second moment, axis ratio, radial profile, tile continuity | 수학 불변조건과 generic profile 회귀 | measured field/azimuth/defocus PSF |
| Color | display-referred ΔEITP | peak luminance와 output transform이 고정된 HDR/SDR 비교 | scene-linear에는 별도 neutral-ratio/relative metric 필요 |
| Backend | max/mean abs error, identity, finite/HDR/alpha contract | 같은 algorithm/quality의 CPU–Metal parity | tolerance는 precision/performance 실측으로 프로젝트가 확정 |

### 8.1 metric 사용 규칙

1. ISO/ITU는 **측정 정의**의 근거다. 프로젝트의 pass number를 자동으로 제공하지 않는다.
2. golden image similarity는 regression용이다. reference 자체가 물리적으로 틀리면 높은 SSIM도 의미가 없다.
3. stochastic grain은 같은 seed/frame parity와 ensemble statistics를 분리한다.
4. ΔEITP는 output transform과 nominal display luminance를 manifest에 기록한 경우만 쓴다. scene-linear neutral core는 RGB ratio/xy chromaticity 등 별도 값으로 검사한다. ([ITU-R BT.2124](https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2124-0-201901-I%21%21PDF-E.pdf))
5. aesthetic approval은 최소 5개 scene의 masked A/B와 100%/viewing-size review로 유지하되, 객관 metric과 별도 gate로 기록한다.

## 9. 구체적 권장 설계 변경 목록

### P0 — 구현 전에 명세 수정

1. Halation의 `No Backing/No Remjet` 프리셋 삭제, 모든 spectral 수치에 `provisional` 태그 추가.
2. Grain plan을 `StockResponse`, `CaptureFormat`, `ProcessingModifier`, `DisplayScale`로 분해.
3. Mist `Density` label을 `Grade`로 변경하고 trademark-free generic family 사용.
4. Lens ghost profile의 `axis_position`을 signed k로 정의하고 공통 `k=-1` 가정 삭제.
5. Lens source isolation에 manual point/matte fallback을 Must로 승격.
6. Optical `bokeh_bias`를 `Center/Rim Bias`로 표시하고 real spherical-aberration claim 금지.
7. 모든 numeric model gate에 `standard`, `measured`, `internal tolerance`, `placeholder` provenance 필드 추가.

### P1 — fixture와 측정

1. 자체 synthetic EXR suite와 manifest를 먼저 생성한다.
2. BRAW + ARRIRAW sample을 로컬 취득하고 hash/input transform/frame/crop을 고정한다.
3. 동일 렌즈·T-stop에서 Tiffen Pro-Mist와 Black Pro-Mist 1/8·1/4·1/2를 직접 촬영한다.
4. Vision3 50D/500T의 controlled point light, flat fields, slanted edge를 동일 lab/scan으로 확보한다.
5. 자체 렌즈 flare/PSF grid를 center/mid/corner, aperture, focus offset, RGB/narrowband source로 촬영한다.

### P2 — calibration 후에만 활성화

1. measured envelope가 있는 profile에만 stock/filter/lens 실명 또는 실제 단위 control을 허용한다.
2. Halation channel ratio와 Mist grade curve의 provisional 숫자를 measured confidence interval로 교체한다.
3. Flare7K/BracketFlare 등 외부 dataset은 상용 허가를 확보한 경우에만 제품 QA archive에 편입한다.

## 10. 우선순위 reference-fixture 확보 목록

| 순위 | 확보물 | 최소 조건 | 해소하는 위험 |
|---:|---|---|---|
| 1 | 자체 synthetic linear EXR suite | source/edge/flat/PSF/alpha, ground-truth masks, 1080/UHD/8K | 모든 효과의 수학·scale·parity gate |
| 2 | Blackmagic BRAW 3 clips | 공식 페이지, local-only, SHA-256, Gen 5 decode metadata | 현재 Resolve host/color pipeline 회귀 |
| 3 | ARRI ALEXA 35 ARRIRAW clips | 공식 sample doc, LogC4/ARRI Wide Gamut 4 설정 | high-latitude/metadata/색 관리 |
| 4 | 동일 계열 physical mist pair | Pro-Mist vs Black Pro-Mist, same grade/lens/T-stop/source | Black/White transfer·MTF placeholder 제거 |
| 5 | controlled Vision3 capture/scan | 50D+500T, point/edge/9 exposure flat, same ECN-2 lab/scanner | halation spectral/RMS/MTF profile calibration |
| 6 | 자체 real-lens flare sweep | clean lens, source angle/position/intensity, exposure bracket | source isolation, k, ghost pattern/veil |
| 7 | 자체 field PSF grid | center/mid/corner × focus offset × aperture × RGB source | cat-eye/aberration/profile calibration |
| 8 | Sony X-OCN/RED R3D | official download, accepted terms archived | cross-camera robustness |
| 9 | Flare7K/BracketFlare | commercial permission first | diverse flare visual stress test |

## 11. Source quality / availability

| 출처 | 품질 | 무엇을 직접 제공 | 가용성·제약 |
|---|---|---|---|
| Kodak Vision3 2026 technical data | A | stock별 sensitometry, RMS granularity graph/방법, RGB MTF, spectral curves, anti-halation undercoat 설명 | 공개 PDF. 대표 coating data이지 보증 specification 아님. |
| Kodak ECN-2 Module 7 / Exploring the Color Image | A- | color-negative 층 순서와 처리/색층 원리 | 공개 PDF. 현행 stock의 halation PSF 숫자는 없음. |
| ISO 10505:2009 | A | intrinsic RMS granularity 측정 범위 정의 | 표준 페이지 공개, 원문 유료. 2025 재확인. |
| ISO 12233:2024 | A | digital camera resolution/SFR 측정 표준 | 표준 페이지 공개, 원문 유료. 자체 구현을 compliance라 부르지 않음. |
| ITU-R BT.2124 | A | ΔEITP 정의와 display/scene-referred 적용 조건 | 원문 무료. pass threshold는 프로젝트가 정함. |
| Tiffen/Hoya/Schneider 공식 자료 | B | Black/White 계열의 정성적 상대 방향, 제품 grade, 촬영 context | 공개. MTF/PSF/transfer 수치 없음. |
| Hullin et al. 2011 | A- | lens prescription 기반 ghost ray paths와 real-time 근사 | 저자 project/paper 공개. 특정 상용 lens profile 데이터는 아님. |
| BracketFlare CVPR 2023 | A | optical-center 선형 prior, k=-1 적용 범위, bracket source capture | 논문 공개. smartphone-focused domain. |
| Measured PSF / Blur Fields original research | A- | field/azimuth/defocus-dependent PSF 측정·표현 | 논문/일부 데이터 공개. 제품 lens와 직접 일치하지 않음. |
| Blackmagic/ARRI/Sony/RED sample pages | A- | manufacturer camera-original과 workflow 목적 | 다운로드 가능. 원본 재배포는 별도 허가 전 금지. |
| Flare7K | B+ | source/flare/streak annotation과 대규모 stress patterns | 공식 repo, **non-commercial only** license. |

## 12. 결론

심층 근거는 v2의 큰 방향—scene-linear source extraction, multi-branch scattering, exposure/record-aware grain, field-dependent PSF, diagnostic layers—을 지지한다. 그러나 기존 설계는 공개 자료가 주지 않는 수치를 실제 재료의 법칙처럼 너무 일찍 고정했다.

가장 중요한 수정은 다음 세 가지다.

1. **Halation/Mist의 숫자 비율은 실측 전 placeholder로 내리고, 구조적 불변조건과 provenance를 우선한다.**
2. **Grain에서 stock response와 capture format/magnification을 분리한다.**
3. **Ghost의 광축 collinearity는 유지하되 `k=-1`, source-shape 금지 같은 과도한 일반화를 제거한다.**

따라서 P0의 첫 산출물은 알고리즘 구현이 아니라 `fixture manifest + metric provenance + provisional gate 표시`여야 한다. physical filter/film/lens reference를 확보한 뒤에만 특정 stock·filter·lens의 실명 profile과 실제 단위 제어를 제품 약속으로 승격한다.
