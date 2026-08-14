#!/bin/sh
set -euo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"

export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
evidence_dir=${CBEF_V2_EVIDENCE_DIR:-.omo/evidence/v2-final-20260812}
temporary_dir=$(mktemp -d ".omo/evidence/.v2-final-20260812.XXXXXX")
stage=initialization

finish_failure()
{
    status=$?
    printf '{"schema_version":1,"status":"failed","stage":"%s","exit_code":%s}\n' "$stage" "$status" \
        > "$temporary_dir/verdict.json"
    printf '# CBEF Film Effects v2 verification\n\nStatus: **FAILED**\n\nStage: `%s`\n' "$stage" \
        > "$temporary_dir/verdict.md"
    rm -rf "$evidence_dir"
    mv "$temporary_dir" "$evidence_dir"
    echo "verify-v2: FAIL at $stage; evidence: $evidence_dir" >&2
    exit "$status"
}
trap finish_failure EXIT HUP INT TERM

run()
{
    name=$1
    shift
    stage=$name
    "$@" 2>&1 | tee "$temporary_dir/$name.log"
}

stage=clean-build
make clean > "$temporary_dir/00-clean.log" 2>&1
make build/openfx-sdk >> "$temporary_dir/00-clean.log" 2>&1
run 01-clean-build make -j4 build \
    build/tests/plugin_abi_probe build/tests/headless_render_contract \
    build/tests/host_action_lifecycle_contract build/tests/filter_context_host_probe \
    build/tests/film_grain_render_contract build/tests/optical_blur_render_contract \
    build/tests/frame_arena_contract \
    build/tests/typed_compile_contract build/tests/inspector_metadata_contract \
    build/tests/halation_v2_cpu_contract build/tests/halation_v2_metal_ticket08 \
    build/tests/mist_v2_cpu_contract build/tests/mist_v2_metal_ticket11 \
    build/tests/grain_v2_stock_cpu_contract build/tests/grain_v2_metal_ticket14 \
    build/tests/optical_field_psf_cpu_contract build/tests/optical_aberration_cpu_contract \
    build/tests/lens_source_map_cpu_contract build/tests/lens_external_matte_cpu_contract \
    build/tests/lens_signed_elements_cpu_contract build/tests/lens_v2_metal_ticket21 \
    build/tests/v2_integration_contract build/tests/m7_performance_benchmark

run 02-fixtures python3 -m unittest tests/quality_fixture_test.py -v

stage=03-bundle-audit
binary=build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx
metallib=build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' build/CBEFFilmEffects.ofx.bundle/Contents/Info.plist)" = 2.0
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' build/CBEFFilmEffects.ofx.bundle/Contents/Info.plist)" = 2.0.0
file "$binary" "$metallib" > "$temporary_dir/03-bundle-audit.log"
find build/CBEFFilmEffects.ofx.bundle -type f -print | sort >> "$temporary_dir/03-bundle-audit.log"
test -s "$binary"
test -s "$metallib"
test -f build/CBEFFilmEffects.ofx.bundle/Contents/Resources/THIRD_PARTY_NOTICES.md
/usr/bin/codesign --verify --deep --strict build/CBEFFilmEffects.ofx.bundle \
    >> "$temporary_dir/03-bundle-audit.log" 2>&1

run 04-abi build/tests/plugin_abi_probe "$binary"
run 04-host-action build/tests/host_action_lifecycle_contract src/ofx/CBEFFilmEffects.cpp
run 04-filter-context build/tests/filter_context_host_probe
run 04-package-install-sandbox ./tests/package_install_contract.sh \
    build/CBEFFilmEffects.ofx.bundle ./scripts/install.sh

stage=05-metallib-functions
xcrun metal-objdump --syms "$metallib" > "$temporary_dir/05-metallib-functions.log"
rg -o '"cbef_[a-z0-9_]+"' src/metal/MetalRenderBackend.mm | tr -d '"' | sort -u > "$temporary_dir/expected-metal-functions.txt"
while IFS= read -r function_name; do
    rg -q "[[:space:]]${function_name}$" "$temporary_dir/05-metallib-functions.log"
done < "$temporary_dir/expected-metal-functions.txt"

