# 02 — M1: Headless Render Contract와 공통 색·알파 Module

**What to build:** 사용자가 어떤 효과를 선택해도 동일한 설정 방식, 색공간 처리, 알파 보존과 CPU·Metal 완료 의미를 얻도록 Render Core Module과 두 RenderBackend adapter를 완성합니다.

**Blocked by:** 01 — M0: Resolve 무료판에 설치되는 다섯 효과 tracer bullet

**Status:** resolved

- [x] Effect Definition 한곳에서 다섯 효과의 stable parameter ID, type, 범위, increment, 기본값, preset expansion, Custom 전환, Reset, identity predicate와 Output View를 제공합니다.
- [x] RenderRequest와 FrameSurface가 format, bounds, stride, render window, non-aliasing, ownership과 window 밖 byte 보존 계약을 강제하며 모든 명세 오류를 정확한 Failed(error)로 반환합니다.
- [x] CPU는 Completed, Metal은 주입된 host queue에 모든 command buffer를 commit한 뒤 Enqueued를 반환하며 sentinel 방식으로 완료 후 결과를 읽을 수 있습니다.
- [x] Final identity는 hidden RGB가 있는 straight alpha 0 fixture까지 RGBA float bit pattern을 정확히 복사하고 window 밖 destination을 바꾸지 않습니다.
- [x] 비-identity straight·premultiplied 처리, transparent-edge 차단과 bit-identical alpha 보존이 공통 fixture를 통과합니다. 공간 alpha-weighted sampling은 M2+ 공간 알고리즘이 생기는 시점에 이 공통 alpha 계약 위에서 구현합니다.
- [x] DWG Intermediate, DWG Linear, Rec.709 Gamma 2.4의 transfer·primaries·D65 변환, 음수·near-zero·HDR 보존과 roundtrip 허용오차를 통과합니다.
- [x] Final의 linear Mix, component/matte encode 순서와 diagnostic view의 Mix 무시 규칙이 Headless Render Contract에서 관찰됩니다.
- [x] CPU·실제 Metal 공통 fixture가 2e-4 parity, finite output, invalid-request, non-zero origin과 padded stride 검증을 통과하고 affected build가 성공합니다.

## Completion evidence

Artifact: `m1-headless-render-contract-2026-08-12`

| Check | Result |
|---|---|
| Affected bundle build | `make build` — exit 0, compiler warnings 0 |
| Focused CPU + actual Metal contract | `make test-m1` — exit 0, `PASS (CPU + Metal M1 contract)` |
| Metal completion proof | Supplied `MTLCommandQueue`, committed command buffer, then a same-queue sentinel command buffer confirms readable destination; production backend contains no completion wait. |
| Observable GPU assertions | CPU–Metal maximum error ≤ `2e-4`, premultiplied alpha bit identity, finite RGB, partial render-window preservation, and Metal identity RGBA bit copy. |
| Host boundary | OFX Filter/float RGBA descriptors use the five stable Core effect IDs, define Core-owned parameters/defaults/choices, apply presets without changing Working Mode/Output View/Mix, and submit CPU or supplied-queue Metal `RenderRequest`s. |

Resolve was intentionally not launched for M1 under the lightweight policy. M2+ effect algorithms remain out of scope; this milestone owns only the common scaffold and execution contract.

## Comments

- 2026-08-12: M1 acceptance criteria were completed by the CPU and actual Metal focused contract suite. Artifact: `m1-headless-render-contract-2026-08-12`.
