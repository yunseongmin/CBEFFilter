SHELL := /bin/sh

SDK_ROOT ?= /Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/OpenFX
SDK_LINK := build/openfx-sdk

PLUGIN_NAME := CBEFFilmEffects
BUNDLE_NAME := $(PLUGIN_NAME).ofx.bundle
BUNDLE_DIR := build/$(BUNDLE_NAME)
BINARY := $(BUNDLE_DIR)/Contents/MacOS/$(PLUGIN_NAME).ofx
NOTICE := $(BUNDLE_DIR)/Contents/Resources/THIRD_PARTY_NOTICES.md
DIST_DIR := build/dist
PKG_FILE := $(DIST_DIR)/CBEFFilter-2.0.0.pkg
DMG_FILE := $(DIST_DIR)/CBEFFilter-2.0.0.dmg
RELEASE_DIR := releases
RESTORE_DMG := $(RELEASE_DIR)/CBEFFilter-2.0.0-Personal-Restore.dmg
RESTORE_CHECKSUM := $(RESTORE_DMG).sha256
TEST_BINARY := build/tests/plugin_abi_probe
HOST_ACTION_TEST_BINARY := build/tests/host_action_lifecycle_contract
FILTER_CONTEXT_HOST_PROBE_BINARY := build/tests/filter_context_host_probe
HEADLESS_TEST_BINARY := build/tests/headless_render_contract
HALATION_TEST_BINARY := build/tests/halation_render_contract
GRAIN_TEST_BINARY := build/tests/film_grain_render_contract
MIST_TEST_BINARY := build/tests/mist_render_contract
OPTICAL_BLUR_TEST_BINARY := build/tests/optical_blur_render_contract
LENS_REFLECTIONS_TEST_BINARY := build/tests/lens_reflections_render_contract
LENS_REFLECTIONS_CPU_TEST_BINARY := build/tests/lens_reflections_render_contract_cpu
V2_LENS_SOURCE_CPU_TEST_BINARY := build/tests/lens_source_map_cpu_contract
V2_LENS_EXTERNAL_MATTE_CPU_TEST_BINARY := build/tests/lens_external_matte_cpu_contract
V2_LENS_ELEMENTS_CPU_TEST_BINARY := build/tests/lens_signed_elements_cpu_contract
V2_LENS_METAL_TEST_BINARY := build/tests/lens_v2_metal_ticket21
FRAME_ARENA_TEST_BINARY := build/tests/frame_arena_contract
TYPED_COMPILE_TEST_BINARY := build/tests/typed_compile_contract
INSPECTOR_METADATA_TEST_BINARY := build/tests/inspector_metadata_contract
V2_HALATION_CPU_TEST_BINARY := build/tests/halation_v2_cpu_contract
V2_HALATION_METAL_TEST_BINARY := build/tests/halation_v2_metal_ticket08
V2_MIST_CPU_TEST_BINARY := build/tests/mist_v2_cpu_contract
V2_MIST_METAL_TEST_BINARY := build/tests/mist_v2_metal_ticket11
V2_GRAIN_STOCK_CPU_TEST_BINARY := build/tests/grain_v2_stock_cpu_contract
V2_GRAIN_METAL_TEST_BINARY := build/tests/grain_v2_metal_ticket14
V2_OPTICAL_FIELD_CPU_TEST_BINARY := build/tests/optical_field_psf_cpu_contract
V2_OPTICAL_ABERRATION_CPU_TEST_BINARY := build/tests/optical_aberration_cpu_contract
M7_BENCHMARK_BINARY := build/tests/m7_performance_benchmark
V2_INTEGRATION_TEST_BINARY := build/tests/v2_integration_contract
M7_OUTPUT_DIR ?= .omo/evidence/m7-performance-$(shell date +%Y%m%d)
METAL_SOURCE := src/metal/kernels/CBEFFilmEffects.metal
METAL_AIR := build/obj/metal/CBEFFilmEffects.air
METALLIB := $(BUNDLE_DIR)/Contents/Resources/CBEFFilmEffects.metallib
TEST_METALLIB := build/tests/CBEFFilmEffects.metallib
METAL_COMPILER ?= xcrun -sdk macosx metal
METALLIB_COMPILER ?= xcrun -sdk macosx metallib

CXX := xcrun clang++
CPPFLAGS := -Iinclude -I$(SDK_LINK)/OpenFX-1.4/include -I$(SDK_LINK)/Support/include
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra -Wpedantic -fvisibility=hidden -arch arm64
SUPPORT_CXXFLAGS := -w
LDFLAGS := -bundle -arch arm64 -Wl,-dead_strip
METAL_LDFLAGS := -framework Foundation -framework Metal

