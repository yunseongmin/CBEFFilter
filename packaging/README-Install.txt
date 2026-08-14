CBEF Filter 2.0.0 개인 복구본
==============================

포맷 후 설치 순서
-----------------
1. Apple Silicon Mac에 DaVinci Resolve를 설치합니다.
2. DaVinci Resolve가 실행 중이면 완전히 종료합니다.
3. CBEFFilter-2.0.0.pkg를 더블클릭합니다.
4. macOS 관리자 암호를 입력해 설치를 승인합니다.
5. DaVinci Resolve를 다시 실행하고 Effects의 CBEF Film Effects 그룹을 확인합니다.

인터넷, Xcode, OpenFX SDK는 설치 과정에 필요하지 않습니다.
설치 프로그램은 완성된 플러그인과 Metal 라이브러리를 다음 위치에 복사합니다.
  /Library/OFX/Plugins/CBEFFilmEffects.ofx.bundle

기존 CBEF Film Effects 1.x가 있으면 다음 위치에 한 번만 백업합니다.
  /Library/OFX/CBEFBackups/CBEFFilmEffects-v1-backup.ofx.bundle

삭제
----
DaVinci Resolve를 종료한 뒤 "Uninstall CBEF Filter.command"를 더블클릭합니다.

보관 권장
---------
DMG 파일과 함께 제공되는 .sha256 파일을 외장 저장장치나 클라우드에 같이 보관하세요.
BUILD-MANIFEST.txt에는 플러그인 바이너리, Metal 라이브러리, PKG의 SHA-256이 기록됩니다.

서명 안내
---------
이 파일은 개인용 ad-hoc 서명본이며 Developer ID 배포 서명·Apple 공증본은 아닙니다.
본인 Mac에서 개인적으로 복구 설치하는 용도입니다.
클라우드나 외장 저장장치에서 복사한 뒤 macOS가 실행을 차단하면 PKG를 Control-클릭해
"열기"를 선택하세요. 그래도 차단되면 시스템 설정 > 개인정보 보호 및 보안에서
해당 설치 프로그램의 "확인 없이 열기"를 선택한 뒤 다시 실행합니다.
