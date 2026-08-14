#import <Metal/Metal.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string_view>
#include <utility>
#include <vector>

#include "cbef/RenderCore.h"

namespace {
using namespace cbef;
constexpr std::size_t kRgbaBytes = sizeof(float) * 4U;
constexpr std::uint8_t kSentinel = 0xA5U;
using Setting = std::pair<std::string_view, SettingValue>;

#define CHECK(condition, message) \
    do { \
        if (!(condition)) { std::fprintf(stderr, "lens_v2_metal_ticket21: %s\n", message); return 1; } \
    } while (false)

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    Frame(int width, int height, int x = 0, int y = 0)
        : bounds{x, y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kRgbaBytes + 32U)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), kSentinel)
    {
        for (int py = y; py < y + height; ++py) {
            for (int px = x; px < x + width; ++px) {
                float* value = reinterpret_cast<float*>(source.data() +
                    static_cast<std::size_t>(py - y) * row_bytes + static_cast<std::size_t>(px - x) * kRgbaBytes);
                const int ix = px - x;
                const int iy = py - y;
                value[0] = 0.025F + 0.002F * static_cast<float>((ix * 7 + iy * 3) % 17);
                value[1] = 0.035F + 0.002F * static_cast<float>((ix * 5 + iy * 11) % 19);
                value[2] = 0.020F + 0.002F * static_cast<float>((ix * 13 + iy) % 13);
                value[3] = ((ix + iy * 3) % 23 == 0) ? 0.625F : 1.0F;
            }
        }
        const int hx = x + width * 3 / 4;
        const int hy = y + height / 2;
        float* highlight = reinterpret_cast<float*>(source.data() +
            static_cast<std::size_t>(hy - y) * row_bytes + static_cast<std::size_t>(hx - x) * kRgbaBytes);
        highlight[0] = 0.8F;
        highlight[1] = 0.6F;
        highlight[2] = 0.35F;
        highlight[3] = 1.0F;
    }
};

struct Matte {
    DataWindow bounds;
    PixelFormat format;
    std::size_t row_bytes;
    std::vector<std::uint8_t> bytes;
    AlphaAssociation association;

    Matte(int width, int height, PixelFormat pixel_format)
        : bounds{11, -9, width, height}
        , format(pixel_format)
        , row_bytes(static_cast<std::size_t>(width) *
                        (pixel_format == PixelFormat::AlphaFloat32 ? sizeof(float) : kRgbaBytes) + 16U)
        , bytes(row_bytes * static_cast<std::size_t>(height), 0U)
        , association(pixel_format == PixelFormat::RgbaFloat32 ? AlphaAssociation::Premultiplied :
                                                                 AlphaAssociation::Straight)
    {
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                const float amount = 0.15F + 0.75F * static_cast<float>((x + 2 * y) % 11) / 10.0F;
                float* value = reinterpret_cast<float*>(bytes.data() + static_cast<std::size_t>(y) * row_bytes +
                    static_cast<std::size_t>(x) * (format == PixelFormat::AlphaFloat32 ? sizeof(float) : kRgbaBytes));
                if (format == PixelFormat::AlphaFloat32) {
                    value[0] = amount;
                } else {
                    value[0] = amount * 0.70F;
                    value[1] = amount * 0.85F;
                    value[2] = amount;
                    value[3] = amount;
                }
            }
        }
    }
};

struct Metrics {
    double max_error = 0.0;
    double mean_error = 0.0;
    double cpu_energy = 0.0;
    double metal_energy = 0.0;
    double cpu_centroid_x = 0.0;
    double cpu_centroid_y = 0.0;
    double metal_centroid_x = 0.0;
    double metal_centroid_y = 0.0;
    std::uint64_t hash = 1469598103934665603ULL;
    bool alpha_exact = true;
    bool crop_exact = true;
    bool finite = true;
    bool submitted = false;
};

double positiveLuma(const float* value)
{
    return std::max(0.0, 0.27411851 * std::max(0.0F, value[0]) +
                             0.87363190 * std::max(0.0F, value[1]) -
                             0.14775041 * std::max(0.0F, value[2]));
}

Settings configured(const std::vector<Setting>& changes)
{
    Settings settings = defaultSettings(EffectId::LensReflections);
    setSetting(settings, "working_mode", 1);
    setSetting(settings, "threshold", -2.0);
    setSetting(settings, "amount", 82.0);
    setSetting(settings, "spread", 73.0);
    setSetting(settings, "blur", 0.35);
    setSetting(settings, "chroma", 24.0);
    setSetting(settings, "source_smoothness", 35.0);
    for (const Setting& change : changes) setSetting(settings, change.first, change.second);
    return settings;
}