PLUGIN_SOURCES := src/ofx/CBEFFilmEffects.cpp
OFX_SUPPORT_NAMES := ofxsCore ofxsImageEffect ofxsInteract ofxsLog ofxsMultiThread ofxsParams ofxsProperty ofxsPropertyValidation
OFX_SUPPORT_SOURCES := $(addprefix $(SDK_LINK)/Support/Library/,$(addsuffix .cpp,$(OFX_SUPPORT_NAMES)))
PLUGIN_OBJECT := build/obj/CBEFFilmEffects.o
CORE_OBJECT := build/obj/core/RenderCore.o
METAL_OBJECT := build/obj/metal/MetalRenderBackend.o
FRAME_ARENA_OBJECT := build/obj/metal/FrameArena.o
OFX_SUPPORT_OBJECTS := $(addprefix build/obj/openfx/,$(addsuffix .o,$(OFX_SUPPORT_NAMES)))
OBJECTS := $(PLUGIN_OBJECT) $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(OFX_SUPPORT_OBJECTS)

.PHONY: all build package installer dmg personal-restore test-dmg test-personal-restore test test-host-action test-package-install test-m1 test-m1-cpu test-m2 test-m3 test-m3-cpu test-m4 test-m4-cpu test-m5 test-m5-cpu test-m6 test-m6-cpu test-frame-arena test-v2-compile test-v2-inspector test-v2-halation-cpu test-v2-halation-metal test-v2-mist-cpu test-v2-mist-metal test-v2-grain-stock-cpu test-v2-grain-metal test-v2-optical-field-cpu test-v2-optical-aberration-cpu test-v2-optical-metal test-v2-lens-source-cpu test-v2-lens-external-matte-cpu test-v2-lens-elements-cpu test-v2-lens-metal test-v2-integration benchmark-m7 benchmark-mist benchmark-grain benchmark-optical benchmark-lens verify-v2 install uninstall rebuild clean verify-sdk

all: build

build: verify-sdk $(BINARY) $(CORE_OBJECT)

verify-sdk:
	@test -f "$(SDK_ROOT)/OpenFX-1.4/include/ofxCore.h" || { echo "OpenFX SDK headers were not found under: $(SDK_ROOT)" >&2; exit 2; }
	@test -f "$(SDK_ROOT)/Support/Library/ofxsImageEffect.cpp" || { echo "OpenFX SDK support sources were not found under: $(SDK_ROOT)" >&2; exit 2; }

$(SDK_LINK): verify-sdk
	@mkdir -p "$(dir $@)"
	@test -L "$@" || ln -s "$(SDK_ROOT)" "$@"

$(BINARY): $(OBJECTS) $(METALLIB) vendor/openfx/LICENSE vendor/openfx/THIRD_PARTY_NOTICES.md
	@mkdir -p "$(dir $@)" "$(dir $(NOTICE))"
	$(CXX) $(OBJECTS) -o "$@" $(LDFLAGS) $(METAL_LDFLAGS)
	cp vendor/openfx/THIRD_PARTY_NOTICES.md "$(NOTICE)"
	/usr/libexec/PlistBuddy -c 'Clear dict' "$(BUNDLE_DIR)/Contents/Info.plist" 2>/dev/null || true
	@printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0"><dict>' \
		'<key>CFBundleDevelopmentRegion</key><string>en</string>' \
		'<key>CFBundleExecutable</key><string>$(PLUGIN_NAME).ofx</string>' \
		'<key>CFBundleIdentifier</key><string>com.cbef.filmeffects</string>' \
		'<key>CFBundleName</key><string>CBEF Film Effects</string>' \
		'<key>CFBundlePackageType</key><string>BNDL</string>' \
		'<key>CFBundleShortVersionString</key><string>2.0</string>' \
		'<key>CFBundleVersion</key><string>2.0.0</string>' \
		'</dict></plist>' > "$(BUNDLE_DIR)/Contents/Info.plist"
	/usr/bin/codesign --force --sign - "$(BUNDLE_DIR)"

$(METALLIB): $(METAL_SOURCE)
	@mkdir -p "$(dir $(METAL_AIR))" "$(dir $@)"
	$(METAL_COMPILER) -c "$<" -o "$(METAL_AIR)"
	$(METALLIB_COMPILER) "$(METAL_AIR)" -o "$@"

