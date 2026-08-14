# Ticket 08 direct verification run 6
## Source gate
        }
    }

    const auto markBasic = [&parameters](const char* id, int order,
                                         ParameterRole role = ParameterRole::EffectControl) {
        for (ParameterDefinition& parameter : parameters) {
            if (std::strcmp(parameter.id, id) == 0) {
                parameter.group = ParameterGroup::Basic;
                parameter.role = role;
                parameter.display_order = order;
                return;
            }
        }
    };
    const auto markAdvanced = [&parameters](const char* id, int order, ParameterRole role = ParameterRole::EffectControl,
                                            const char* enabled_when = nullptr, int enabled_choice = 0) {
## Build
BUILD_EXIT_CODE:0
## Focused CPU and Metal
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -Isrc/core "tests/halation_v2_cpu_contract.cpp" "build/obj/core/RenderCore.o" -o "build/tests/halation_v2_cpu_contract"
"build/tests/halation_v2_cpu_contract"
halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)
cp "build/CBEFFilmEffects.ofx.bundle/Contents/Resources/CBEFFilmEffects.metallib" "build/tests/CBEFFilmEffects.metallib"
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -DCBEF_ENABLE_METAL_TEST -Isrc/core "tests/halation_v2_metal_ticket08.mm" "build/obj/core/RenderCore.o" "build/obj/metal/MetalRenderBackend.o" "build/obj/metal/FrameArena.o" \
		-o "build/tests/halation_v2_metal_ticket08" -framework Foundation -framework Metal
"build/tests/halation_v2_metal_ticket08"
wide parity channel 0 energy cpu=106.79 metal=100 centroid cpu=(351.872,198.102) metal=(341,192)
wide parity channel 1 energy cpu=55.6792 metal=50 centroid cpu=(358.44,201.788) metal=(341,192)
wide parity channel 2 energy cpu=29.9151 metal=25 centroid cpu=(369.094,207.767) metal=(341,192)
halation_v2_metal_ticket08: PASS
FOCUSED_EXIT_CODE:0
## FrameArena, M1, M2, typed, inspector
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -DCBEF_ENABLE_METAL_TEST -Isrc/core "tests/headless_render_contract.mm" "build/obj/core/RenderCore.o" "build/obj/metal/MetalRenderBackend.o" "build/obj/metal/FrameArena.o" \
		-o "build/tests/headless_render_contract" -framework Foundation -framework Metal
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -DCBEF_ENABLE_METAL_TEST -Isrc/core "tests/halation_render_contract.mm" "build/obj/core/RenderCore.o" "build/obj/metal/MetalRenderBackend.o" "build/obj/metal/FrameArena.o" \
		-o "build/tests/halation_render_contract" -framework Foundation -framework Metal
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -DCBEF_ENABLE_METAL_TEST -Isrc/core "tests/frame_arena_contract.mm" "build/obj/core/RenderCore.o" "build/obj/metal/MetalRenderBackend.o" "build/obj/metal/FrameArena.o" \
		-o "build/tests/frame_arena_contract" -framework Foundation -framework Metal
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -Isrc/core "tests/inspector_metadata_contract.cpp" "build/obj/core/RenderCore.o" -o "build/tests/inspector_metadata_contract"
xcrun clang++ -Iinclude -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64 -Isrc/core "tests/typed_compile_contract.cpp" "build/obj/core/RenderCore.o" -o "build/tests/typed_compile_contract"
"build/tests/frame_arena_contract"
"build/tests/headless_render_contract"
"build/tests/halation_render_contract"
frame_arena_contract: PASS
REPORT: .omo/evidence/ticket-05-frame-arena.json
TRACE: .omo/evidence/ticket-05-frame-arena.jsonl
"build/tests/typed_compile_contract"
headless_render_contract: PASS (CPU + Metal M1 contract)
"build/tests/inspector_metadata_contract"
halation_render_contract: PASS (CPU + Metal M2 Halation)
REGRESSION_EXIT_CODE:0
