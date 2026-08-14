# CBEF Filter QA 자산

이 폴더에는 실제 Resolve 품질 확인에 사용했던 외부 자산의 출처와 해시만 보관합니다.
대용량 영상 자체는 프로젝트에 포함하지 않습니다.

## 구성

- `qa/raw-footage/download-provenance.json`: Blackmagic 카메라 원본 5개와 sidecar의 공식 URL,
  크기, SHA-256, 취득·검증 기록

원본 ZIP, BRAW, sidecar와 host MOV fixture는 개발 완료 후 제거했습니다. 다시 시각 QA가 필요하면
manifest의 공식 URL에서 필요한 장면만 내려받고 기록된 SHA-256으로 확인합니다. 자동 CPU·Metal
계약은 외부 영상 없이 `fixtures/quality/`의 작은 deterministic fixture만 사용합니다.

## 권리와 사용 범위

카메라 원본과 파생 캡처는 CBEF Filter의 개인용 내부 QA에만 사용합니다. 재배포하지 않습니다.
Blackmagic Design과 원 제작자가 모든 권리를 보유하며, 추가 사용은 제조사 갤러리의 현재 이용 조건을
따릅니다.

현재 프로젝트에는 `.braw`, `.mov`, `.mp4` 같은 샘플 영상 파일이 없습니다.