$(TEST_METALLIB): $(METALLIB)
	@mkdir -p "$(dir $@)"
	cp "$(METALLIB)" "$@"

$(PLUGIN_OBJECT): $(PLUGIN_SOURCES) | $(SDK_LINK)
	@mkdir -p "$(dir $@)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c "$<" -o "$@"

build/obj/openfx/%.o: $(SDK_LINK)/Support/Library/%.cpp | $(SDK_LINK)
	@mkdir -p "$(dir $@)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(SUPPORT_CXXFLAGS) -c "$<" -o "$@"

$(TEST_BINARY): tests/plugin_abi_probe.cpp $(BINARY) $(METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) "$<" -o "$@"

test: $(TEST_BINARY)
	"$(TEST_BINARY)" "$(BINARY)"

$(HOST_ACTION_TEST_BINARY): tests/host_action_lifecycle_contract.cpp
	@mkdir -p "$(dir $@)"
	$(CXX) $(CXXFLAGS) "$<" -o "$@"

$(FILTER_CONTEXT_HOST_PROBE_BINARY): tests/filter_context_host_probe.cpp $(PLUGIN_SOURCES) $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(OFX_SUPPORT_SOURCES)
	@mkdir -p "$(dir $@)"
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(SUPPORT_CXXFLAGS) -DkOfxsDisableValidation \
		tests/filter_context_host_probe.cpp $(PLUGIN_SOURCES) $(OFX_SUPPORT_SOURCES) \
		"$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" -o "$@" $(METAL_LDFLAGS)

test-host-action: $(HOST_ACTION_TEST_BINARY) $(FILTER_CONTEXT_HOST_PROBE_BINARY)
	"$(HOST_ACTION_TEST_BINARY)" src/ofx/CBEFFilmEffects.cpp
	"$(FILTER_CONTEXT_HOST_PROBE_BINARY)"

test-package-install: build
	./tests/package_install_contract.sh "$(BUNDLE_DIR)" ./scripts/install.sh

package: build
	./scripts/package-dmg.sh "$(BUNDLE_DIR)" "$(DIST_DIR)"

installer: package

dmg: package

test-dmg: package
	./tests/dmg_package_contract.sh "$(BUNDLE_DIR)" "$(PKG_FILE)" "$(DMG_FILE)" ./packaging/pkg/scripts/preinstall

personal-restore: package
	@mkdir -p "$(RELEASE_DIR)"
	cp "$(DMG_FILE)" "$(RESTORE_DMG)"
	cd "$(RELEASE_DIR)" && shasum -a 256 "$(notdir $(RESTORE_DMG))" > "$(notdir $(RESTORE_CHECKSUM))"

test-personal-restore: personal-restore
	cd "$(RELEASE_DIR)" && shasum -a 256 -c "$(notdir $(RESTORE_CHECKSUM))"
	./tests/dmg_package_contract.sh "$(BUNDLE_DIR)" "$(PKG_FILE)" "$(RESTORE_DMG)" ./packaging/pkg/scripts/preinstall

$(CORE_OBJECT): src/core/RenderCore.cpp include/cbef/RenderCore.h src/core/RenderPlan.h src/core/OpticalSampling.h
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core -c "$<" -o "$@"

$(METAL_OBJECT): src/metal/MetalRenderBackend.mm src/metal/FrameArena.h include/cbef/RenderCore.h src/core/RenderPlan.h src/core/OpticalSampling.h
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core -c "$<" -o "$@"

$(FRAME_ARENA_OBJECT): src/metal/FrameArena.mm src/metal/FrameArena.h
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core -c "$<" -o "$@"

$(HEADLESS_TEST_BINARY): tests/headless_render_contract.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(HALATION_TEST_BINARY): tests/halation_render_contract.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(GRAIN_TEST_BINARY): tests/film_grain_render_contract.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
        -o "$@" $(METAL_LDFLAGS)

$(MIST_TEST_BINARY): tests/mist_render_contract.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(OPTICAL_BLUR_TEST_BINARY): tests/optical_blur_render_contract.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(LENS_REFLECTIONS_TEST_BINARY): tests/lens_reflections_render_contract.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(LENS_REFLECTIONS_CPU_TEST_BINARY): tests/lens_reflections_render_contract.mm $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@" $(METAL_LDFLAGS)

