#import <Metal/Metal.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <limits>
#include <string_view>
#include <utility>
#include <vector>

#include "cbef/RenderCore.h"

namespace {
using namespace cbef;
constexpr std::size_t kPixelBytes = sizeof(float) * 4U;
constexpr std::uint8_t kSentinel = 0xA5U;

#define CHECK(condition, message) \
    do { \
        if (!(condition)) { std::fprintf(stderr, "grain_v2_metal_ticket14: %s\n", message); return 1; } \
    } while (false)

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    Frame(int width, int height)
        : bounds{0, 0, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + 32U)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), kSentinel)
    {
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                float* p = reinterpret_cast<float*>(source.data() + static_cast<std::size_t>(y) * row_bytes +
                                                     static_cast<std::size_t>(x) * kPixelBytes);
                p[0] = 0.08F + 0.001F * static_cast<float>((x * 7 + y * 3) % 31);
                p[1] = 0.10F + 0.001F * static_cast<float>((x * 5 + y * 11) % 29);
                p[2] = 0.14F + 0.001F * static_cast<float>((x * 13 + y * 2) % 37);
                p[3] = 1.0F;
            }
        }
    }
};

FrameSurface cpuSurface(void* data, const Frame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, frame.bounds};
}

struct PairMetrics {
    double max_error = 0.0;
    double sum_abs = 0.0;
    std::size_t samples = 0U;
    std::vector<float> cpu_red;
    std::vector<float> metal_red;
    int max_x = 0;
    int max_y = 0;
    int max_channel = 0;
};

using Setting = std::pair<std::string_view, SettingValue>;

PairMetrics renderPair(const char* label, int width, int height, RectI window, double frame_time,
                       const std::vector<Setting>& settings)
{
    PairMetrics result;
    Frame frame(width, height);
    if (std::string_view(label) == "48-frame") {
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                float* p = reinterpret_cast<float*>(frame.source.data() + static_cast<std::size_t>(y) * frame.row_bytes +
                                                     static_cast<std::size_t>(x) * kPixelBytes);
                p[0] = p[1] = p[2] = 0.18F;
                p[3] = 1.0F;
            }
        }
    }
    RenderRequest cpu_request{EffectId::FilmGrain, cpuSurface(frame.source.data(), frame),
                              cpuSurface(frame.destination.data(), frame), window, frame_time,
                              RenderScale{1.0, 1.0}, AlphaAssociation::Straight,
                              defaultSettings(EffectId::FilmGrain)};
    setSetting(cpu_request.settings, "working_mode", 1);
    for (const Setting& setting : settings) setSetting(cpu_request.settings, setting.first, setting.second);
    CpuRenderBackend cpu_backend;
    if (cbef::render(cpu_request, cpu_backend).kind != SubmissionKind::Completed) {
        std::fprintf(stderr, "grain_v2_metal_ticket14: CPU %s render failed\n", label);
        return result;
    }

    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) return result;
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
        if (queue == nil || source == nil || destination == nil) return result;
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, kSentinel, frame.destination.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                            (__bridge void*)source, 0U, frame.row_bytes, frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, frame.row_bytes, frame.bounds};
        MetalRenderBackend metal_backend((__bridge void*)queue);
        if (cbef::render(metal_request, metal_backend).kind != SubmissionKind::Enqueued) return result;
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        if (sentinel == nil) return result;
        [sentinel commit];
        [sentinel waitUntilCompleted];
        if (sentinel.status != MTLCommandBufferStatusCompleted) return result;

        const int x1 = window.x1;
        const int x2 = window.x2;
        const int y1 = window.y1;
        const int y2 = window.y2;
        result.cpu_red.reserve(static_cast<std::size_t>(x2 - x1) * static_cast<std::size_t>(y2 - y1));
        result.metal_red.reserve(result.cpu_red.capacity());
        for (int y = y1; y < y2; ++y) {
            for (int x = x1; x < x2; ++x) {
                const auto* cpu = reinterpret_cast<const float*>(frame.destination.data() +
                    static_cast<std::size_t>(y) * frame.row_bytes + static_cast<std::size_t>(x) * kPixelBytes);
                const auto* metal = reinterpret_cast<const float*>(static_cast<const std::uint8_t*>(destination.contents) +
                    static_cast<std::size_t>(y) * frame.row_bytes + static_cast<std::size_t>(x) * kPixelBytes);
                result.cpu_red.push_back(cpu[0]);
                result.metal_red.push_back(metal[0]);
                for (int channel = 0; channel < 3; ++channel) {
                    const double error = std::abs(static_cast<double>(cpu[channel]) - metal[channel]);
                    if (error > result.max_error) {
                        result.max_error = error;
                        result.max_x = x;
                        result.max_y = y;
                        result.max_channel = channel;
                    }
                    result.sum_abs += std::abs(static_cast<double>(cpu[channel]) - metal[channel]);
                    ++result.samples;
                }
                std::uint32_t cpu_alpha = 0U;
                std::uint32_t metal_alpha = 0U;
                std::memcpy(&cpu_alpha, &cpu[3], sizeof(cpu_alpha));
                std::memcpy(&metal_alpha, &metal[3], sizeof(metal_alpha));
                if (cpu_alpha != metal_alpha) result.max_error = 1.0;
            }
        }
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                if (x >= x1 && x < x2 && y >= y1 && y < y2) continue;
                const auto* pixel = static_cast<const std::uint8_t*>(destination.contents) +
                                    static_cast<std::size_t>(y) * frame.row_bytes + static_cast<std::size_t>(x) * kPixelBytes;
                for (std::size_t byte = 0; byte < kPixelBytes; ++byte) {
                    if (pixel[byte] != kSentinel) result.max_error = 1.0;
                }
            }
            const std::uint8_t* padding = static_cast<const std::uint8_t*>(destination.contents) +
                                          static_cast<std::size_t>(y) * frame.row_bytes + static_cast<std::size_t>(width) * kPixelBytes;
            for (std::size_t byte = 0; byte < frame.row_bytes - static_cast<std::size_t>(width) * kPixelBytes; ++byte) {
                if (padding[byte] != kSentinel) result.max_error = 1.0;
            }
        }
        [source release];
        [destination release];
        [queue release];
    }
    return result;
}