stage=06-forbidden-symbols
if rg -n 'effectGain|scaffold_gain|renderPlanFromCompiled|encode_legacy|cbef_scaffold|kernel void cbef_grain\(' \
    src include tests > "$temporary_dir/06-forbidden-symbols.log"; then
    echo "forbidden v1 symbol found" >&2
    false
fi
if rg -n 'newLibraryWithSource|runtime Metal source|No Remjet|No Backing' src include \
    >> "$temporary_dir/06-forbidden-symbols.log"; then
    echo "forbidden runtime source or unsupported product claim found" >&2
    false
fi
printf 'PASS: no forbidden v1/runtime-source symbols\n' >> "$temporary_dir/06-forbidden-symbols.log"

run 07-typed-compile build/tests/typed_compile_contract
run 08-inspector build/tests/inspector_metadata_contract
run 09-common-contract build/tests/headless_render_contract
run 11-halation-cpu build/tests/halation_v2_cpu_contract
run 12-halation-metal build/tests/halation_v2_metal_ticket08
run 13-grain-48-frame build/tests/film_grain_render_contract
run 14-grain-cpu build/tests/grain_v2_stock_cpu_contract
run 15-grain-metal build/tests/grain_v2_metal_ticket14
run 17-mist-cpu build/tests/mist_v2_cpu_contract
run 18-mist-metal build/tests/mist_v2_metal_ticket11
run 19-optical-cpu-model build/tests/optical_field_psf_cpu_contract
run 20-optical-aberration build/tests/optical_aberration_cpu_contract
run 21-optical-metal build/tests/optical_blur_render_contract
run 23-lens-source build/tests/lens_source_map_cpu_contract
run 24-lens-matte build/tests/lens_external_matte_cpu_contract
run 25-lens-elements build/tests/lens_signed_elements_cpu_contract
run 26-lens-metal build/tests/lens_v2_metal_ticket21
run 27-frame-arena build/tests/frame_arena_contract
run 28-resolution-identity build/tests/v2_integration_contract

stage=29-provenance-rights
python3 -c 'import json; d=json.load(open("fixtures/quality/manifest.json")); assert d["external_assets"]["records"] == []' \
    > "$temporary_dir/29-provenance-rights.log" 2>&1
find fixtures/quality -type f ! -path '*/local-assets/*' -print0 | sort -z | xargs -0 shasum -a 256 \
    > "$temporary_dir/fixture-checksums.sha256"
printf 'PASS: synthetic fixture manifest has no bundled external records\n' >> "$temporary_dir/29-provenance-rights.log"

stage=30-performance
CBEF_M7_OUTPUT_DIR="$temporary_dir/performance" CBEF_M7_BUNDLE="$binary" \
    build/tests/m7_performance_benchmark 2>&1 | tee "$temporary_dir/30-performance.log"
rg -q '"all_pass": true' "$temporary_dir/performance/m7-performance.json"

stage=31-checksums
(cd "$temporary_dir" && find . -type f ! -name checksums.sha256 -print0 | sort -z | xargs -0 shasum -a 256) \
    > "$temporary_dir/checksums.sha256"
printf '{"schema_version":1,"status":"passed","plugin_version":"2.0.0","effect_count":5,"warmup_frames":3,"measurement_frames":10,"grain_statistical_frames":48,"scratch_limits_mib":{"halation":160,"grain":64,"mist":220,"optical":192,"lens":256}}\n' \
    > "$temporary_dir/verdict.json"
printf '# CBEF Film Effects v2 verification\n\nStatus: **PASSED**\n\nThe clean arm64 package, v2 ABI, fixtures, static audits, CPU/Metal effect contracts, 48-frame Grain statistics, 8K/12K correctness, allocation gates and 3+10 frame performance gates passed.\n' \
    > "$temporary_dir/verdict.md"
(cd "$temporary_dir" && shasum -a 256 ./verdict.json ./verdict.md) >> "$temporary_dir/checksums.sha256"

trap - EXIT HUP INT TERM
rm -rf "$evidence_dir"
mv "$temporary_dir" "$evidence_dir"
echo "verify-v2: PASS; evidence: $evidence_dir"
