# 12 — 필름 그레인 Stock Response와 Capture Format

**What to build:** 유제의 노출 반응과 촬영 포맷·스캔·표시 확대를 분리하여, 해상도와 포맷을 바꿔도 같은 필름 면적에서 비롯된 자연스러운 입자 크기와 세기를 얻도록 합니다.

**Blocked by:** 01 — 품질 기준 영상과 근거 기록; 02 — 효과별 설정 컴파일 구조 확장; 03 — v2 Inspector 메타데이터와 조작 흐름.

**Status:** resolved

- [x] Inspector에서 Stock Response, Capture Format, scan sampling, processing modifier와 display scale을 서로 독립적으로 선택할 수 있습니다.
- [x] 제조사 stock 이름은 측정 profile이 있을 때만 사용하고 기본 제공 profile은 generic 성격으로 표시됩니다.
- [x] 같은 seed·frame·설정은 bit-identical하고 random seek와 subframe quantization 뒤에도 같은 output frame을 재현합니다.
- [x] Capture Format과 표시 배율은 canonical grain scale만 바꾸고 Stock Response의 노출 곡선이나 color record 성격을 몰래 바꾸지 않습니다.
- [x] 1080p·UHD·8K와 Render Scale에서 정규화된 입자 크기와 PSD가 정한 해상도 일관성 안에 있습니다.
- [x] black·white 끝점 감쇠, HDR·signed RGB, alpha, crop와 identity 계약을 CPU reference에서 통과합니다.

## Answer

기존 `format`과 `size` 저장 ID/ordinal은 유지하면서 Inspector 표시를 각각 `Capture Format`과 `Display Scale`로 분리했습니다. `stock_response`, `scan_sampling`, `processing_modifier`는 ordinal 13–15에 추가되었고, 현재 구현은 Sol 확정 계획의 Generic Fine/Balanced/Fast 및 Choice형 2K/4K/8K·Normal/Gentle/Enhanced 표기와 일치합니다. 티켓13의 공유 Grain 메타데이터 교정 후 focused suite를 재실행해 통과를 확인했습니다.

CPU reference는 공개 render seam을 통해 기존 counter RNG/frame quantization과 data-window height normalization을 유지합니다. focused suite에서 stock RMS ordering, format/scan 독립성, processing monotonicity, random seek/subframe bit identity, black/white endpoint, signed HDR, alpha, crop, 4320-line data-window crop을 통과했고, Inspector·affected build·ABI 회귀도 통과했습니다.

## Implementation evidence

- [`verification.md`](../../../.omo/evidence/ticket12-grain-stock-20260812/verification.md)
- [`validation.log`](../../../.omo/evidence/ticket12-grain-stock-20260812/validation.log)
- [`validation.exit`](../../../.omo/evidence/ticket12-grain-stock-20260812/validation.exit)
- [`direct-audit-20260812-r2.md`](../../../.omo/evidence/ticket12-grain-stock-20260812/direct-audit-20260812-r2.md)
