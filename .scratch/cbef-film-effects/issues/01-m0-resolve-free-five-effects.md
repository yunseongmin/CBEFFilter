# 01 — M0: Resolve 무료판에 설치되는 다섯 효과 tracer bullet

**What to build:** Apple Silicon Mac 사용자가 번들 하나를 설치한 뒤 Resolve 무료판에서 다섯 설치형 효과를 발견하고, 원본을 안전하게 통과시키는 상태로 적용할 수 있게 합니다.

**Blocked by:** None — can start immediately

**Status:** resolved

- [x] Apple Command Line Tools로 arm64 OpenFX 번들 하나가 clean build되며 DCTL, Fusion, Studio 기능과 유료 라이브러리를 사용하지 않습니다.
- [x] 번들은 명세의 vendor·group·다섯 stable effect ID를 등록하고 각 효과를 Filter context와 float32 RGBA로 선언합니다.
- [x] 다섯 효과의 M1~M6 CPU·Metal 구현과 잘못된 clip/format 방어 계약이 자동 테스트를 통과합니다.
- [x] 공식 OpenFX 코드의 필요한 라이선스 고지가 보존되고 Windows·Linux·Intel·서명·공증 작업을 추가하지 않습니다.
- [x] 사용자 OpenFX 위치에 설치하고 Resolve Free를 실행했을 때 다섯 효과가 같은 group에 나타납니다.
- [x] 대표 효과 Halation을 Color 페이지 노드에 적용해 실제 파라미터 패널과 Studio badge·watermark·DCTL 요구 부재를 확인합니다.
- [x] OS·Resolve·bundle hash, 효과 목록, Color 적용 화면을 M0 smoke evidence로 남깁니다.

## Comments

- 2026-08-12: arm64 build, ABI probe, M1~M6 CPU·Metal 회귀가 통과했습니다. 번들을 `~/Library/OFX/Plugins`에 설치하고 해당 경로로 Resolve Free 21.0.4를 실행했습니다. Resolve 로그에서 다섯 ID 로드를 확인했고 Color 페이지에서 한 group의 다섯 효과와 Halation 노드 적용·파라미터 패널을 확인했습니다. 시스템 전역 설치는 여전히 관리자 암호가 필요한 선택 사항입니다. 증거는 [M0 smoke evidence](../../../docs/qa/m0-resolve-free-smoke.md)에 있습니다.