Metrics renderPair(int width, int height, DataWindow bounds, RectI window, const Settings& settings,
                   double time = 0.0, RenderScale scale = {1.0, 1.0}, Matte* matte = nullptr,
                   AlphaAssociation alpha_association = AlphaAssociation::Straight)
{
    Metrics result;
    Frame frame(width, height, bounds.x, bounds.y);
    if (settingChoice(settings, "working_mode") == 1) {
        const int hx = bounds.x + width * 3 / 4;
        const int hy = bounds.y + height / 2;
        float* highlight = reinterpret_cast<float*>(frame.source.data() +
            static_cast<std::size_t>(hy - bounds.y) * frame.row_bytes +
            static_cast<std::size_t>(hx - bounds.x) * kRgbaBytes);
        highlight[0] = 12.0F;
        highlight[1] = 5.0F;
        highlight[2] = 1.5F;
    }
    const FrameSurface cpu_source{MemoryKind::Cpu, PixelFormat::RgbaFloat32, frame.source.data(), 0U,
                                  frame.row_bytes, frame.bounds};
    const FrameSurface cpu_destination{MemoryKind::Cpu, PixelFormat::RgbaFloat32, frame.destination.data(), 0U,
                                       frame.row_bytes, frame.bounds};
    RenderRequest cpu_request{EffectId::LensReflections, cpu_source, cpu_destination, window, time, scale,
                              alpha_association, settings};
    ExternalMatteInput cpu_external{};
    if (matte != nullptr) {
        cpu_external = ExternalMatteInput{
            FrameSurface{MemoryKind::Cpu, matte->format, matte->bytes.data(), 0U, matte->row_bytes, matte->bounds},
            matte->association};
        cpu_request.external_matte = &cpu_external;
    }
    CpuRenderBackend cpu_backend;
    if (cbef::render(cpu_request, cpu_backend).kind != SubmissionKind::Completed) return result;

    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        id<MTLCommandQueue> queue = device == nil ? nil : [device newCommandQueue];
        id<MTLBuffer> source = device == nil ? nil :
            [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = device == nil ? nil :
            [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
        id<MTLBuffer> matte_buffer = matte == nullptr || device == nil ? nil :
            [device newBufferWithLength:matte->bytes.size() options:MTLResourceStorageModeShared];
        if (queue == nil || source == nil || destination == nil || (matte != nullptr && matte_buffer == nil)) return result;
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, kSentinel, frame.destination.size());
        if (matte != nullptr) std::memcpy(matte_buffer.contents, matte->bytes.data(), matte->bytes.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)source, 0U,
                                            frame.row_bytes, frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, frame.row_bytes, frame.bounds};
        ExternalMatteInput metal_external{};
        if (matte != nullptr) {
            metal_external = ExternalMatteInput{
                FrameSurface{MemoryKind::Metal, matte->format, (__bridge void*)matte_buffer, 0U,
                             matte->row_bytes, matte->bounds}, matte->association};
            metal_request.external_matte = &metal_external;
        }
        MetalRenderBackend metal_backend((__bridge void*)queue);
        result.submitted = cbef::render(metal_request, metal_backend).kind == SubmissionKind::Enqueued;
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        [sentinel commit];
        [sentinel waitUntilCompleted];
        result.submitted = result.submitted && sentinel.status == MTLCommandBufferStatusCompleted;

        double error_sum = 0.0;
        std::size_t samples = 0U;
        double cpu_x = 0.0, cpu_y = 0.0, metal_x = 0.0, metal_y = 0.0;
        const auto* metal_bytes = static_cast<const std::uint8_t*>(destination.contents);
        for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
            for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
                const std::size_t offset = static_cast<std::size_t>(y - bounds.y) * frame.row_bytes +
                                           static_cast<std::size_t>(x - bounds.x) * kRgbaBytes;
                const bool inside = x >= window.x1 && x < window.x2 && y >= window.y1 && y < window.y2;
                if (!inside) {
                    for (std::size_t byte = 0; byte < kRgbaBytes; ++byte)
                        result.crop_exact = result.crop_exact && metal_bytes[offset + byte] == kSentinel;
                    continue;
                }
                const float* cpu = reinterpret_cast<const float*>(frame.destination.data() + offset);
                const float* metal = reinterpret_cast<const float*>(metal_bytes + offset);
                for (int channel = 0; channel < 3; ++channel) {
                    const double error = std::abs(static_cast<double>(cpu[channel]) - metal[channel]);
                    result.max_error = std::max(result.max_error, error);
                    error_sum += error;
                    ++samples;
                    result.finite = result.finite && std::isfinite(metal[channel]);
                }
                result.alpha_exact = result.alpha_exact && std::memcmp(&cpu[3], &metal[3], sizeof(float)) == 0;
                const double ce = positiveLuma(cpu);
                const double me = positiveLuma(metal);
                result.cpu_energy += ce;
                result.metal_energy += me;
                cpu_x += static_cast<double>(x) * ce;
                cpu_y += static_cast<double>(y) * ce;
                metal_x += static_cast<double>(x) * me;
                metal_y += static_cast<double>(y) * me;
                for (std::size_t byte = 0; byte < kRgbaBytes; ++byte) {
                    result.hash ^= metal_bytes[offset + byte];
                    result.hash *= 1099511628211ULL;
                }
            }
        }
        result.mean_error = samples == 0U ? 0.0 : error_sum / static_cast<double>(samples);
        if (result.cpu_energy > 1.0e-12) {
            result.cpu_centroid_x = cpu_x / result.cpu_energy;
            result.cpu_centroid_y = cpu_y / result.cpu_energy;
        }
        if (result.metal_energy > 1.0e-12) {
            result.metal_centroid_x = metal_x / result.metal_energy;
            result.metal_centroid_y = metal_y / result.metal_energy;
        }
        [matte_buffer release];
        [source release];
        [destination release];
        [queue release];
    }
    return result;
}

