# 공식 카메라 RAW/Log 로컬 QA 소스 조사

> 조사·메타데이터 검증일: 2026-08-12 (KST)  
> 범위: 제조사 공식 1차 출처만 사용. 대용량 원본은 다운로드하지 않고 HTTP 헤더, 공식 카탈로그 메타데이터, FTPS `SIZE`로만 존재 여부를 확인했습니다.  
> 결론: **제조사 다양성을 우선한 최소 세트는 Blackmagic 2장면 + RED 3장면 + ARRI 1장면, 총 6장면/약 7.4 GB**입니다. Sony와 Canon은 아래 사유로 보류합니다.

## 반드시 지킬 권리 경계

이 목록은 공개 배포용 미디어 라이브러리가 아닙니다. **원본, 압축 파일, 프록시, 스틸, 해시 외 메타데이터를 저장소·릴리스·테스트 번들·CI 캐시·스크린샷에 재배포하지 마십시오.**

- Blackmagic 갤러리 파일은 원 창작자가 국제 저작권을 유지하며, 원본과 그레이드 결과 비교를 위해 제공됩니다. Blackmagic의 권리 모달은 다른 목적의 사용·공유에는 창작자의 직접 허가가 필요하다고 명시합니다. 따라서 CBEF 내부 비교 QA가 게시 목적에 포함된다고 권리 담당자가 판단한 경우에만 사용하고, 외부 공유는 별도 허가 없이는 금지합니다. ([Blackmagic 권리 모달](https://www.blackmagicdesign.com/products/blackmagicursaminipro/modal/copyright-and-privacy))
- RED는 샘플을 **내부 테스트 전용**으로 제공하며, 그 밖의 상업·비상업 사용을 금지하고 저작권을 RED가 보유한다고 명시합니다. 로컬 QA에는 가장 명확히 부합하지만 재배포·홍보 이미지 사용은 금지입니다. ([RED Sample R3D Files 사용 조건](https://support.reddigitalcinema.com/hc/en-us/articles/360021857073-Sample-R3D-Files))
- ARRI는 샘플의 목적을 워크플로 평가로 한정해 설명합니다. 공개 재이용 허락은 확인되지 않았으므로 로컬 워크플로 QA에만 사용하고 재배포하지 않습니다. ([ARRI Sample Footage](https://www.arri.com/en/learn-help/learn-help-camera-system/camera-sample-footage-reference-image))

이 문서는 법률 자문이 아닙니다. 특히 Blackmagic 파일을 지속적 회귀 테스트 자산으로 보관하기 전에는 게시 목적과 내부 QA의 합치 여부를 확인하는 것이 안전합니다.

## P0: 우선 확보할 최소 세트

검증 등급은 `A`=안정된 원본 URL의 서버 메타데이터 확인, `B`=제조사 랜딩·크기 확인이나 로그인/동적 발급 때문에 원본 URL HEAD 불가입니다.

| 우선 | 장면 / 제조사 | 공식 랜딩·원본 획득 경로 | 포맷·공식 사양 | 크기·검증 | QA 커버리지 | 권리 |
|---|---|---|---|---|---|---|
| P0-1 | **Mother and child** / Blackmagic | [URSA Mini Pro 공식 갤러리](https://www.blackmagicdesign.com/products/blackmagicursaminipro/gallery) · [직접 ZIP](https://downloads.blackmagicdesign.com/products/blackmagicursaminipro12k/raw/perfect-day/20221121-11fdfd/Mother-and-Child.braw.zip) | BRAW 12:1, 4096×2160, 240 fps, Gen 5, ISO 400 | **1,064,022,788 B**, HTTP 200 `application/zip`, A | 흐린 날의 부드러운 피부, 눈, 머리카락, 밝은 고지대 자연광/하이라이트 | 원 창작자 Florent Piovesan 저작권; 비교 외 사용·공유 허가 필요. [권리 모달](https://www.blackmagicdesign.com/products/blackmagicursaminipro/modal/copyright-and-privacy) |
| P0-2 | **The Greenhouse** / Blackmagic | [URSA Mini Pro 공식 갤러리](https://www.blackmagicdesign.com/products/blackmagicursaminipro/gallery) · [직접 ZIP](https://downloads.blackmagicdesign.com/products/blackmagicursaminipro12k/raw/the-greenhouse/The-Greenhouse.braw.zip) | BRAW 3:1, 8K에서 4K 오버샘플, 24 fps, Gen 5, ISO 800 | **1,641,345,811 B**, HTTP 200 `application/zip`, A | 측면 창, 바닷물 흔적이 있는 유리, 확산광, 프레임 전역의 식물·구조 미세 디테일 | 원 창작자 Guido Pezz 저작권; 비교 외 사용·공유 허가 필요. [권리 모달](https://www.blackmagicdesign.com/products/blackmagicursaminipro/modal/copyright-and-privacy) |
| P0-3 | **KOMODO-X Car Night LQ** / RED | [공식 획득 페이지](https://www.reddigitalcinema.com/download/sample-r3d-file-komodo-x-6k-s35-car-night) | R3D, KOMODO-X 6K S35, 5760×3240, 24 fps, REDCODE LQ | **401 MB**(공식 표기), 로그인 후 동적 다운로드, B | 야간 헤드라이트, 표지·practical, 밝은 점광원, 프레임 밖 광원과 깊은 그림자 | 내부 테스트만 허용. [RED 조건](https://support.reddigitalcinema.com/hc/en-us/articles/360021857073-Sample-R3D-Files) |
| P0-4 | **KOMODO-X Girl Phone LQ** / RED | [공식 획득 페이지](https://www.reddigitalcinema.com/download/sample-r3d-file-komodo-x-6k-s35-girl-phone) | R3D, KOMODO-X 6K S35, 5760×3240, 24 fps, REDCODE LQ | **609 MB**(공식 표기), 로그인 후 동적 다운로드, B | 피부·눈·머리카락, 가죽과 니트의 미세 질감, 혼합 practical | 내부 테스트만 허용. [RED 조건](https://support.reddigitalcinema.com/hc/en-us/articles/360021857073-Sample-R3D-Files) |
| P0-5 | **GEMINI Lightbulbs** / RED | [공식 획득 페이지](https://www.reddigitalcinema.com/download/sample-r3d-file-gemini-5k-s35-redcode-5-1-lightbulbs) | R3D, GEMINI 5K S35, 5120×2700, 24 fps, REDCODE 5:1, Standard Mode | **980.5 MB**(공식 표기), 로그인 후 동적 다운로드, B | 텅스텐 필라멘트, 고휘도·포화 발광부, 검은 배경과 극저조도 그림자 | 내부 테스트만 허용. [RED 조건](https://support.reddigitalcinema.com/hc/en-us/articles/360021857073-Sample-R3D-Files) |
| P0-6 | **Sawmill C022** / ARRI | [공식 Sample Footage](https://www.arri.com/en/learn-help/learn-help-camera-system/camera-sample-footage-reference-image) · `ftps://ftp2.arri.de/ALEXA%2035/SUP_1.2/ARRIRAW/SM0001C022_231013_144014_a12SO.mxf` | MXF/ARRIRAW, ALEXA 35, 4.6K 16:9, 24 fps, LogC4 | **2,696,933,460 B**, explicit FTP over TLS `SIZE`, A | 제재소의 목재·직물성 미세 질감, 밝은 작업영역/그림자, 프레임 가장자리 | 워크플로 평가 전용으로 취급. [공식 기술 정보 PDF](https://www.arri.com/resource/blob/31926/fea9a24f3fe7b77d5f83b49700465f76/2025-03-arri-sample-footage-technical-information-data.pdf) |

여섯 장면 합계는 RED의 십진 MB 표기를 그대로 더한 추정치로 약 **7.4 GB**입니다. 압축 해제 후 실제 점유량과 RED 로그인 페이지가 발급하는 패키지 구성에 따라 달라질 수 있습니다.

### 최소 세트가 요구 장면을 덮는 방식

| 요구 특성 | 담당 장면 |
|---|---|
| 피부·눈·머리카락 | Mother and child, Girl Phone |
| 창·역광 | The Greenhouse; Car Night의 헤드라이트/프레임 밖 광원 |
| 텅스텐·야간 practical | Car Night, Lightbulbs, Girl Phone |
| 포화 LED·네온/발광부 | Car Night, Lightbulbs |
| 그림자·미세 직물/재질 | Girl Phone의 니트·가죽, Sawmill의 목재, Lightbulbs의 검은 배경 |
| 프레임 가장자리·오프스크린 조명 | The Greenhouse의 구조물, Car Night의 차외 광원, Sawmill |

장면 특성은 제조사 랜딩의 설명·공식 썸네일을 판독한 결과이며, 전체 원본 프레임을 내려받아 픽셀 단위로 검사한 결과는 아닙니다.

## 다운로드 존재 확인 세부

### Blackmagic

Blackmagic의 일반 `curl` 요청은 정상 ZIP 대신 약 19,519 B의 HTML 폴백을 `200`으로 반환할 수 있습니다. 브라우저 User-Agent를 넣은 헤더 요청에서 두 URL 모두 `200`과 `application/zip` 및 위 `Content-Length`를 확인했습니다. 자동 수집기는 **상태 코드뿐 아니라 Content-Type과 최소 크기**를 함께 검사해야 합니다. 랜딩은 각 파일의 코덱, 해상도, 프레임레이트, ISO, 화이트 포인트와 원본 다운로드를 함께 게시합니다. ([Blackmagic 공식 갤러리](https://www.blackmagicdesign.com/products/blackmagicursaminipro/gallery))

### RED

세 획득 페이지는 현재 공식 다운로드 카탈로그에 존재하고 버전·크기·촬영 사양을 표시합니다. 다만 다운로드 버튼은 RED 계정 로그인과 조건 동의를 요구하고, 영구적인 원본 파일 URL을 HTML에 노출하지 않습니다. 따라서 표의 URL은 “직접 파일 URL”이 아니라 **공식 획득 랜딩**이며, 실제 파일 URL의 HEAD 검증은 로그인 세션 없이 수행하지 못했습니다. ([RED 공식 다운로드 카탈로그](https://www.reddigitalcinema.com/downloads/), [RED Sample R3D 카탈로그](https://www.reddigitalcinema.com/sample-r3d-files))

### ARRI

ARRI 공식 랜딩이 공개하는 FTPS 자격정보는 사용자 `ALEXA`, 암호 `samplefootage`이며 explicit FTP over TLS 사용을 권장합니다. C022에는 FTPS `SIZE`가 성공했습니다. 같은 Sawmill 세트의 C023은 2,619,093,076 B, C024도 2,619,093,076 B로 확인되어 교체 프레임이 필요할 때 P1 대체재로 쓸 수 있습니다. ([ARRI 공식 Sample Footage](https://www.arri.com/en/learn-help/learn-help-camera-system/camera-sample-footage-reference-image), [ARRIRAW 설명](https://www.arri.com/en/learn-help/learn-help-camera-system/pre-postproduction/file-formats-data-handling/arriraw))

## DaVinci Resolve Free 21 디코드 판단

중요하게도 현재 공개된 Blackmagic의 상세 코덱 목록은 **Resolve 20 문서**입니다. 이 문서는 macOS/Windows에서 BRAW, ARRIRAW(`.ari/.arx/.mxf`), RED R3D, Sony X-OCN을 디코드 가능으로 열거하며 이 항목들에 Studio-only 표시를 붙이지 않습니다. ([DaVinci Resolve 20 Supported Formats and Codecs PDF](https://documents.blackmagicdesign.com/SupportNotes/DaVinci_Resolve_20_Supported_Codec_List.pdf)) Resolve 21 무료판 자체는 현재 공식 제품으로 제공되지만, 조사 시점에 동일 수준의 공개 “21 Supported Codec List”는 확인하지 못했습니다. ([DaVinci Resolve 21 공식 페이지](https://www.blackmagicdesign.com/products/davinciresolve))

| 포맷 | Free 21 사전 판단 | 근거와 남은 불확실성 |
|---|---|---|
| BRAW | **높은 확률로 가능**, 설치별 스모크 테스트 필요 | Blackmagic은 Resolve가 BRAW를 완전히 지원한다고 설명하고, v20 코덱표도 Studio 제한 없이 디코드를 표시합니다. ([Blackmagic RAW](https://www.blackmagicdesign.com/products/blackmagicraw), [v20 코덱표](https://documents.blackmagicdesign.com/SupportNotes/DaVinci_Resolve_20_Supported_Codec_List.pdf)) 정확한 Free 21 빌드·OS 조합은 별도 확인이 필요합니다. |
| ARRIRAW MXF | **가능 예상**, 반드시 스모크 테스트 | v20 macOS/Windows 목록에 Studio 제한 없이 포함됩니다. ARRI도 공식 ARRIRAW 페이지에서 후반 제작 도구와 샘플 풋티지 경로를 안내합니다. ([v20 코덱표](https://documents.blackmagicdesign.com/SupportNotes/DaVinci_Resolve_20_Supported_Codec_List.pdf), [ARRI ARRIRAW](https://www.arri.com/en/learn-help/learn-help-camera-system/pre-postproduction/file-formats-data-handling/arriraw)) Free 21의 해당 MXF 변형은 실증 전 확정하지 않습니다. |
| RED R3D | **가능 예상**, 반드시 스모크 테스트 | v20 목록의 R3D decode에 Studio-only 표시는 없습니다. ([v20 코덱표](https://documents.blackmagicdesign.com/SupportNotes/DaVinci_Resolve_20_Supported_Codec_List.pdf)) 그러나 로그인 후 받은 현재 샘플과 Free 21의 실제 조합은 확인하지 않았습니다. |
| Sony X-OCN | **불확실—보류** | v20 목록에는 X-OCN LT/ST/XT가 포함되지만, Sony의 공식 호환표는 “DaVinci Resolve Studio 18.6.6”을 제품명으로 적습니다. ([BMD v20 코덱표](https://documents.blackmagicdesign.com/SupportNotes/DaVinci_Resolve_20_Supported_Codec_List.pdf), [Sony X-OCN 호환표](https://pro.sony/s3/2023/09/02123321/X-OCN_XAVCH_Supported_Products_Nov2024.pdf)) Free 21을 직접 시험하기 전에는 P0에 넣지 않습니다. |
| Canon Cinema RAW Light (`.CRM`) | **불확실—보류** | Canon RAW `.crm` 표기가 v20 문서에 있으나 최신 Cinema RAW Light의 모든 변형을 명확히 포괄한다고 단정할 수 없습니다. 또한 공식 카메라 원본 샘플도 확보하지 못했습니다. |

무료판의 UHD 타임라인/출력 한계는 고해상도 원본 “디코드 가능 여부”와 별개입니다. QA는 먼저 미디어 풀 임포트, 첫·중간·끝 프레임 디코드, RAW controls 노출 여부를 확인하고, 3840×2160 타임라인에서 효과를 검증하십시오.

## P1 및 보류 후보

### Sony X-OCN — 접근 가능하지만 Free 21과 권리 문구가 불충분

Sony Professional Cinema 공식 테스트 페이지에는 BURANO **“X-OCN LT Interior Night with Practical Lights”**가 공개되어 있습니다. 조사 중 공식 Sony Ci 메타데이터에서 `BURANO XOCN LT Clip 3.mxf`, 1,220,275,760 B, 6052×3192, 24 fps, 277프레임, Sony X-OCN LT와 소스 다운로드 허용 상태를 확인했지만, 당시의 Ci 공유 URL은 이후 404가 되어 고정 링크로 싣지 않습니다. 현재 획득은 [Sony 공식 Test Footage](https://sony-cinematography.com/testfootage/)에서 다시 시작해야 합니다.

이 장면은 실내 야간 practical과 혼합색 테스트에 적합하지만, 실제 다운로드 URL은 단기 서명 URL이라 문서에 고정할 수 없습니다. 또한 테스트 페이지에서 샘플 자체의 명시적 재이용 라이선스를 찾지 못했고 Free 21 판정도 위와 같이 상충하므로 **권리 확인 + Free 21 스모크 테스트 후 P1**로 올립니다. Sony의 별도 8K X-OCN 샘플 세트는 회원 등록을 요구합니다. ([Sony 공식 X-OCN 8K Downloads](https://pro.sony/en_BG/cinematography/cinematography-tips/x-ocn-8k-downloads))

### Canon Cinema RAW Light — 공식 카메라 원본 샘플 미확인

Canon은 EOS C80의 6K Cinema RAW Light 내부 기록과 EOS R5 C의 Cinema RAW Light HQ/ST/LT 기록을 공식 제품 자료로 확인해 줍니다. ([Canon EOS C80](https://www.usa.canon.com/shop/p/eos-c80), [Canon EOS R5 C](https://www.usa.canon.com/shop/p/eos-r5-c-body)) 그러나 이번 조사 범위에서는 현재 공개되어 있고 직접 획득 가능한 **제조사 공식 카메라 원본 `.CRM` 샘플**을 확인하지 못했습니다. 제3자 파일로 대체하지 않고 보류합니다. Canon의 Cinema RAW Development는 공식 변환 경로로만 기록합니다. ([Canon Cinema RAW Development](https://canon.jp/support/software/os/select/dc/crdw-2-11-10-1-9l-1))

## 획득 후 QA 절차

1. 저장소 밖의 접근 제한 디렉터리에 원본을 저장합니다. Git, LFS, 릴리스, 클라우드 공유 폴더, CI 캐시에 넣지 않습니다.
2. 획득 직전에 랜딩·권리 페이지를 다시 열고 `retrieved_at`, 약관 URL과 화면/HTML 해시를 기록합니다.
3. 다운로드 뒤 SHA-256과 실제 바이트 수를 기록합니다. HTTP `ETag`는 멀티파트 업로드 값일 수 있으므로 파일 해시로 간주하지 않습니다.
4. Resolve **21.x Free**, 실제 OS/하드웨어에서 임포트와 첫·중간·끝 프레임을 확인합니다. RAW controls가 노출되는지, 프록시로 자동 대체되지 않았는지도 기록합니다.
5. CBEF 효과마다 피부, 하이라이트, 채도, 그림자, 미세 질감, 프레임 가장자리의 before/after를 확인하되 결과 스틸은 외부에 배포하지 않습니다.
6. 권리 조건이 바뀌거나 공식 URL이 사라지면 파일을 격리하고 재승인 전까지 테스트에서 제외합니다.

## 권리·출처 추적 필드

각 자산에 다음 레코드를 함께 보관하십시오.

```yaml
asset_id: manufacturer_scene_version
manufacturer: Blackmagic|ARRI|RED|Sony|Canon
scene_name: ""
official_landing_url: ""
acquisition_url: ""        # 안정된 직접 URL 또는 로그인 랜딩
url_kind: direct|ftps|authenticated|signed-ephemeral
retrieved_at: "YYYY-MM-DDThh:mm:ssZ"
verification_method: http_head|official_catalog|ftps_size|public_api
http_status: null
content_type: null
content_length_bytes: null
last_modified: null
publisher_checksum: null
local_sha256: null          # 실제 다운로드 후 계산
format_codec: ""
camera_and_settings: ""
rights_source_url: ""
rights_scope: internal_qa_only
redistribution_allowed: false
local_storage_path: ""      # 저장소 밖 경로
resolve_version: "21.x"
resolve_edition: Free
platform: macOS|Windows
decode_result: untested|pass|fail
raw_controls_result: untested|pass|fail
tested_at: null
operator: ""
notes: ""
```

## 검증 한계

- 원본 대용량 파일을 받지 않았으므로 압축 무결성, 실제 코덱 헤더, 프레임 손상, 전체 장면의 시각 요소는 검증하지 않았습니다.
- Blackmagic 크기는 브라우저 User-Agent를 사용한 HTTP 헤더, ARRI 크기는 FTPS `SIZE`, RED 크기는 로그인 전 공식 카탈로그 표기입니다. 방법이 서로 다릅니다.
- RED의 세 파일은 로그인·조건 동의 뒤 URL이 발급되므로 정적 직접 다운로드 URL과 payload HEAD를 확인하지 못했습니다.
- Resolve 21의 상세 공식 코덱표와 **Free 21 실기 디코드 테스트**가 없으므로 BRAW 외 포맷도 “예상”으로 남겼습니다. 이 문서가 실증 결과를 대신하지 않습니다.
- Sony는 동적 서명 URL과 불명확한 샘플 재사용 조건, Canon은 공식 원본 샘플 부재 때문에 최소 세트에서 제외했습니다.
