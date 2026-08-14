# 19 — 렌즈 반사 외부 Matte 입력

**What to build:** 자동 검출과 수동 광원만으로 분리하기 어려운 장면에서 Resolve의 외부 matte로 반응 영역을 제한하고, matte가 없을 때도 기존 source 흐름이 그대로 작동하게 합니다.

**Blocked by:** 18 — 렌즈 반사 광원 지도와 수동 광원.

**Status:** resolved for core/OFX; Resolve host smoke deferred to ticket 24

- [x] Lens Reflections가 선택적인 외부 matte 입력을 선언하고 Resolve에서 연결하거나 비워 둘 수 있습니다.
- [x] matte가 없으면 자동·수동 광원 결과가 바뀌지 않고, matte가 있으면 source map과 element energy가 해당 영역으로 제한됩니다.
- [x] matte alpha, grayscale, crop, data-window origin, row stride, 해상도와 Render Scale 차이가 정의된 방식으로 처리됩니다.
- [x] 0·부분·1 matte와 premultiplied source에서 투명 영역이나 crop 밖 destination을 오염시키지 않습니다.
- [x] Source Map 진단 출력에서 matte 제한 전후를 구분해 오검출 교정 여부를 확인할 수 있습니다.
- [ ] 실제 Resolve 무료판에서 외부 matte 연결·해제 후 preview와 render가 성공하는 host smoke 증거를 남깁니다.

**Answer:**

CPU Lens Reflections now accepts an optional float Alpha/RGBA external matte with validated host-surface metadata, canonical bilinear sampling, alpha-aware positive luminance coverage, and deterministic zero/outside behavior. Source Map is the pre-matte diagnostic and Matte Limited is the post-matte diagnostic. Resolve's Lens OFX alone declares and fetches the optional Matte clip when connected.

**Evidence:** `.omo/evidence/ticket19/ticket19-external-matte-cpu-20260812.md`
