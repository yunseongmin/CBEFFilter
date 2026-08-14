# 05 — 완료 시점 연동 Frame Arena

**What to build:** 한 프레임 안의 임시 영상과 buffer를 재사용하되 GPU 작업이 끝나기 전에 덮어쓰지 않는 Frame Arena를 제공하여, v2 다중 패스 효과가 안정적인 메모리 안에서 렌더되게 합니다.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] 같은 device와 queue에서 크기·형식이 호환되는 임시 자원을 안정 상태에서 재사용합니다.
- [x] command buffer 완료 전에는 in-flight 자원을 다른 프레임이 재사용하거나 해제하지 않습니다.
- [x] 제품 렌더는 GPU 완료를 기다리지 않고 Enqueued를 반환하며, 테스트는 같은 queue의 completion 뒤 결과를 읽습니다.
- [x] 할당 실패와 잘못된 크기는 정의된 backend 오류로 끝나고 이미 확보한 자원은 누수 없이 정리됩니다.
- [x] 기존 다섯 효과의 pixel 결과, alpha, crop, identity와 queue ordering이 바뀌지 않습니다.
- [x] warm-up 이후 steady allocation과 임시 peak를 같은 성능 보고서에서 관찰할 수 있습니다.

## Answer

- queue별 Frame Arena가 크기와 storage mode가 맞는 Metal buffer를 보관하고 command buffer 완료 handler 이후에만 다시 빌려 줍니다.
- 모든 다중 패스 임시 buffer와 작은 weight·tap 업로드가 arena scope를 사용하며 제품 경로는 GPU 완료를 기다리지 않고 `Enqueued`를 유지합니다.
- focused 계약은 동시에 제출한 세 프레임에서 활성 slot 재사용 0건, completion 이후 재사용, 강제 할당 실패 후 in-flight 정리와 정상 회복을 확인했습니다.
- 관측 결과는 acquire 21건, 최대 동시 활성 14개, peak 167,773,040 bytes이며 JSON·JSONL 증거로 기록했습니다.
- `test-frame-arena`, M1~M6 CPU·Metal 계약, bundle build와 ABI probe가 Full Xcode 26.6 환경에서 모두 통과했습니다.
- 증거: `.omo/evidence/ticket-05-frame-arena.json`, `.omo/evidence/ticket-05-frame-arena.jsonl`, `.omo/evidence/ticket-05-m1-m6-build-test.log`, `.omo/evidence/ticket-05-abi-test.log`.
