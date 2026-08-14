# 유료급 필름·광학 효과 재설계를 위한 1차 자료 조사

- 작성일: 2026-08-12
- 범위: Halation, Film Grain, Lens Reflections/Ghosts, Black/White Mist, Optical Blur/Bokeh, 색 관리와 품질 검증
- 출처 원칙: 필름·필터·렌즈 제조사, 효과 제품 제작사 공식 문서, 표준 문서, 원 연구 논문만 사용
- 목적: 효과가 단순히 보이는 수준이 아니라 상용 고급 필터처럼 물리적으로 설득력 있고 조절 가능하며 반복 검증 가능한 수준이 되도록 수정 범위를 정의한다.

## 1. 결론 요약

현재 효과를 유료급으로 끌어올리려면 강도를 높이는 작업이 아니라 다음 다섯 가지 공통 구조가 필요하다.

1. **입력 신호를 이해하는 처리**: Rec.709 코드값에 곧바로 블러를 거는 대신 입력 감마·색역을 명시하고, 광량 기반 효과는 장면 선형 또는 그에 준하는 노출 도메인에서 계산한다.
2. **콘텐츠 반응형 소스 추출**: 밝은 픽셀 전체가 아니라 점광원, 고대비 경계, 색, 배경 밝기, 화면 위치에 따라 발생 위치와 형태가 달라져야 한다.
3. **다중 스케일·채널별 광학 모델**: 단일 Gaussian blur와 단일 tint로 끝내지 않고, 좁은 링·넓은 산란·베일, R/G/B 확산 차이, 렌즈/필름 프로파일을 조합한다.
4. **격리 보기와 측정 가능성**: Halation Map, Flare Elements, Grain-only, Bloom-only 같은 진단 출력을 제공해야 프리셋과 회귀 테스트를 객관화할 수 있다.
5. **물리적 규칙 안에서의 예술 제어**: 사용자가 자유롭게 조절하되 광원 이동, 렌즈 중심, 조리개, 노출 변화에서 결과가 일관되게 움직여야 한다.

효과별 최우선 수정은 다음과 같다.

| 효과 | 현재의 단순 구현이 보일 수 있는 문제 | 유료급 수정 핵심 |
|---|---|---|
| Halation | 따뜻한 백색 블룸처럼 보임 | 적·주황 계열의 경계 halo와 넓은 red glare를 분리하고 소스·배경·채널별 반응 구현 |
| Film Grain | 영상 위에 얹은 균일 노이즈처럼 보임 | 필름 포맷/감도별 입자 구조, 노출·색상별 밀도, 공간적 군집과 결정론적 시간 변화 구현 |
| Lens Reflections | 화면에 고정된 장식 또는 단순 대칭 ghost | 광원 추적, 렌즈 중심을 지나는 반사 기하, 조리개·코팅·수차·아나모픽 프로파일 구현 |
| Black/White Mist | 밝은 영역 blur와 전체 contrast 조정에 머묾 | 국소 highlight flare, 저주파 veiling, 고주파 피부 디테일 완화를 분리하고 두 필터의 black 유지 차별화 |
| Optical Blur/Bokeh | 전 화면 균일 Gaussian/anamorphic blur | aperture PSF, 비네팅/cat-eye, 구면·색수차, 전경/배경 비대칭, 선택적 depth/matte 처리 구현 |

## 2. Halation

### 2.1 물리 현상