$(V2_LENS_SOURCE_CPU_TEST_BINARY): tests/lens_source_map_cpu_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(V2_LENS_EXTERNAL_MATTE_CPU_TEST_BINARY): tests/lens_external_matte_cpu_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(V2_LENS_ELEMENTS_CPU_TEST_BINARY): tests/lens_signed_elements_cpu_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(TYPED_COMPILE_TEST_BINARY): tests/typed_compile_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(INSPECTOR_METADATA_TEST_BINARY): tests/inspector_metadata_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(V2_HALATION_CPU_TEST_BINARY): tests/halation_v2_cpu_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(V2_HALATION_METAL_TEST_BINARY): tests/halation_v2_metal_ticket08.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(V2_MIST_CPU_TEST_BINARY): tests/mist_v2_cpu_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(V2_MIST_METAL_TEST_BINARY): tests/mist_v2_metal_ticket11.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(V2_GRAIN_STOCK_CPU_TEST_BINARY): tests/grain_v2_stock_cpu_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(V2_GRAIN_METAL_TEST_BINARY): tests/grain_v2_metal_ticket14.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(V2_LENS_METAL_TEST_BINARY): tests/lens_v2_metal_ticket21.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(V2_OPTICAL_FIELD_CPU_TEST_BINARY): tests/optical_field_psf_cpu_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(V2_OPTICAL_ABERRATION_CPU_TEST_BINARY): tests/optical_aberration_cpu_contract.cpp $(CORE_OBJECT)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -Isrc/core "$<" "$(CORE_OBJECT)" -o "$@"

$(FRAME_ARENA_TEST_BINARY): tests/frame_arena_contract.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(M7_BENCHMARK_BINARY): tests/m7_performance_benchmark.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

$(V2_INTEGRATION_TEST_BINARY): tests/v2_integration_contract.mm $(CORE_OBJECT) $(METAL_OBJECT) $(FRAME_ARENA_OBJECT) $(TEST_METALLIB)
	@mkdir -p "$(dir $@)"
	$(CXX) -Iinclude $(CXXFLAGS) -DCBEF_ENABLE_METAL_TEST -Isrc/core "$<" "$(CORE_OBJECT)" "$(METAL_OBJECT)" "$(FRAME_ARENA_OBJECT)" \
		-o "$@" $(METAL_LDFLAGS)

test-m1: $(HEADLESS_TEST_BINARY)
	"$(HEADLESS_TEST_BINARY)"

test-m1-cpu: test-m1

test-m2: $(HALATION_TEST_BINARY)
	"$(HALATION_TEST_BINARY)"

test-m3: $(GRAIN_TEST_BINARY)
	"$(GRAIN_TEST_BINARY)"

test-m3-cpu: test-m3

test-m4: $(MIST_TEST_BINARY)
	"$(MIST_TEST_BINARY)"

test-m4-cpu: $(MIST_TEST_BINARY)
	"$(MIST_TEST_BINARY)"

test-m5-cpu: $(OPTICAL_BLUR_TEST_BINARY)
	"$(OPTICAL_BLUR_TEST_BINARY)"

test-m5: $(OPTICAL_BLUR_TEST_BINARY)
	"$(OPTICAL_BLUR_TEST_BINARY)"

test-m6-cpu: $(LENS_REFLECTIONS_CPU_TEST_BINARY)
	"$(LENS_REFLECTIONS_CPU_TEST_BINARY)"

test-m6: $(LENS_REFLECTIONS_TEST_BINARY)
	"$(LENS_REFLECTIONS_TEST_BINARY)"

test-frame-arena: $(FRAME_ARENA_TEST_BINARY)
	"$(FRAME_ARENA_TEST_BINARY)"

test-v2-compile: $(TYPED_COMPILE_TEST_BINARY)
	"$(TYPED_COMPILE_TEST_BINARY)"

test-v2-inspector: $(INSPECTOR_METADATA_TEST_BINARY) $(BINARY)
	"$(INSPECTOR_METADATA_TEST_BINARY)"

test-v2-halation-cpu: $(V2_HALATION_CPU_TEST_BINARY)
	"$(V2_HALATION_CPU_TEST_BINARY)"

test-v2-halation-metal: $(V2_HALATION_METAL_TEST_BINARY)
	"$(V2_HALATION_METAL_TEST_BINARY)"

test-v2-mist-cpu: $(V2_MIST_CPU_TEST_BINARY)
	"$(V2_MIST_CPU_TEST_BINARY)"

test-v2-mist-metal: $(V2_MIST_METAL_TEST_BINARY)
	"$(V2_MIST_METAL_TEST_BINARY)"