bool parity(const Metrics& metrics)
{
    const double centroid = std::hypot(metrics.cpu_centroid_x - metrics.metal_centroid_x,
                                       metrics.cpu_centroid_y - metrics.metal_centroid_y);
    const double energy = std::abs(metrics.cpu_energy - metrics.metal_energy) /
                          std::max(metrics.cpu_energy, 1.0e-12);
    return metrics.submitted && metrics.finite && metrics.alpha_exact && metrics.crop_exact &&
           metrics.max_error <= 2.0e-4 && metrics.mean_error <= 2.0e-5 && centroid <= 0.1 && energy <= 0.005;
}

void report(const char* label, const Metrics& metrics, int first = -1, int second = -1)
{
    const double centroid = std::hypot(metrics.cpu_centroid_x - metrics.metal_centroid_x,
                                       metrics.cpu_centroid_y - metrics.metal_centroid_y);
    const double energy = std::abs(metrics.cpu_energy - metrics.metal_energy) /
                          std::max(metrics.cpu_energy, 1.0e-12);
    if (!parity(metrics)) {
        std::fprintf(stderr,
                     "%s (%d,%d): submitted=%d finite=%d alpha=%d crop=%d max=%g mean=%g centroid=%g energy=%g\n",
                     label, first, second, metrics.submitted, metrics.finite, metrics.alpha_exact, metrics.crop_exact,
                     metrics.max_error, metrics.mean_error, centroid, energy);
    }
}