- Kodak은 필름에 anti-halation 층을 두어 에멀전 또는 지지체를 통과한 빛의 역산란과 색 번짐을 억제한다고 설명한다. Vision3 500T는 rem-jet 대신 anti-halation undercoat를 사용하며, Vision Color Print Film 역시 처리 과정에서 제거되는 anti-halation 층을 명시한다. 이는 halation이 단순한 소프트 글로우가 아니라 필름층을 통과한 강한 빛의 내부 산란·반사에 관계된 현상임을 뒷받침한다.  
  출처: [KODAK VISION3 500T 5219/7219 Technical Data](https://www.kodak.com/content/products-brochures/motion-picture/KODAK-VISION3-5219-7219-technical-information.pdf), [KODAK VISION Color Print Film 2383/3383](https://www.kodak.com/en/motion/product/post/print-films/vision-color-2383-3383/)
- FilmConvert는 강한 빛이 필름을 통과한 뒤 red-sensitive layer에 영향을 주어 밝은 부분 주위에 붉은 halo가 생긴다고 설명한다. Dehancer 역시 밝은 광원, specular highlight, 고대비 경계 주변의 red-orange halo와 중간톤의 넓은 red glare를 구분한다.  
  출처: [FilmConvert Halation 공식 튜토리얼](https://www.filmconvert.com/tutorials?Product=halation), [Dehancer Halation 공식 설명](https://www.dehancer.com/learn/article/halation)

### 2.2 상용 고급 구현의 특징

- **광원 추적**: FilmConvert는 단순 오버레이가 아니라 영상 속 빛을 추적해 어디에 어떻게 halation이 생길지 결정한다고 설명한다.  
  출처: [FilmConvert Nitrate](https://www.filmconvert.com/nitrate)
- **두 종류의 확산 분리**: Dehancer의 Local Diffusion은 광원·경계 주변의 halo 반경을, Global Diffusion은 낮은 대비의 넓은 red glare를 제어한다.
- **소스와 배경을 따로 제한**: Source Limiter는 발광원 임계값을, Background Gain은 밝은 배경에 halo가 과도하게 보이는 것을 제한한다.
- **색층 반응**: Amplify, Hue, Blue Compensation은 단순한 warm tint가 아니라 적·녹·청층 민감도와 배경색의 관계를 조절한다.
- **필름 프로파일**: 표준 anti-halation 구조와 No Remjet 프로파일의 강도 차이를 프리셋으로 제공한다.
- **진단 출력**: FilmConvert의 View Halation Alone과 Dehancer의 Mask Mode는 선택 영역과 실제 합성 결과를 분리해 확인하게 한다.

### 2.3 권장 파라미터와 프리셋

| 그룹 | 권장 제어 |
|---|---|
| Source | Threshold/Sensitivity, Source Softness, Background Protection, Highlight Core Protection |
| Shape | Edge Width, Local Radius, Global Spread, Smoothness |
| Spectrum | Red Bias, Hue, Saturation, Green Sensitivity, Blue Compensation |
| Mix | Local Amount, Global Amount, Impact, Highlights Only |
| Diagnostics | Halation Only, Source Mask, Local/Global split view |
| Presets | 8mm, 16mm, 35mm, 65mm, No Remjet, Subtle Negative, Strong Edge |

### 2.4 피해야 할 실패 형태

- 흰 광원 전체와 주변이 동일하게 희어져 bloom처럼 보이는 결과
- 모든 밝은 픽셀에 같은 크기의 붉은 외곽선을 붙이는 결과
- 밝은 배경·피부 중간톤까지 한 덩어리로 붉어지는 결과
- 색수차를 halation으로 잘못 선택하는 결과
- 밝은 중심부를 재차 더해 highlight가 clipping되는 결과
- 해상도나 Render Scale에 따라 halo의 화면상 크기가 달라지는 결과

### 2.5 QA 방법과 합격 기준

- 점광원, 흰색 사각형의 고대비 경계, 밝은 배경 위 광원, 어두운 배경 위 광원을 각각 시험한다.
- Halation-only map에서 점광원·경계가 선택되고 평탄한 흰 영역의 중심은 과도하게 채워지지 않아야 한다.
- 좁은 red-orange edge halo와 넓고 약한 red glare를 따로 확인한다.
- 파란 LED, tungsten, 중성 백색 광원에서 hue가 입력색에 무관한 고정 빨강으로 붙지 않는지 확인한다.
- 표준 프로파일과 No Remjet 프리셋의 반경·에너지 차이가 일관돼야 한다.
- 100% 확대에서 banding, hard contour, chromatic ringing, clipping이 없어야 한다.
- 공식 제품이 제공하는 진단 방식에 맞춰 Source Mask와 Halation Only 출력을 스냅샷 회귀 테스트에 포함한다.

## 3. Film Grain

### 3.1 물리 현상

- Kodak은 silver-halide grains가 무작위로 분포하며 고감도 필름일수록 일반적으로 더 큰 입자를 사용한다고 설명한다. 입상성은 특히 shadow와 underexposure에서 더 두드러진다.  
  출처: [KODAK Essential Reference Guide for Filmmakers](https://www.kodak.com/content/products-brochures/Film/kodak-essential-reference-guide-for-filmmakers.pdf)
- Fujifilm은 입자의 불균일한 분포와 군집이 시각적 graininess를 만들며, RMS granularity가 시각적 입상성과 상관되는 표준적인 객관 지표라고 설명한다.  
  출처: [Fujifilm Professional Film Data Guide](https://asset.fujifilm.com/www/us/files/2020-03/3ab271f46f8d71c7e4c91bcedb7de050/ProfessionalFilmDataGuide.pdf)
- FilmConvert와 Dehancer는 단순한 noise overlay와 달리 필름 stock, exposure, color에 따라 grain 양과 성격이 달라지는 모델을 강조한다.  
  출처: [FilmConvert Nitrate](https://www.filmconvert.com/nitrate), [Dehancer Film Grain](https://www.dehancer.com/learn/article/grain)

### 3.2 상용 고급 구현의 특징

- **stock/format별 구조**: 8mm, 16mm, 35mm에서 입자 크기와 이미지 해상감이 함께 달라진다.
- **톤별 반응곡선**: shadows, midtones, highlights, whites를 단일 gain이 아니라 곡선으로 제어한다.
- **색층별 입자**: monochrome noise에 hue를 입히는 대신 RGB 또는 dye-cloud 성분의 크기·상관·포화를 모델링한다.
- **공간적 군집**: 완전 독립 픽셀 노이즈가 아니라 여러 크기의 입자와 약한 clumping이 존재한다.
- **해상감과 grain의 분리**: Dehancer의 Film Resolution, FilmConvert의 Image Softness, Resolve의 Image Defocus처럼 영상의 광학적 선예도와 입자 선예도를 별개로 조절한다.
- **시간적 생동감과 결정성**: 프레임마다 변화하되 동일 seed·frame·파라미터는 렌더 순서와 캐시에 상관없이 같은 결과를 내야 한다.
- **성능/품질 모드**: FilmConvert는 artifacts가 보일 때 Performance에서 Balanced 또는 Quality로 올리는 제어를 제공한다.

### 3.3 권장 파라미터와 프리셋

| 그룹 | 권장 제어 |
|---|---|
| Stock | Format/Stock, Speed/Grain class, Negative/Positive response |
| Structure | Size, Clump, Sharpness, Film Resolution, Softness |
| Tonal response | Amount, Shadows, Midtones, Highlights, Blacks/Whites roll-off |
| Color | Chroma Amount, RGB/Dye correlation, Color Bias |
| Motion | Seed, Temporal Rate, Persistence/Jitter |
| Diagnostics | Grain Only, Luma Grain, Chroma Grain, Response Curve |
| Presets | Super 8, 16mm 250D/500T 성격, 35mm Fine/Medium/Fast, 65mm Fine |

상용 stock 명칭이나 실측 데이터가 없는 상태에서 Kodak/Fujifilm 상품명을 그대로 붙여 정확한 에뮬레이션이라고 주장해서는 안 된다. 실측 자료가 없으면 `35mm Fine`, `16mm Fast`처럼 물리적 성격을 표현하는 명칭이 정확하다.

### 3.4 피해야 할 실패 형태

- 순수 흰색과 순수 검정까지 동일 진폭으로 끓는 white-noise overlay
- RGB 채널이 완전히 독립적이어서 컬러 점이 과도하게 튀는 결과
- 프레임 간 패턴이 고정되어 화면에 붙어 보이거나, 반대로 seed가 불안정해 seek 때마다 달라지는 결과
- 해상도가 바뀔 때 grain의 체감 크기가 바뀌는 결과
- optical defocus 이전에 grain을 넣어 grain까지 함께 흐려지는 잘못된 노드 순서
- blur/downsample로 사라지는 1-pixel noise 또는 확대 시 거대한 디지털 얼룩이 되는 구조

### 3.5 QA 방법과 합격 기준

- Kodak/Fujifilm의 방법을 디지털 기준으로 변환해 일정한 flat-field 노출 샘플의 density/luma fluctuation 표준편차와 공간 주파수 분포를 기록한다. 원 필름의 48 μm aperture, density 1.0 수치를 디지털에 그대로 동일시하지 않고 **측정 방법의 원칙**으로 사용한다.
- -8~+8 stop ramp와 neutral/color flat patches에서 톤별 RMS, RGB covariance, power spectral density를 측정한다.
- 순수 black/white 근처에서 grain이 자연스럽게 감쇠하는지 확인한다.
- 프레임 0/1/2, 임의 seek, 역방향 seek, 재렌더에서 동일 frame output이 bit-exact 또는 정한 tolerance 안에서 일치해야 한다.
- 1080p/4K/8K/12K와 Render Scale에서 물리적 체감 크기가 유지돼야 한다.
- Resolve 21의 grain replacement 지침처럼 defocus 처리 뒤 grain을 추가한 경우와 앞에 추가한 경우를 비교해 올바른 노드 순서를 문서화한다.  
  출처: [DaVinci Resolve 21 New Features Guide](https://documents.blackmagicdesign.com/SupportNotes/DaVinci_Resolve_21_New_Features_Guide.pdf)
- MTF/slanted-edge와 grain PSD를 동시에 확인해 입자를 강하게 만들면서 원본 detail을 무조건 blur로 숨기지 않는지 검증한다.

## 4. Lens Reflections / Ghosts / Flare

### 4.1 물리 현상

- Canon은 렌즈 요소 표면 사이의 내부 반사가 흐린 복제상인 ghost를 만들고, 렌즈 표면이나 barrel에서 반사된 비결상광이 flare와 contrast 저하를 만든다고 설명한다. 다층 코팅은 파동 간 상쇄를 이용해 반사를 줄이며, 코팅에 따라 wavelength response가 달라진다.  
  출처: [Canon Science Lab: Lens Coating](https://global.canon/en/technology/s_labo/light/003/03.html)
- ARRI는 Master Anamorphic의 원래 설계가 flare와 내부 반사를 억제하지만, 별도 전·후면 Flare Set 코팅은 의도적으로 flaring, ghosting, veiling glare를 만든다고 설명한다. front/rear를 따로 또는 함께 바꾸며 해상도와 왜곡 성능은 유지한다.  
  출처: [ARRI Master Anamorphic Lenses / Flare Sets](https://www.arri.com/en/cine-lenses/arri-zeiss-fujinon-lenses/master-anamorphics)
- 원 연구는 reflective ghost가 광원과 이미지 중심을 잇는 선상에 놓이고 광원 이동에 반대 방향으로 움직이는 경향, 조리개 모양, element geometry, coating spectrum, 색수차가 형태와 색을 좌우한다고 정리한다.  
  출처: [A Survey of Lens Flare Phenomenon and Removal](https://arxiv.org/abs/2310.14354), [Real-world Flare Removal Benchmark](https://arxiv.org/abs/2306.15884)

### 4.2 상용 고급 구현의 특징

- 광원의 위치·크기·색·세기를 추적하고 화면 밖 광원도 고려한다.
- lens optical center/pivot를 기준으로 ghost가 정렬되고 source 이동에 따라 반대 방향으로 연속적으로 움직인다.
- ghost disc/polygon, hotspot, rings, streaks, rays/starburst, veiling glare를 별도 element로 구성한다.
- aperture blade 수·곡률·회전, anamorphic squeeze, lens coating, iris/T-stop, focal length를 프로파일로 묶는다.
- ghost마다 크기, 초점 흐림, 색 분산, 투과율, edge falloff가 다르다.
- flare가 dark scene에서 더 잘 보이고 bright background에서는 자연스럽게 묻히도록 local contrast-aware compositing을 사용한다.
- Boris FX처럼 Flare Designer, presets, element별 brightness/color/gamma/saturation/hue, rays와 edge trigger를 제공한다.  
  출처: [Boris FX Sapphire OFX LensFlare](https://borisfx.com/documentation/sapphire/ofx/lensflare/)

### 4.3 권장 파라미터와 프리셋

| 그룹 | 권장 제어 |
|---|---|
| Source | Automatic/Manual Source, Threshold, Source Radius, Off-screen Reach, Occlusion |
| Lens | Optical Center, Focal Length, T-stop, Coating, Lens Model |
| Ghosts | Count, Spread, Scale, Blur, Chromatic Dispersion, Falloff |
| Flare | Hotspot, Veiling Glare, Streak, Rays/Starburst, Halo |
| Anamorphic | Squeeze, Horizontal Streak, Ovality, Flare tint |
| Diagnostics | Source Map, Ghost Paths, Elements Only, per-element solo |
| Presets | Clean Spherical, Vintage Coated, Uncoated, Modern Anamorphic, Vintage Anamorphic |

### 4.4 피해야 할 실패 형태

- 광원이 움직여도 ghost가 화면에 붙어 있거나 임의 방향으로 움직이는 결과
- 모든 광원에 같은 간격·같은 크기의 원을 반복하는 결과
- aperture 모양을 모든 blur 영역에 도장처럼 찍는 결과
- flare가 피사체 앞뒤 가림과 무관하게 항상 최상단에 존재하는 결과
- 화면 전체 대비를 과도하게 잃고도 source energy와 관계없는 결과
- anamorphic preset이 단지 수평 Gaussian streak 하나로 끝나는 결과
- 밝은 배경에서도 ghost가 불투명 스티커처럼 보이는 합성

### 4.5 QA 방법과 합격 기준

- 점광원을 화면 중앙에서 네 모서리와 화면 밖으로 이동시키는 animation sweep을 만든다.
- ghost 중심이 source–optical-center 선상에 있고 source와 반대 방향으로 연속 이동하는지 측정한다.
- T-stop, aperture blades, coating, focal length, source color/intensity를 sweep해 각 제어가 독립적이면서 일관되게 작동해야 한다.
- 어두운 배경과 밝은 배경에서 같은 source를 비교해 local contrast 적응을 확인한다.
- Elements Only에서 ghost, streak, veil, rays를 격리하고 element 에너지 합이 최종 결과와 일치하는지 검사한다.
- 시간축에서 source detection이 깜빡이거나 ghost 위치가 frame-to-frame로 튀지 않아야 한다.
- PSNR/SSIM/LPIPS는 기준 렌더 회귀에 사용할 수 있지만, 원 연구가 지적하듯 실제 ground truth에도 잔여 flare가 있을 수 있으므로 광학 규칙 검사와 전문가 눈 검사를 함께 사용한다.

## 5. Black Mist / White Mist

### 5.1 물리 현상과 두 종류의 차이

- Tiffen은 Pro-Mist가 미세 디테일을 부드럽게 하고 contrast를 낮추며 highlight 주변에 국소 flare를 더한다고 설명한다. Black Pro-Mist는 유사한 효과를 내면서 shadow를 덜 들어 올려 blacks를 더 잘 유지하고, highlight flare를 더 절제한다.  
  출처: [Tiffen Pro-Mist & Black Pro-Mist](https://tiffen.com/collections/explore-pro-mist%C2%AE-and-black-pro-mist-camera-filters), [Tiffen Black Pro-Mist](https://tiffen.com/products/6-6x6-6-black-pro-mist-filter)
- Schneider Hollywood Black Magic은 Micro-Lenslets와 carbon particles의 조합으로 제어된 highlight glow를 만들면서 rich blacks/colors와 in-focus image를 유지한다고 설명한다. 임상적으로 날카로운 디지털 센서 느낌을 줄이는 것이 목적이며, density는 1/8, 1/4, 1/2, 1, 2로 제공된다.  
  출처: [Schneider Diffusion & Mist Filters](https://schneiderkreuznach.com/en/cine-optics/filters/cine-filters/diffusion-and-mist), [Hollywood Black Magic Fact Sheet](https://schneiderkreuznach.com/application/files/8516/8024/4715/Fact_Sheet_Hollywood_Black_Magic_Schneider-Kreuznach.pdf)
- Hoya White Mist는 직접 광원 주변 halation, 전체 image/skin softening, contrast 감소를 만들며 Black Mist보다 diffusion이 강하다고 설명한다.  
  출처: [Hoya White Mist](https://hoyafilterusa.com/products/hoya-white-mist)

따라서 디지털 구현에서 Black Mist와 White Mist를 단순히 tint만 바꾼 같은 blur로 처리하면 안 된다.

- **Black Mist**: 국소 highlight glow와 피부 미세 디테일 완화는 존재하지만 black/shadow lift와 전체 veil은 제한한다.
- **White Mist**: 더 넓고 밝은 white glow, 더 강한 contrast 저하와 atmospheric veil을 허용한다.

`black particles가 검정을 보존하고 white particles가 검정을 들어 올린다` 같은 미세구조 설명은 모든 제조사 자료가 직접 입증하는 내용이 아니므로, 구현 근거로 단정하지 않고 위의 관찰 가능한 응답 차이를 목표로 삼는다.

### 5.2 상용 고급 구현의 특징

- highlight-localized flare, low-frequency veiling glare, high-frequency detail softening을 별도 경로로 계산한다.
- 단일 Gaussian blur가 아니라 중심과 긴 꼬리가 다른 multi-lobe PSF 또는 측정 기반 kernel을 사용한다.
- 눈, 머리카락, 직물 윤곽 같은 중·저주파 edge acuity는 유지하면서 피부의 매우 높은 주파수 shimmer를 완화한다.
- Black mode는 black floor와 shadow contrast를 보호하고 White mode는 veil과 highlight spread가 더 강한 별도 응답곡선을 가진다.
- 실제 필터의 density 단계는 선형 배수가 아니므로 1/8→1/4→1/2→1→2를 측정/시각 보정된 곡선으로 매핑한다.
- Schneider가 설명하는 focal length, f-stop, subject light 의존성을 Lens Context 파라미터 또는 프리셋에 반영한다.

### 5.3 권장 파라미터와 프리셋

| 그룹 | 권장 제어 |
|---|---|
| Type/Density | Black/White, 1/8, 1/4, 1/2, 1, 2 |
| Highlight | Threshold, Glow Amount, Radius, Tail, Highlight Protection |
| Veil | Diffusion/Veil, Contrast, Black Retention, White Lift |
| Detail | Skin Detail, Edge Acuity, Texture Frequency, Resolution |
| Color | Neutral/Warm, Bloom Saturation |
| Lens context | Focal Length, T-stop 또는 Compact/Normal/Tele response |
| Diagnostics | Glow Only, Veil Only, Detail Difference, Source Mask |

### 5.4 피해야 할 실패 형태

- Black과 White preset이 밝기나 tint만 다르고 black response가 같은 결과
- 화면 전체를 blur해 눈과 머리카락까지 초점이 나간 결과
- highlight threshold가 단단해 halo 테두리가 생기는 결과
- 강도를 올릴수록 검정이 회색으로 뜨고 색이 탈색되는 Black Mist
- White Mist가 단순 exposure lift처럼 작동하는 결과
- 고정 pixel radius 때문에 해상도와 Render Scale에 따라 다른 필터처럼 보이는 결과
- 광원 밝기 경계에서 glow가 시간축으로 켜졌다 꺼지는 pumping

### 5.5 QA 방법과 합격 기준

- 동일 노출의 point light, gray scale, ColorChecker/skin, slanted edge, fine texture를 한 프레임에 배치한다.
- density별 highlight PSF 반경·에너지, black level 변화, local/global contrast, MTF를 기록한다.
- 같은 density에서 Black은 White보다 shadow lift와 broad veil이 작아야 하며, 두 모드가 통계적으로도 구분돼야 한다.
- 눈/머리카락 edge MTF와 피부 texture ROI를 따로 측정해 `피부는 부드럽지만 초점은 유지`되는지 확인한다.
- focal length/T-stop/light intensity sweep에서 강도가 급변하지 않고 단조롭게 반응해야 한다.
- 피부 patch의 hue/ΔE가 의도한 Warm preset 외에는 과도하게 이동하지 않아야 한다.
- 영상에서 halo radius와 luminance를 추적해 temporal pumping을 검사한다.

## 6. Optical Blur / Bokeh

### 6.1 물리 현상

- Nikon은 depth of field가 초점이 허용 가능한 범위이며 focal length, aperture, sensor/circle of confusion에 따라 달라진다고 설명한다. 작은 조리개는 DOF를 늘리지만 지나치게 조이면 diffraction 때문에 해상도가 감소한다.  
  출처: [Nikon: Depth of Field](https://imaging.nikon.com/imaging/information/story/0022/)
- Nikon OPTIA는 spherical, coma, astigmatism, field curvature, chromatic aberration과 같은 wavefront aberration이 bokeh와 focus transition을 결정하며, wavefront 측정과 사람의 시각 평가를 함께 사용한다고 설명한다.  
  출처: [Nikon OPTIA](https://www.nikon.com/company/technology/stories/1909_optia/)
- ZEISS는 조리개 모양이 큰 defocus의 작은 점광원에서 주로 드러나며, 작은 defocus나 선형 피사체에서는 source의 형태와 방향이 더 중요하다고 설명한다. 모든 영역에 동일한 polygon disc를 찍는 방식은 실제 bokeh를 재현하지 못한다. 또한 구면수차의 under/over-correction은 전경과 배경 bokeh를 다르게 만들며 색수차는 초점 앞뒤에서 색 fringe 방향을 바꾼다.  
  출처: [ZEISS Depth of Field and Bokeh](https://lenspire.zeiss.com/photo/app/uploads/2022/02/technical-article-depth-of-field-and-bokeh.pdf)

### 6.2 상용 고급 구현의 특징

- 단일 blur radius가 아니라 aperture point-spread function(PSF)으로 convolution/splatting한다.
- aperture blades, roundness, rotation, cat-eye/vignetting, anamorphic ovality를 지원한다.
- spherical aberration에 따른 밝은 rim/center 분포와 전경·배경 비대칭을 모델링한다.
- longitudinal chromatic aberration은 green/magenta 또는 파장별 fringe를 초점 앞뒤에 다르게 적용한다.
- 화면 위치에 따라 bokeh 모양과 에너지가 달라지는 field-dependent PSF를 사용한다.
- depth map이 있으면 per-pixel circle of confusion과 occlusion-aware foreground/background 처리를 사용한다.
- depth map이 없으면 `Depth of Field`라고 과장하지 않고 uniform optical defocus 또는 selective matte blur로 명확히 정의한다.
- ZEISS CinCraft LensCore처럼 focus, T-stop, focal length, focus distance, real-lens profile을 하나의 일관된 렌즈 상태로 묶는 것이 고급 기준이다.  
  출처: [ZEISS CinCraft LensCore](https://www.zeiss.com/photonics-and-optics/us/cinematography/cincraft/lenscore.html)

### 6.3 권장 파라미터와 프리셋

| 그룹 | 권장 제어 |
|---|---|
| Focus | Defocus/Focus Distance, Depth Map/Matte, Near/Far Bias |
| Aperture | T-stop/Radius, Blade Count, Roundness, Rotation |
| Lens | Focal Length, Sensor/CoC, Lens Profile, Cat-eye, Field Curvature |
| Aberration | Spherical Aberration, Coma/Astigmatism, Chromatic Aberration |
| Bokeh | Highlight Gain, Edge/Rim, Center Fill, Anamorphism |
| Quality | Sample/Kernel Quality, Occlusion Quality, Edge Extension |
| Diagnostics | CoC Map, Near/Far Split, PSF Preview, Highlight Source Map |
| Presets | Clean Spherical, Vintage Swirl, Soft Portrait, Modern Anamorphic, Vintage Anamorphic |

### 6.4 피해야 할 실패 형태

- 전체 화면에 같은 모양·같은 크기의 polygon disc가 반복되는 결과
- depth/occlusion 없이 전경 blur가 배경 경계를 침범하는 결과
- 전경과 배경 bokeh가 완전히 같은 결과
- 중앙과 모서리 bokeh가 같아 cat-eye와 field behavior가 없는 결과
- highlight가 blur될 때 에너지가 증가하거나 감소해 노출이 변하는 결과
- chromatic fringe가 모든 edge에 고정 방향으로 붙는 결과
- 과도한 ring으로 double-line, onion-ring, harsh edge가 생기는 결과
- `Optical Blur`와 `Depth of Field`의 기능 범위를 UI에서 구분하지 않는 결과

### 6.5 QA 방법과 합격 기준

- focus ramp, depth edge, point-light grid, slanted line, foliage/texture, skin을 포함한 chart를 사용한다.
- aperture, focal length, focus distance, screen position, wavelength/source color를 sweep한다.
- PSF 에너지 보존, 중심/모서리 모양, near/far 비대칭, chromatic fringe 방향을 측정한다.
- depth mode에서는 foreground/background occlusion과 disocclusion hole을 검사한다.
- Nikon 방식처럼 wavefront/PSF 기반 객관 측정과 실제 bokeh/reference 영상에 대한 사람 눈 평가를 함께 시행한다.
- ZEISS가 지적한 것처럼 bokeh는 aperture와 imaging scale에 따라 크게 달라지므로 단일 정지 화면만으로 프리셋을 승인하지 않는다.

## 7. 색 관리와 OpenFX 처리 계약

### 7.1 장면 기준과 디스플레이 기준을 혼동하지 않는다

- Resolve Color Management는 Input, Timeline, Output color space를 분리하며, RAW는 camera primaries와 linear gamma를 기반으로 scene data를 보존해 timeline으로 보낼 수 있다. 플러그인이 입력을 무조건 Rec.709로 가정하면 Log/RAW, DaVinci Wide Gamut, HDR에서 물리 효과의 threshold와 색이 달라진다.  
  출처: [DaVinci Resolve 15 Reference Manual, Color Management](https://documents.blackmagicdesign.com/UserManuals/DaVinci_Resolve_15_Reference_Manual.pdf)
- ACES는 Input Transform으로 영상을 scene-referred ACES로 옮기고, creative Look Transform은 ACES-to-ACES로 Output Transform 전에 적용한다. Output Transform은 rendering과 display encoding을 담당한다.  
  출처: [ACES System Overview](https://docs.acescentral.com/background/overview/), [ACES Look Transforms](https://docs.acescentral.com/system-components/look-transforms/), [ACES Output Transforms](https://docs.acescentral.com/system-components/output-transforms/)

### 7.2 효과별 권장 작업 도메인

| 효과 | 권장 내부 도메인 | 이유 |
|---|---|---|
| Lens Reflections | scene-linear 또는 exposure-linear | 광원 에너지, local contrast, additive flare가 핵심 |
| Mist | scene-linear + perceptual detail branch | glow/veil은 광량 기반, 피부 texture 완화는 주파수·지각 기반 |
| Optical Blur | scene-linear RGB 또는 파장 근사 | 에너지 보존 PSF와 색수차 처리 |
| Halation | scene-linear source extraction + film/log composite | 강한 광원의 층별 확산과 highlight latitude 보존 |
| Film Grain | film/log density 또는 노출 반응 도메인 | 톤·색별 grain density와 print/display 독립성 |

권장 노드 순서는 물리적 발생 순서에 가깝게 `Lens Reflections / Mist / Optical Blur → Halation → Film Grain`이다. Grain은 광학 defocus 뒤에 배치해야 입자까지 렌즈 blur로 흐려지는 오류를 피할 수 있다. 개별 효과를 독립 OFX로 유지하더라도 README와 UI 도움말에 이 순서를 명시해야 한다.

### 7.3 플러그인 색 관리 인터페이스 수정 범위

- 모든 효과에 공통 `Working Space` 선택을 제공한다: Rec.709 Gamma 2.4, DaVinci Wide Gamut/Intermediate, ACEScct, Linear/custom transfer.
- 광량 기반 branch는 명시적 inverse transfer를 거쳐 linearize하고 결과를 원 도메인으로 되돌린다.
- input gamut과 transfer를 따로 표현하고, 단순 gamma 이름 하나로 색역까지 암묵 처리하지 않는다.
- `Output View`는 효과 자체를 바꾸는 transform이 아니라 진단용 preview일 때만 제공하고 명확히 표시한다.
- negative와 1.0 초과 float 값을 조기에 clamp하지 않는다. ACES는 포화 LED 등의 out-of-gamut/negative 값이 합성과 출력에서 artifact를 만들 수 있음을 경고한다.  
  출처: [ACES Reference Gamut Compression](https://docs.acescentral.com/rgc/overview/)
- SDR Rec.709뿐 아니라 HDR PQ/HLG 및 wide-gamut output에서 동일한 look intent가 유지되는지 검증한다.

### 7.4 OpenFX 계약

- OpenFX는 8-bit, 16-bit, half/32-bit float를 정의하고 32-bit float는 nominal 0–1 밖의 값을 허용한다. RGBA의 premultiplied/unpremultiplied 상태도 clip metadata로 전달된다.  
  출처: [OpenFX Images and Clips](https://openfx.readthedocs.io/en/main/Reference/ofxImageClip.html), [OpenFX Clip Preferences](https://openfx.readthedocs.io/en/main/Reference/ofxClipPreferences.html)
- 타일·ROI·Render Scale·pixel aspect ratio·row bytes를 가정하지 않고 host property를 따라야 한다.  
  출처: [OpenFX Rendering](https://openfx.readthedocs.io/en/main/Reference/ofxRendering.html)
- CPU와 Metal의 수치 일치는 표준이 자동으로 보장하지 않으므로 프로젝트가 자체 tolerance와 회귀 이미지를 정의해야 한다.
- temporal grain은 frame access 순서, cache, multi-thread render, random seek와 무관한 deterministic seed를 사용한다.
- alpha가 있는 영상은 straight/premult 변환을 올바르게 처리하고 RGB 효과가 투명 edge 밖으로 새지 않아야 한다.

## 8. 통합 QA 매트릭스

### 8.1 합성 테스트 소스

| 소스 | 검증 효과 |
|---|---|
| -10~+10 stop neutral/RGB ramps | threshold, HDR 보존, gamut, grain tonal response |
| 중앙·모서리·화면 밖 이동 point lights | halation, ghost path, flare, mist PSF, temporal stability |
| white rectangle와 thin line | halation edge, blur direction, hard contour |
| slanted edge / Siemens star / fine texture | MTF, detail softening, scale invariance |
| flat fields 여러 노출·색 | grain RMS/PSD/covariance |
| point-light grid + depth ramp | aperture PSF, cat-eye, near/far bokeh |
| skin/chart + practical lights | 피부 색·질감, mist, halation, flare |
| alpha checkerboard / semi-transparent edge | premultiplication과 spill |

### 8.2 실제 영상 매트릭스

- 공식 BRAW/ARRIRAW/Log 샘플과 Rec.709 영상
- 낮/밤, 피부, tungsten practical, saturated LED, backlight, specular metal
- 1080p, UHD, 8K, 12K 및 Proxy/Render Scale
- 정지 프레임, 느린 pan, 빠른 source movement, random seek
- SDR Rec.709, P3, HDR PQ/HLG output

### 8.3 수치 검증

- NaN/Inf 개수, negative 및 >1.0 값의 의도치 않은 clipping 여부
- CPU/Metal mean/max absolute error, SSIM/LPIPS. 초기 제안 tolerance는 deterministic 효과에서 linear normalized max error `≤ 1e-4`, SSIM `≥ 0.999`; stochastic grain은 동일 seed/frame이면 더 엄격한 일치를 목표로 한다. 실제 kernel 정밀도에 맞춰 기준을 확정한다.
- Render Scale/해상도별 물리 반경과 grain spatial-frequency 변화
- PSF 에너지, halo radius, ghost path collinearity, MTF, grain RMS/PSD/RGB covariance
- black level, local/global contrast, skin patch ΔE, highlight clipping 비율
- 반복 render, frame-order permutation, cache clear 전후의 결정성

### 8.4 시각 검증과 승인

- 모든 효과에서 `Effect Only/Mask/Elements`와 최종 composite를 함께 저장한다.
- 기본, 강함, 극단값을 따로 시험하되 프리셋 평가는 기본 강도에서 실시한다.
- 최소 세 종류의 실제 영상에서 동일 프리셋이 무너지지 않는지 확인한다.
- 100% 확대와 최종 시청 배율을 모두 확인한다. Grain은 축소 미리보기만으로 승인하지 않는다.
- 객관 수치는 회귀와 물리 일관성을 확인하는 도구이며 미학적 품질을 대신하지 않는다. 최종 프리셋은 reference 촬영 또는 제조사 공개 비교 자료와 blind A/B로 승인한다.

## 9. 구현 우선순위와 완료 정의

### P0: 공통 기반

- Working Space/inverse transfer/linear processing 공통 모듈
- HDR/negative-safe float pipeline, alpha, ROI, Render Scale
- 공통 multi-scale convolution/PSF와 diagnostic output
- CPU/Metal 공유 파라미터 계약과 golden-image harness

### P1: Halation 재설계

- 기존 warm bloom을 별도 `Bloom` 또는 legacy mode로 이동
- source/background-aware mask, local edge halo, global red glare, spectral controls
- Halation-only/source-mask QA와 실제 RAW 재검증

### P2: Grain 재설계

- exposure/color response curve, multi-scale clustered grain, stock/format model
- deterministic temporal synthesis, resolution-independent scale, luma/chroma diagnostics

### P3: Mist 재설계

- highlight glow, broad veil, detail softening을 분리
- Black/White의 black retention과 contrast response를 별도 모델로 구현
- density 단계와 skin/MTF/PSF QA

### P4: Lens Reflections 재설계

- source tracker와 optical-center geometry
- lens element profiles, aperture/coating/anamorphic models, temporal smoothing
- ghost path와 element diagnostics

### P5: Optical Blur 확장

- aperture PSF와 field-dependent cat-eye/aberration
- matte/depth 입력이 가능하면 occlusion-aware DOF 추가
- depth가 없을 때는 기능을 Optical Defocus로 정확히 제한

각 단계의 완료 조건은 `효과가 보인다`가 아니라 다음 네 가지를 모두 만족하는 것이다.

1. 공식 자료에서 도출한 물리적 움직임과 톤/색 반응 규칙을 만족한다.
2. CPU와 Metal, 해상도와 Render Scale, frame seek에서 회귀 기준을 통과한다.
3. 격리 진단 화면과 수치 측정으로 파라미터의 역할을 검증할 수 있다.
4. 실제 Log/RAW 영상과 SDR/HDR output에서 과장하지 않은 기본 프리셋이 상용 필터 수준의 자연스러운 결과를 낸다.

## 10. 주요 1차 자료 목록

### Film / Halation / Grain

- [Kodak: Exploring the Color Image](https://www.kodak.com/content/products-brochures/Film/Exploring-the-Color-Image.pdf)
- [Kodak Essential Reference Guide for Filmmakers](https://www.kodak.com/content/products-brochures/Film/kodak-essential-reference-guide-for-filmmakers.pdf)
- [Kodak Vision3 500T Technical Data](https://www.kodak.com/content/products-brochures/motion-picture/KODAK-VISION3-5219-7219-technical-information.pdf)
- [Fujifilm Professional Film Data Guide](https://asset.fujifilm.com/www/us/files/2020-03/3ab271f46f8d71c7e4c91bcedb7de050/ProfessionalFilmDataGuide.pdf)
- [Dehancer Film Grain](https://www.dehancer.com/learn/article/grain)
- [Dehancer Halation](https://www.dehancer.com/learn/article/halation)
- [FilmConvert Nitrate](https://www.filmconvert.com/nitrate)
- [FilmConvert Nitrate Controls](https://www.filmconvert.com/tutorials?Product=nitrate)
- [FilmConvert Halation Controls](https://www.filmconvert.com/tutorials?Product=halation)
- [DaVinci Resolve 19.1 New Features Guide](https://documents.blackmagicdesign.com/SupportNotes/DaVinci_Resolve_19_1_New_Features_Guide.pdf)

### Optical filters / Lens effects

- [Tiffen Diffusion Guide](https://tiffen.com/pages/diffusion-guide)
- [Tiffen Pro-Mist / Black Pro-Mist](https://tiffen.com/collections/explore-pro-mist%C2%AE-and-black-pro-mist-camera-filters)
- [Schneider Diffusion and Mist Filters](https://schneiderkreuznach.com/en/cine-optics/filters/cine-filters/diffusion-and-mist)
- [Hoya White Mist](https://hoyafilterusa.com/products/hoya-white-mist)
- [Canon Science Lab: Lens Coating](https://global.canon/en/technology/s_labo/light/003/03.html)
- [ARRI Master Anamorphic Lenses / Flare Sets](https://www.arri.com/en/cine-lenses/arri-zeiss-fujinon-lenses/master-anamorphics)
- [Boris FX Sapphire OFX LensFlare](https://borisfx.com/documentation/sapphire/ofx/lensflare/)
- [Nikon OPTIA](https://www.nikon.com/company/technology/stories/1909_optia/)
- [ZEISS Depth of Field and Bokeh](https://lenspire.zeiss.com/photo/app/uploads/2022/02/technical-article-depth-of-field-and-bokeh.pdf)

### Color management / Host contract

- [ACES System Overview](https://docs.acescentral.com/background/overview/)
- [ACES Look Transforms](https://docs.acescentral.com/system-components/look-transforms/)
- [ACES Output Transforms](https://docs.acescentral.com/system-components/output-transforms/)
- [ACES Reference Gamut Compression](https://docs.acescentral.com/rgc/overview/)
- [OpenFX Images and Clips](https://openfx.readthedocs.io/en/main/Reference/ofxImageClip.html)
- [OpenFX Clip Preferences](https://openfx.readthedocs.io/en/main/Reference/ofxClipPreferences.html)
- [OpenFX Rendering](https://openfx.readthedocs.io/en/main/Reference/ofxRendering.html)
