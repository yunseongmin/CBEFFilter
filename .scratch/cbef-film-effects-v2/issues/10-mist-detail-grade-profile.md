# 10 — 미스트 Detail 보존과 Grade profile

**What to build:** Glow·Veil과 별도로 중간 주파수 Detail을 제어하여, 피부는 부드럽게 하면서 눈·머리카락·직물과 장면의 초점 인상은 유지되는 고급 미스트 profile을 제공합니다.

**Blocked by:** 09 — Generic Black·White 미스트 Glow와 Veil.

**Status:** resolved

- [x] Detail 제어가 Glow와 Veil의 크기·에너지를 바꾸지 않고 피부 고주파와 눈·머리카락·직물의 중간 주파수를 구분해 반응합니다.
- [x] Detail Difference 진단 출력과 Glow Only·Veil Only가 정한 내부 허용치 안에서 Final contribution을 재구성합니다.
- [x] 각 Generic profile의 Grade 단계가 glow·veil·detail 변화 곡선을 소유하며 단계 전환에서 튀지 않습니다.
- [x] slanted edge relative MTF, 피부 질감, 눈·머리카락 edge와 평탄 영역에서 Detail 변화가 정한 방향으로 측정됩니다.
- [x] 실제 필터 계측값이 없는 Black·White 비율과 MTF 수치는 임시값으로 표시되고 measured profile로 오인되지 않습니다.
- [x] 기본 프리셋은 자연스러운 대비와 피부 질감을 보존하고 강함·최대 설정은 finite·no-wrap·alpha 안전성을 유지합니다.

## Answer

Mist CPU reference에 Grade 2 단계와 `Detail Difference` ordinal 6을 추가하고, 기존 parameter ID와 ordinal은 유지했습니다. Glow와 Veil은 서로 다른 반경·tail 계수를 소유하며, Glow는 양의 C1 residual, Veil은 contrast 응답을 소유합니다. Detail은 alpha-weighted fine/mid Gaussian 분리와 gradient 기반 edge protection으로 계산하고, Texture 100은 detail contribution을 0으로 만듭니다. Final은 Glow·Veil·Detail contribution의 합으로 구성됩니다.

실측 필터 계수나 stock 동등성을 주장하지 않도록 계수는 내부 placeholder이며, deterministic semantic fixture의 measured-profile gate는 false입니다. Metal parity는 ticket 11 소유입니다.

## Implementation evidence

- [`summary.txt`](../../../.omo/evidence/ticket10-mist-detail-20260812/summary.txt)
- `make -B test-v2-mist-cpu`: PASS
- `make -B test-v2-compile`: PASS
- `make -B test-v2-inspector`: PASS
- `make -B build`: PASS
- `fixtures/quality/manifest.json`: integrated `mist-detail-frequency` fixture with all `measured_profile_gate: false`
