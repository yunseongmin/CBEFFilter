# CBEF Halation Lightroom Classic 플러그인

Lightroom Classic 15.5용 Export Filter입니다. Lightroom SDK에는 Develop 픽셀 효과를 실시간으로 추가하는 API가 없으므로, 이 플러그인은 **Export > Post-Process Actions**에서 렌더링된 파일을 외부 엔진으로 후처리합니다.

## 설치 및 사용

1. `CBEFHalation.lrplugin` 폴더를 Lightroom의 Plug-in Manager에서 추가합니다.
2. `LightroomHalation/bin/halation-engine` 실행 파일을 플러그인 폴더의 부모 디렉터리에 둡니다.
3. 사진을 내보낼 때 Export dialog의 **Post-Process Actions**에서 `CBEF Halation (Export Post-Process)`를 선택합니다.
4. 프리셋을 고른 뒤 Halation, Bloom, Grain, Lens, Fade/Contrast/Saturation 값을 조정하고 출력 모드(`final`, `halo`, `matte`)를 선택합니다.

## Engine invocation contract

각 렌더링 결과마다 플러그인은 사용자 입력을 범위 검증한 뒤 다음 형태로 실행합니다. 파일 경로와 mode는 shell-safe single quoting을 적용하고, 숫자는 검증된 숫자만 생성합니다.

```text
bin/halation-engine --input PATH --output TEMP_PATH \
  --halation-amount N --halation-radius N --threshold N --softness N --warmth N \
  --bloom-amount N --bloom-radius N --grain-amount N --grain-size N \
  --vignette N --chromatic-aberration N --fade N --contrast N --saturation N \
  --mode final|halo|matte
```

엔진은 별도 임시 파일에 기록해야 하며, 성공한 경우 플러그인이 원본을 임시 백업으로 이동한 뒤 결과를 승격합니다. 승격이 실패하면 백업에서 원본을 복구합니다. 엔진 종료 코드가 0이 아니거나 임시 결과가 없으면 해당 rendition은 실패로 표시되고 임시 파일은 삭제됩니다.

## 지원 범위

필터는 JPEG/TIFF/PNG 등 Lightroom이 렌더링할 수 있는 정지 이미지에 사용하도록 설계되었습니다. 비디오와 Develop 모듈의 실시간 미리보기는 지원하지 않습니다.