double meanStops(const std::vector<float>& values)
{
    double sum = 0.0;
    for (float value : values) sum += std::log2(std::max(static_cast<double>(value), 1.0e-8) / 0.18);
    return values.empty() ? 0.0 : sum / static_cast<double>(values.size());
}

double rmsStops(const std::vector<float>& values)
{
    double sum = 0.0;
    for (float value : values) {
        const double stop = std::log2(std::max(static_cast<double>(value), 1.0e-8) / 0.18);
        sum += stop * stop;
    }
    return values.empty() ? 0.0 : std::sqrt(sum / static_cast<double>(values.size()));
}

double maxVectorDelta(const std::vector<float>& first, const std::vector<float>& second)
{
    if (first.size() != second.size()) return std::numeric_limits<double>::infinity();
    double maximum = 0.0;
    for (std::size_t index = 0; index < first.size(); ++index) {
        maximum = std::max(maximum, std::abs(static_cast<double>(first[index]) - second[index]));
    }
    return maximum;
}

int mainTest()
{
    std::vector<Setting> settings = {
        {"format", 1}, {"amount", 72.0}, {"size", 135.0}, {"softness", 32.0}, {"chroma", 20.0},
        {"stock_response", 2}, {"scan_sampling", 2}, {"processing_modifier", 1},
        {"film_resolution", 70.0}, {"clump", 22.0}, {"exposure_bias", 0.3},
    };
    const PairMetrics smoke = renderPair("1080p", 1920, 1080, RectI{181, 101, 197, 113}, 8.0, settings);
    CHECK(smoke.samples == 16U * 12U * 3U, "1080p Metal sample count must match render window");
    CHECK(smoke.max_error <= 2.0e-4, "1080p CPU/Metal Grain parity exceeded 2e-4");

    const PairMetrics uhd = renderPair("UHD", 3840, 2160, RectI{501, 701, 517, 713}, 9.0, settings);
    CHECK(uhd.samples == 16U * 12U * 3U && uhd.max_error <= 2.0e-4,
          "UHD CPU/Metal Grain parity or crop contract failed");

    const PairMetrics tiled = renderPair("tiled-v2", 320, 320, RectI{0, 0, 320, 320}, 9.5, settings);
    CHECK(tiled.samples == 320U * 320U * 3U && tiled.max_error <= 2.0e-4,
          "large-window v2 Grain parity failed (fast path must preserve population/record math)");

    const PairMetrics atlas = renderPair("atlas-v2", 640, 360, RectI{0, 0, 640, 360}, 9.75, settings);
    std::fprintf(stderr, "atlas max=%g at (%d,%d) ch=%d\n", atlas.max_error, atlas.max_x, atlas.max_y, atlas.max_channel);
    CHECK(atlas.samples == 640U * 360U * 3U && atlas.max_error <= 2.0e-4,
          "packed-basis v2 Grain parity failed for the benchmark-sized path");

    std::vector<Setting> strong_settings = settings;
    for (Setting& setting : strong_settings) {
        if (setting.first == "clump") setting.second = 65.0;
        if (setting.first == "stock_response") setting.second = 2;
        if (setting.first == "chroma") setting.second = 70.0;
        if (setting.first == "exposure_bias") setting.second = 1.5;
    }
    const PairMetrics strong = renderPair("strong-v2", 640, 360, RectI{0, 0, 640, 360}, 10.25, strong_settings);
    CHECK(strong.samples == 640U * 360U * 3U && strong.max_error <= 2.0e-4,
          "strong clump/covariance v2 Grain parity failed for the packed-basis path");


    const PairMetrics eight_k = renderPair("8K", 64, 4320, RectI{11, 4301, 27, 4313}, 10.0, settings);
    CHECK(eight_k.samples == 16U * 12U * 3U && eight_k.max_error <= 2.0e-4,
          "8K data-window CPU/Metal Grain parity failed");

    for (int stock = 0; stock < 3; ++stock) {
        for (int format = 0; format < 5; ++format) {
            std::vector<Setting> sample_settings = settings;
            for (Setting& setting : sample_settings) {
                if (setting.first == "stock_response") setting.second = stock;
                if (setting.first == "format") setting.second = format;
            }
            const PairMetrics sample = renderPair("stock-capture-grid", 128, 72, RectI{17, 19, 25, 27},
                                                  11.0 + stock * 5.0 + format, sample_settings);
            CHECK(sample.samples == 8U * 8U * 3U && sample.max_error <= 2.0e-4,
                  "Stock Response / Capture Format grid parity failed");
        }
    }

    const PairMetrics seek_forward = renderPair("seek-forward", 48, 32, RectI{0, 0, 48, 32}, 17.0, settings);
    const PairMetrics seek_adjacent = renderPair("seek-adjacent", 48, 32, RectI{0, 0, 48, 32}, 18.0, settings);
    const PairMetrics seek_reverse = renderPair("seek-reverse", 48, 32, RectI{0, 0, 48, 32}, 4.0, settings);
    const PairMetrics seek_repeat = renderPair("seek-repeat", 48, 32, RectI{0, 0, 48, 32}, 17.0, settings);
    CHECK(maxVectorDelta(seek_forward.metal_red, seek_repeat.metal_red) == 0.0,
          "random/reverse seek order changed a repeated frame");
    CHECK(maxVectorDelta(seek_forward.metal_red, seek_adjacent.metal_red) > 1.0e-5 &&
              maxVectorDelta(seek_forward.metal_red, seek_reverse.metal_red) > 1.0e-5,
          "adjacent or reverse-seek frames did not produce a distinct Grain structure");

    std::vector<float> all_cpu;
    std::vector<float> all_metal;
    double max_error = std::max({smoke.max_error, uhd.max_error, tiled.max_error, atlas.max_error,
                                 strong.max_error, eight_k.max_error});
    double sum_abs = smoke.sum_abs + uhd.sum_abs + tiled.sum_abs + atlas.sum_abs + strong.sum_abs + eight_k.sum_abs;
    std::size_t samples = smoke.samples + uhd.samples + tiled.samples + atlas.samples + strong.samples + eight_k.samples;
    const std::vector<Setting> statistical_settings = {
        {"amount", 28.0}, {"size", 100.0}, {"softness", 28.0}, {"chroma", 12.0},
        {"stock_response", 0}, {"scan_sampling", 1}, {"processing_modifier", 0},
        {"film_resolution", 72.0}, {"clump", 22.0}, {"exposure_bias", 0.0},
    };
    for (int frame = 0; frame < 48; ++frame) {
        PairMetrics metrics = renderPair("48-frame", 48, 32, RectI{0, 0, 48, 32}, static_cast<double>(frame),
                                         statistical_settings);
        CHECK(metrics.samples == 48U * 32U * 3U && metrics.max_error <= 2.0e-4,
              "48-frame CPU/Metal Grain parity exceeded 2e-4");
        max_error = std::max(max_error, metrics.max_error);
        sum_abs += metrics.sum_abs;
        samples += metrics.samples;
        all_cpu.insert(all_cpu.end(), metrics.cpu_red.begin(), metrics.cpu_red.end());
        all_metal.insert(all_metal.end(), metrics.metal_red.begin(), metrics.metal_red.end());
    }
    CHECK(all_cpu.size() == 48U * 48U * 32U, "48-frame CPU evidence sample count mismatch");
    const double cpu_mean = meanStops(all_cpu);
    const double metal_mean = meanStops(all_metal);
    const double cpu_rms = rmsStops(all_cpu);
    const double metal_rms = rmsStops(all_metal);
    CHECK(std::abs(cpu_mean) < 2.0e-3 && std::abs(metal_mean) < 2.0e-3,
          "48-frame mean bias must remain bounded");
    CHECK(cpu_rms >= 0.02128 && cpu_rms <= 0.02352 && metal_rms >= 0.02128 && metal_rms <= 0.02352,
          "48-frame RMS must remain in the CPU reference envelope");
    CHECK(std::abs(cpu_mean - metal_mean) <= 2.0e-4 && std::abs(cpu_rms - metal_rms) <= 2.0e-4,
          "48-frame CPU/Metal ensemble statistics diverged");

    const char* evidence = std::getenv("CBEF_GRAIN_METAL_EVIDENCE_DIR");
    if (evidence != nullptr && evidence[0] != '\0') {
        const std::filesystem::path directory(evidence);
        std::filesystem::create_directories(directory);
        std::ofstream json(directory / "ticket14-grain-metal-statistics.json");
        json << "{\"fixture_id\":\"grain-response-grid\",\"frames\":48,\"same_frame_pixel_threshold\":0.0002,"
             << "\"metrics\":[{\"id\":\"max_abs_pixel_error\",\"value\":" << max_error
             << ",\"threshold\":\"<=2e-4\",\"pass\":" << (max_error <= 2.0e-4 ? "true" : "false")
             << ",\"provenance\":\"internal tolerance\"},{\"id\":\"mean_bias_cpu_stop\",\"value\":" << cpu_mean
             << ",\"threshold\":\"abs<2e-3\",\"pass\":true,\"provenance\":\"internal tolerance\"},{\"id\":\"mean_bias_metal_stop\",\"value\":" << metal_mean
             << ",\"threshold\":\"abs<2e-3\",\"pass\":true,\"provenance\":\"internal tolerance\"},{\"id\":\"rms_cpu_stop\",\"value\":" << cpu_rms
             << ",\"threshold\":\"0.02128..0.02352\",\"pass\":true,\"provenance\":\"internal tolerance\"},{\"id\":\"rms_metal_stop\",\"value\":" << metal_rms
             << ",\"threshold\":\"0.02128..0.02352\",\"pass\":true,\"provenance\":\"internal tolerance\"},{\"id\":\"mean_rms_delta\",\"value\":"
             << std::max(std::abs(cpu_mean - metal_mean), std::abs(cpu_rms - metal_rms))
             << ",\"threshold\":\"<=2e-4\",\"pass\":true,\"provenance\":\"internal tolerance\"}],\"measured_profile_gate\":false}\n";
        std::ofstream report(directory / "ticket14-grain-metal-statistics.md");
        report << "# Ticket 14 Grain Metal Statistics\n\n"
               << "- fixture: grain-response-grid; CPU and Metal use the same 48 frame indices (0..47).\n"
               << "- same-frame max absolute pixel error: " << max_error << " (threshold <=2e-4, PASS)\n"
               << "- CPU mean bias: " << cpu_mean << " stops; Metal mean bias: " << metal_mean
               << " stops (threshold |x|<2e-3, PASS)\n"
               << "- CPU RMS: " << cpu_rms << " stops; Metal RMS: " << metal_rms
               << " stops (reference envelope 0.02128..0.02352, PASS)\n"
               << "- ensemble mean/RMS delta: " << std::max(std::abs(cpu_mean - metal_mean), std::abs(cpu_rms - metal_rms))
               << " (threshold <=2e-4, PASS)\n"
               << "- resolution crops: 1080p, UHD, and 8K-height; identity/crop/padding/alpha contracts preserved.\n"
               << "- measured_profile_gate: false\n";
    }
    std::printf("grain_v2_metal_ticket14: PASS (48-frame CPU/Metal; max_error=%.9g, mean_abs=%.9g)\n",
                max_error, samples == 0U ? 0.0 : sum_abs / static_cast<double>(samples));
    return 0;
}
}

int main()
{
    return mainTest();
}
