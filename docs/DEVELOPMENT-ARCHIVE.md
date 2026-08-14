# CBEF Filter v2 개발 아카이브

## 현재 기준선

- 제품 버전: `2.0.0`
- 효과: Halation, Film Grain, Mist Diffusion, Optical Blur, Lens Reflections
- 호스트: Apple Silicon macOS, DaVinci Resolve 21 Free
- 실행 구조: typed compiled plan → CPU reference 또는 precompiled Metal backend
- 최종 자동 판정: [PASSED](evidence/v2-final-20260812/verdict.md)
- 실제 카메라 원본 판정: [다섯 BRAW 장면 PASS](evidence/host-acceptance/visual-qa-20260812.md)

## 개발 중 확정된 주요 수정

- Halation은 profile-relative·Film Red·Warm Amber·Neutral White와 장면 반응형 Auto Color를 지원합니다.
- Film Grain은 stock/capture/scan/population을 분리하고 CPU·Metal 48-frame 통계를 일치시킵니다.
- White Mist의 강한 설정에서 발생하던 음의 edge polarity를 exact·UHD pyramid 양쪽에서 제거했습니다.
- Optical Blur는 field PSF, cat-eye, coma, astigmatism, field focus, chromatic aberration을 같은 sampling 정책으로 처리합니다.
- Lens Reflections는 자동·수동 source, optional external Matte, signed-axis element model과 GPU top-8 선택을 지원합니다.
- Lens의 미연결 Matte가 필수 clip으로 기술되어 Resolve가 source fallback하던 문제를 optional clip 계약으로 수정했습니다.

세부 모델과 수치 근거는 [설계 문서](design/premium-film-effects-revision-scope.md), 효과별 회귀는
[QA 문서](qa/), 구현 순서와 판단 이력은 `.scratch/cbef-film-effects-v2/`에 남아 있습니다.

## 보존 산출물

| 산출물 | SHA-256 |
| --- | --- |
| 현재 OFX executable | `895d9019d5e65fc6cbf6b9a7931f5c0bd33d620e59d726b75604513d89672e0d` |
| 현재 Metal library | `f214acd4f4943f0d92de49f9c22cc3dd4d47d42f9d02f16fe16925154316271a` |
| 개인 복구 DMG | `c932d3dbc53f98aef6c4d8136c31842b808cb655ff21dc2667bf3ecec4f1daa0` |

복구 DMG와 `.sha256`은 `releases/`에 있으며 `make clean`의 영향을 받지 않습니다. 대용량 RAW와
host 영상은 제거했으며 공식 URL·크기·해시는 `assets/qa/raw-footage/download-provenance.json`에
남겼습니다. 실제 Resolve 판정은 이미지 대신 `docs/evidence/host-acceptance/`의 텍스트 보고서로
보존합니다.
