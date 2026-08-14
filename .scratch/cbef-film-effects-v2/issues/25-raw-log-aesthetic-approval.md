# 25 — RAW·Log 유료급 미학 승인

**What to build:** 최소 다섯 실제 RAW·Log 장면에서 다섯 효과의 기본과 강한 설정이 광원·노출·배경·화면 위치가 달라져도 같은 필름·필터·렌즈 성격으로 보이는지 사용자가 직접 최종 승인합니다.

**Blocked by:** 24 — Resolve 무료판 Host Acceptance.

**Status:** ready-for-human

- [ ] 기준 릴에 피부·눈·머리카락, 창문·야간 practical, tungsten, 포화 LED·neon, 역광, shadow, fine textile, 흰 그래픽, frame-edge와 off-screen source가 포함됩니다.
- [ ] 각 장면에서 Baseline, Effect Only 또는 Mask·Elements, 기본, 강함과 극단값을 100% pixel view와 최종 시청 배율로 비교합니다.
- [ ] 정지 화면뿐 아니라 정상 속도 재생에서 Grain의 시간 질감, threshold flicker, ghost 이동, blur·mist 안정성을 판단합니다.
- [ ] Halation은 white bloom이나 고정 빨강 테두리, Mist는 초점 이탈, Grain은 디지털 noise, Lens는 불투명 복제상, Optical Blur는 균일 Gaussian처럼 보이지 않습니다.
- [ ] 사용자가 보유한 상용 효과와 blind A/B를 할 경우 품질 참고로만 사용하고 pixel 복제나 내부 구현 추정을 하지 않습니다.
- [ ] 기본 프리셋의 자연스러움과 강한 설정의 설득력을 각각 승인하며 screenshot 차이·MAE·SSIM만으로 합격시키지 않습니다.
- [ ] 사용자가 장면별 승인·수정 요청과 최종 verdict를 기록한 뒤에만 v2 미학 완료로 표시합니다.