int mainTest()
{
    const DataWindow odd{-7, 5, 63, 41};
    const RectI crop{-3, 8, 51, 43};
    for (int mode = 0; mode < 3; ++mode) {
        for (int model = 0; model < 3; ++model) {
            const Metrics metrics = renderPair(odd.width, odd.height, odd, crop,
                configured({{"working_mode", mode}, {"lens_model", model}, {"output_view", 0}, {"amount", 18.0}}));
            report("mode-profile", metrics, mode, model);
            CHECK(parity(metrics), "working-mode/profile CPU-Metal parity failed");
        }
    }

    for (int view : {3, 4, 5, 7}) {
        const Metrics metrics = renderPair(odd.width, odd.height, odd, crop,
            configured({{"output_view", view}, {"lens_model", 2}, {"anamorphism", 2.2},
                        {"source_mode", 1}, {"manual_x", 42.0}, {"manual_y", -12.0},
                        {"manual_size", 8.0}, {"amount", 18.0}}));
        report("diagnostic", metrics, view);
        CHECK(parity(metrics), "Source Map/Ghost Paths/Elements diagnostics parity failed");
    }
    const Metrics auto_source_map = renderPair(odd.width, odd.height, odd, crop,
        configured({{"output_view", 3}, {"amount", 18.0}}));
    report("auto-source-map", auto_source_map);
    CHECK(parity(auto_source_map), "automatic multi-source map parity failed");

    for (int solo = 1; solo <= 5; ++solo) {
        const Metrics metrics = renderPair(odd.width, odd.height, odd, crop,
            configured({{"source_mode", 1}, {"manual_x", 47.0}, {"manual_y", -18.0},
                        {"manual_size", 7.0}, {"manual_intensity", 135.0}, {"manual_color", 2},
                        {"element_solo", solo}, {"output_view", 6}}));
        CHECK(parity(metrics), "manual source/element solo parity failed");
    }

    Matte alpha_matte(17, 13, PixelFormat::AlphaFloat32);
    Matte rgba_matte(17, 13, PixelFormat::RgbaFloat32);
    for (Matte* matte : {&alpha_matte, &rgba_matte}) {
        for (double morphology : {-75.0, 0.0, 75.0}) {
            const Metrics metrics = renderPair(odd.width, odd.height, odd, crop,
                configured({{"output_view", 7}, {"source_morphology", morphology}}), 3.0,
                RenderScale{0.5, 0.5}, matte);
            CHECK(parity(metrics), "Alpha/RGBA external matte or morphology parity failed");
        }
    }

    for (double scale : {0.5, 1.0, 2.0}) {
        const Metrics metrics = renderPair(odd.width, odd.height, odd, crop,
            configured({{"output_view", 1}, {"background_adaptation", 60.0}, {"veil", 28.0}}),
            7.0, RenderScale{scale, scale}, nullptr, AlphaAssociation::Premultiplied);
        CHECK(parity(metrics), "odd-origin/render-scale/HDR/premultiplied parity failed");
    }

    const Metrics offscreen = renderPair(odd.width, odd.height, odd, crop,
        configured({{"source_mode", 1}, {"manual_x", 300.0}, {"manual_y", -220.0},
                    {"manual_size", 9.0}, {"output_view", 1}}));
    CHECK(parity(offscreen), "offscreen manual-source parity failed");

    const Settings identity = configured({{"mix", 0.0}, {"output_view", 0}});
    const Metrics identity_metrics = renderPair(odd.width, odd.height, odd, crop, identity);
    CHECK(parity(identity_metrics) && identity_metrics.max_error == 0.0,
          "identity/alpha/crop contract must be bit exact");

    const Settings component = configured({{"output_view", 1}, {"blur", 0.0}, {"chroma", 0.0}, {"amount", 10.0}});
    const Metrics component_metrics = renderPair(257, 129, DataWindow{3, -4, 257, 129},
                                                  RectI{3, -4, 260, 125}, component);
    report("component", component_metrics);
    CHECK(parity(component_metrics), "centroid/energy public seam failed");

    const Settings dimension_guard = configured({{"source_mode", 1}, {"manual_size", 55.0},
                                                   {"manual_intensity", 100.0}, {"output_view", 7}});
    const Metrics eight_k_wide = renderPair(8192, 16, DataWindow{0, 0, 8192, 16},
                                            RectI{4086, 3, 4106, 13}, dimension_guard);
    const Metrics twelve_k_wide = renderPair(12288, 8, DataWindow{-2, 7, 12288, 8},
                                             RectI{6132, 8, 6152, 14}, dimension_guard);
    const Metrics eight_k_tall = renderPair(16, 8192, DataWindow{5, -3, 16, 8192},
                                            RectI{8, 4083, 18, 4103}, dimension_guard);
    const Metrics twelve_k_tall = renderPair(8, 12288, DataWindow{-4, 2, 8, 12288},
                                             RectI{-3, 6136, 3, 6156}, dimension_guard);
    report("8K-wide", eight_k_wide);
    report("12K-wide", twelve_k_wide);
    report("8K-tall", eight_k_tall);
    report("12K-tall", twelve_k_tall);
    CHECK(parity(eight_k_wide) && parity(twelve_k_wide) && parity(eight_k_tall) && parity(twelve_k_tall),
          "8K/12K shallow-wide or tall-narrow correctness seam failed");

    const Metrics seek_a = renderPair(odd.width, odd.height, odd, crop, component, 17.0);
    const Metrics seek_b = renderPair(odd.width, odd.height, odd, crop, component, -4.0);
    const Metrics seek_repeat = renderPair(odd.width, odd.height, odd, crop, component, 17.0);
    CHECK(parity(seek_a) && parity(seek_b) && parity(seek_repeat) && seek_a.hash == seek_repeat.hash &&
              seek_a.hash == seek_b.hash,
          "random/reverse seek changed deterministic Lens output");
    return 0;
}
} // namespace

int main()
{
    if (mainTest() != 0) return 1;
    std::puts("lens_v2_metal_ticket21: PASS (public seam, diagnostics, matte, profiles, solo, 8K/12K)");
    return 0;
}
