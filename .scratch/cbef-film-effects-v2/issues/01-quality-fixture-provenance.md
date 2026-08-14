# 01 — 품질 기준 영상과 근거 기록

**What to build:** 다섯 시네마 마감 효과를 같은 기준으로 비교할 수 있도록, 저장소에서 재현 가능한 scene-linear 기준 영상과 각 측정값의 출처·권리·용도를 함께 기록하는 품질 기반을 만듭니다.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] 노출·색상 ramp, 평탄 영역, 점광원 sweep·grid, slanted edge, 얇은 선, 간판·LED, 알파 경계, 화면 위치별 PSF 기준 영상을 재현할 수 있습니다.
- [x] 각 기준 영상은 생성기 버전, 색 인코딩, 해상도, frame·crop, 예상 mask, hash와 측정 항목을 manifest에 기록합니다.
- [x] 각 합격 수치는 표준 측정법, 실측값, 프로젝트 내부 허용치, 임시값 중 하나로 분류되며 실제 물성처럼 과장되지 않습니다.
- [x] 외부 RAW·Log 원본은 로컬 전용 cache만 사용하고 공식 URL, hash, 취득일, 약관, decode·색 변환 정보만 저장소에 남깁니다.
- [x] 재배포 또는 상업 사용 권리가 불명확한 자산은 설치 번들, 공개 기준 crop, 자동 테스트 산출물에 포함되지 않습니다.
- [x] 최상위 렌더 계약을 통해 v1 기준 결과와 v2 목표 측정값을 같은 보고서 형식으로 비교할 수 있습니다.

## Answer

구현을 완료했습니다.

- `fixtures/quality/generate_fixtures.py`가 노출·색상 ramp, 평탄 영역, 점광원 sweep·grid, slanted edge, 얇은 선, signage/RGB LED, 알파 경계, 화면 위치별 PSF를 deterministic scene-linear RGBA float32 소스로 생성합니다.
- `fixtures/quality/generated/`에 8개 기준 영상과 semantic mask sidecar를 생성하고, `fixtures/quality/manifest.json`에 generator version, color encoding, resolution, frame, crop, mask labels, frame/mask SHA-256을 기록했습니다.
- 모든 metric은 `standard`, `measured`, `internal tolerance`, `placeholder` 중 하나로 분류합니다. placeholder metric에는 measured-profile 승인 역할을 부여하지 않았습니다.
- `fixtures/quality/local-assets/.gitignore`와 manifest record schema로 외부 RAW/Log는 local-only cache에만 두고 URL, hash, 취득일, 약관, clip/frame, decode, color transform, 명시적 재배포 권리를 요구합니다. 현재 외부 asset record는 0건입니다.
- `fixtures/quality/render_report.py`가 최상위 RenderRequest/RenderSubmission 결과를 v1 baseline과 v2 candidate의 동일 JSON/Markdown 비교 형식으로 검증·비교합니다. 내부 kernel이나 fake host seam은 노출하지 않습니다.
- `tests/quality_fixture_test.py`의 3개 테스트가 고정 산출물 hash, 두 번 생성한 byte 재현성, finite/HDR/alpha 안전성, mask와 provenance 정책, report bridge를 검증합니다.

검증 명령:

```text
python3 -m py_compile fixtures/quality/generate_fixtures.py fixtures/quality/render_report.py tests/quality_fixture_test.py
python3 -m unittest tests/quality_fixture_test.py -v
```

결과: 3 tests, `OK`. 상세 증거는 [`ticket-01-quality-fixture-2026-08-12.md`](../../../.omo/evidence/ticket-01-quality-fixture-2026-08-12.md)에 기록했습니다. 이번 티켓은 Python fixture 인프라만 변경하므로 C++/Metal affected target build는 요구되지 않았습니다.

## Comments

Stop-hook 재검증에서 fixture focused suite와 checked-in hash/float audit은 다시 통과했습니다. 별도로 `make test-m1-cpu`를 실행했으나 현재 환경에 `xcrun metal` compiler가 없어 metallib 단계에서 종료되었고, 기존 `build/tests/headless_render_contract` 직접 실행은 기존 Metal Enqueued 계약 오류를 보고했습니다. 두 실패는 이 티켓이 소유한 Python fixture/report 파일과 무관하며, 상세 기록은 [`ticket-01-verification-rerun3-2026-08-12.md`](../../../.omo/evidence/ticket-01-verification-rerun3-2026-08-12.md)에 남겼습니다.
