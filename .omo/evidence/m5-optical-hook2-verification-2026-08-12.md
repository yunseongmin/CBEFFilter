verification=second-stop-hook
test_command=make test-m5-cpu
test_exit=0
test_log_bytes=     383
test_pass_observable=
4:optical_blur_render_contract: PASS
build_command=make -B build
build_exit=0
build_log_bytes=    3482
build_diagnostics=
prior_evidence_bytes=
    4052 .omo/evidence/m5-optical-hook-verification-2026-08-12.md
    1066 .omo/evidence/m5-optical-cpu-2026-08-12.md
    5118 total
test_log_tail=
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -Isrc/core "tests/optical_blur_render_contract.mm" "build/obj/core/RenderCore.o" "build/obj/metal/MetalRenderBackend.o" \
		-o "build/tests/optical_blur_render_contract" -framework Foundation -framework Metal
"build/tests/optical_blur_render_contract"
optical_blur_render_contract: PASS
build_log_tail=
xcrun clang++ -Iinclude -Ibuild/openfx-sdk/OpenFX-1.4/include -Ibuild/openfx-sdk/Support/include -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -w -c "build/openfx-sdk/Support/Library/ofxsMultiThread.cpp" -o "build/obj/openfx/ofxsMultiThread.o"
xcrun clang++ -Iinclude -Ibuild/openfx-sdk/OpenFX-1.4/include -Ibuild/openfx-sdk/Support/include -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -w -c "build/openfx-sdk/Support/Library/ofxsParams.cpp" -o "build/obj/openfx/ofxsParams.o"
xcrun clang++ -Iinclude -Ibuild/openfx-sdk/OpenFX-1.4/include -Ibuild/openfx-sdk/Support/include -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -w -c "build/openfx-sdk/Support/Library/ofxsProperty.cpp" -o "build/obj/openfx/ofxsProperty.o"
xcrun clang++ -Iinclude -Ibuild/openfx-sdk/OpenFX-1.4/include -Ibuild/openfx-sdk/Support/include -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -w -c "build/openfx-sdk/Support/Library/ofxsPropertyValidation.cpp" -o "build/obj/openfx/ofxsPropertyValidation.o"
xcrun clang++ build/obj/CBEFFilmEffects.o build/obj/core/RenderCore.o build/obj/metal/MetalRenderBackend.o build/obj/openfx/ofxsCore.o build/obj/openfx/ofxsImageEffect.o build/obj/openfx/ofxsInteract.o build/obj/openfx/ofxsLog.o build/obj/openfx/ofxsMultiThread.o build/obj/openfx/ofxsParams.o build/obj/openfx/ofxsProperty.o build/obj/openfx/ofxsPropertyValidation.o -o "build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx" -bundle -arch arm64 -Wl,-dead_strip -framework Foundation -framework Metal
cp vendor/openfx/THIRD_PARTY_NOTICES.md "build/CBEFFilmEffects.ofx.bundle/Contents/Resources/THIRD_PARTY_NOTICES.md"
/usr/libexec/PlistBuddy -c 'Clear dict' "build/CBEFFilmEffects.ofx.bundle/Contents/Info.plist" 2>/dev/null || true
Initializing Plist...
