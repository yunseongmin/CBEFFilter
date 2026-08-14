# 09 — Generic Black·White 미스트 Glow와 Veil

**What to build:** 미스트 확산을 단순 화면 블러가 아닌 광원 Glow와 전역 Veil의 조합으로 만들고, Generic Black과 Generic White가 같은 Grade에서도 대비를 다르게 보존하도록 합니다.

**Blocked by:** 01 — 품질 기준 영상과 근거 기록; 02 — 효과별 설정 컴파일 구조 확장; 03 — v2 Inspector 메타데이터와 조작 흐름; 06 — 장면 반응형 할레이션 광원과 국소 산란.

**Status:** resolved

- [x] Inspector는 제조사명을 사용하지 않는 Generic Black·Generic White profile과 Density가 아닌 Grade를 표시합니다.
- [x] Glow와 Veil을 독립적으로 조절하고 Glow Only, Veil Only, Source Mask 진단 출력을 볼 수 있습니다.
- [x] 같은 Grade에서 Generic White는 더 넓은 white glow와 broad veil을, Generic Black은 더 높은 저주파 black retention을 보입니다.
- [x] Grade 증가에 따라 glow radius·energy와 veil이 profile 방향으로 연속적이고 단조롭게 변합니다.
- [x] 중성 profile이 피부색이나 중성 patch를 과도하게 이동시키지 않고 강한 설정에서도 단순 초점 이탈로 무너지지 않습니다.
- [x] point source, dark patch, 국소 대비, HDR·signed RGB, alpha, crop와 edge 기준 영상에서 CPU reference gate를 통과합니다.

## Answer

Mist v2 CPU reference는 `Generic Black`과 `Generic White`를 상표명 없는 profile family로 노출하고, 기존 Density 표기를 profile-relative `Grade` 단계로 변경했습니다. Glow와 Veil은 서로 다른 산란 branch와 독립 control로 계산되며 `Glow Only`, `Veil Only`, `Source Mask` 진단 출력은 public `render(RenderRequest, CpuRenderBackend)` seam에서 직접 확인할 수 있습니다.

동일 Grade에서 White는 profile radius와 veil contrast 방향을 더 넓게, Black은 highlight 중심 외부의 veil lift를 제한하여 저주파 암부 보존을 더 높게 유지합니다. Grade별 반경·에너지 방향은 synthetic placeholder profile로 연속·단조하게 검증하며, 실제 필터 계측값을 주장하지 않습니다. Detail shaping은 별도 ticket 10 범위로 남기고 현재 `Detail Retention` control만 유지했습니다.

중성 scene-linear source, signed HDR, straight alpha, crop/non-zero origin, edge clamp, transparent hidden RGB와 alpha bit 보존을 포함한 CPU contract가 통과했습니다. Metal parity와 UHD 성능은 ticket 11의 범위입니다.

## Implementation evidence

- Fresh ticket-scoped validation (Xcode 26.6 via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`) is recorded in [`ticket09-mist-glow-veil-20260812-luna`](../../../.omo/evidence/ticket09-mist-glow-veil-20260812-luna/summary.txt).
- `make -B test-v2-mist-cpu`: PASS, including metadata vocabulary, branch diagnostics/reconstruction, independent zero controls, Black/White direction, Grade monotonicity, neutral safety, signed HDR, alpha, crop and edge cases.
- `make -B test-m4-cpu`: PASS for the relevant legacy CPU Mist contract; `make -B test-v2-compile`, `make -B test-v2-inspector`, `make -B build`, and `make -B test`: PASS.