test-v2-grain-stock-cpu: $(V2_GRAIN_STOCK_CPU_TEST_BINARY)
	"$(V2_GRAIN_STOCK_CPU_TEST_BINARY)"

test-v2-grain-metal: $(V2_GRAIN_METAL_TEST_BINARY)
	"$(V2_GRAIN_METAL_TEST_BINARY)"

test-v2-optical-field-cpu: $(V2_OPTICAL_FIELD_CPU_TEST_BINARY)
	"$(V2_OPTICAL_FIELD_CPU_TEST_BINARY)"

test-v2-optical-aberration-cpu: $(V2_OPTICAL_ABERRATION_CPU_TEST_BINARY)
	"$(V2_OPTICAL_ABERRATION_CPU_TEST_BINARY)"

test-v2-optical-metal: $(OPTICAL_BLUR_TEST_BINARY) $(V2_OPTICAL_ABERRATION_CPU_TEST_BINARY)
	"$(OPTICAL_BLUR_TEST_BINARY)"
	"$(V2_OPTICAL_ABERRATION_CPU_TEST_BINARY)"

test-v2-lens-source-cpu: $(V2_LENS_SOURCE_CPU_TEST_BINARY)
	"$(V2_LENS_SOURCE_CPU_TEST_BINARY)"

test-v2-lens-external-matte-cpu: $(V2_LENS_EXTERNAL_MATTE_CPU_TEST_BINARY)
	"$(V2_LENS_EXTERNAL_MATTE_CPU_TEST_BINARY)"

test-v2-lens-elements-cpu: $(V2_LENS_ELEMENTS_CPU_TEST_BINARY)
	"$(V2_LENS_ELEMENTS_CPU_TEST_BINARY)"

test-v2-lens-metal: $(V2_LENS_METAL_TEST_BINARY)
	"$(V2_LENS_METAL_TEST_BINARY)"

test-v2-integration: $(V2_INTEGRATION_TEST_BINARY)
	"$(V2_INTEGRATION_TEST_BINARY)"

# Runs the complete M7 GPU benchmark and writes m7-performance.json/.md under M7_OUTPUT_DIR.
# The bundle dependency supplies the exact binary hash captured by the benchmark.
benchmark-m7: $(M7_BENCHMARK_BINARY) $(BINARY)
	@mkdir -p "$(M7_OUTPUT_DIR)"
	CBEF_M7_OUTPUT_DIR="$(M7_OUTPUT_DIR)" CBEF_M7_BUNDLE="$(BINARY)" "$(M7_BENCHMARK_BINARY)"

benchmark-mist: $(M7_BENCHMARK_BINARY) $(BINARY)
	@mkdir -p "$(M7_OUTPUT_DIR)"
	CBEF_M7_EFFECT_FILTER=mist CBEF_M7_OUTPUT_DIR="$(M7_OUTPUT_DIR)" CBEF_M7_BUNDLE="$(BINARY)" "$(M7_BENCHMARK_BINARY)"

benchmark-grain: $(M7_BENCHMARK_BINARY) $(BINARY)
	@mkdir -p "$(M7_OUTPUT_DIR)"
	CBEF_M7_EFFECT_FILTER=grain CBEF_M7_OUTPUT_DIR="$(M7_OUTPUT_DIR)" CBEF_M7_BUNDLE="$(BINARY)" "$(M7_BENCHMARK_BINARY)"

benchmark-optical: $(M7_BENCHMARK_BINARY) $(BINARY)
	@mkdir -p "$(M7_OUTPUT_DIR)"
	CBEF_M7_EFFECT_FILTER=optical CBEF_M7_OUTPUT_DIR="$(M7_OUTPUT_DIR)" CBEF_M7_BUNDLE="$(BINARY)" "$(M7_BENCHMARK_BINARY)"

benchmark-lens: $(M7_BENCHMARK_BINARY) $(BINARY)
	@mkdir -p "$(M7_OUTPUT_DIR)"
	CBEF_M7_EFFECT_FILTER=lens CBEF_M7_OUTPUT_DIR="$(M7_OUTPUT_DIR)" CBEF_M7_BUNDLE="$(BINARY)" "$(M7_BENCHMARK_BINARY)"

verify-v2:
	./scripts/verify-v2.sh

install: build
	./scripts/install.sh "$(BUNDLE_DIR)"

uninstall:
	./scripts/uninstall.sh

rebuild: clean build

clean:
	rm -rf build
