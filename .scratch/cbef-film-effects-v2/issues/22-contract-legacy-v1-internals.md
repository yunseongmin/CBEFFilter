# 22 — v1 내부 구조 제거와 v2 계약 확정

**What to build:** 다섯 효과의 v2 CPU·Metal 경로가 완성된 뒤 임시 expand 구조와 v1 알고리즘을 제거하여, 사용자가 숨은 legacy mode 없이 하나의 명확한 v2 제품을 사용하게 합니다.

**Blocked by:** 08 — 할레이션 Metal 산란 피라미드; 11 — 미스트 Metal 품질과 UHD 성능; 14 — 필름 그레인 Metal 통계 일치; 17 — 광학 블러 Metal PSF 샘플링; 21 — 렌즈 반사 Metal Element 투영.

**Status:** resolved

- [x] 렌더 가능한 제품 경로에서 v1 효과 수학, 공용 all-effect 설정 묶음, runtime Metal source와 임시 migration adapter가 제거됩니다.
- [x] v2 안에 legacy algorithm 선택, 자동 설정 migration 또는 backward-compatibility shim을 남기지 않습니다.
- [x] 다섯 stable effect ID와 설치 패키지 이름은 유지하되 plugin major version과 v1 수동 백업·복구 절차가 명확히 구분됩니다.
- [x] Final identity, 오류, 색, HDR, alpha, crop, resolution, queue와 diagnostics 공통 계약이 다섯 효과 모두에 동일하게 적용됩니다.
- [x] 기존 M1~M6 계약은 v2 관찰값에 맞게 확장되고 삭제되거나 약화되지 않은 채 통과합니다.
- [x] 사용되지 않는 v1 preset명, `No Remjet` 주장, 실제 stock·filter·lens를 가장하는 generic label과 죽은 shader 경로가 남아 있지 않습니다.

**Answer:**

CPU와 Metal backend는 이제 `CompiledEffectPlan`의 typed variant를 직접 소비합니다. 공용 all-effect projection, `effectGain`, `scaffold_gain`, `renderPlanFromCompiled`, scaffold fallback과 죽은 pyramid shader를 제거했습니다. 작은 Grain reference 경로와 identity copy도 v2 이름과 전용 계약으로 분리했습니다. 다섯 effect ID와 `CBEFFilmEffects.ofx.bundle` 이름은 유지하면서 OFX major를 2, bundle version을 `2.0.0`으로 올렸습니다. 설치 스크립트는 기존 1.x 번들을 덮어쓰지 않고 별도 v1 backup으로 이동하며, README에 수동 복구 절차를 기록합니다.

**Evidence:** `docs/evidence/v2-final-20260812/`
