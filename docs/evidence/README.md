# 보존 QA 증거

중간 디버그 로그와 반복 재검증 산출물 대신, 제품 판정에 직접 필요한 자료만 이 폴더에 보존합니다.

| 경로 | 내용 |
| --- | --- |
| `v2-final-20260812/` | 최신 v2 clean build, CPU·Metal, ABI, 8K·12K, 성능·메모리 최종 판정 |
| `host-acceptance/` | Resolve 21 Free에서 실제 BRAW에 적용한 다섯 효과의 텍스트 판정 |
| `feature-fixes/` | Halation Auto Color, White Mist edge polarity의 설계·검증 요약 |

최종 자동 판정은 [`v2-final-20260812/verdict.md`](v2-final-20260812/verdict.md), 실제 호스트 판정은
[`host-acceptance/visual-qa-20260812.md`](host-acceptance/visual-qa-20260812.md)를 기준으로 합니다.
대용량 원본과 캡처 이미지는 포함하지 않습니다. 외부 RAW의 출처·해시는
[`../../assets/`](../../assets/README.md)에 남겨 필요할 때만 다시 받을 수 있습니다.
