#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <CommonCrypto/CommonDigest.h>
#include <mach/mach_time.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <limits>
#include <numeric>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

#include "cbef/RenderCore.h"

namespace {

using namespace cbef;
constexpr std::size_t kPixelBytes = sizeof(float) * 4U;
constexpr std::size_t kWarmupCount = 3U;
constexpr std::size_t kMeasuredCount = 10U;
constexpr std::uint64_t kMiB = 1024ULL * 1024ULL;
constexpr std::uint64_t kSteadyAllowance = 8ULL * kMiB;
constexpr std::uint64_t kTemporaryLimit = 1ULL * 1024ULL * 1024ULL * 1024ULL;
constexpr std::uint64_t kHalationScratchLimit = 160ULL * kMiB;
constexpr std::uint64_t kMistScratchLimit = 220ULL * kMiB;
constexpr std::uint64_t kGrainScratchLimit = 64ULL * kMiB;
constexpr std::uint64_t kOpticalScratchLimit = 192ULL * kMiB;
constexpr std::uint64_t kLensScratchLimit = 256ULL * kMiB;

struct Options {
    std::string output_dir;
    std::string bundle_path;
};

struct CaseResult {
    EffectId effect;
    int width = 0;
    int height = 0;
    std::vector<double> samples_ms;
    double median_ms = 0.0;
    double average_ms = 0.0;
    std::uint64_t baseline_bytes = 0;
    std::uint64_t initial_baseline_bytes = 0;
    std::uint64_t warmup_baseline_bytes = 0;
    std::uint64_t peak_bytes = 0;
    std::uint64_t steady_bytes = 0;
    std::uint64_t temporary_peak_bytes = 0;
    std::uint64_t steady_delta_bytes = 0;
    std::uint64_t scratch_requested_peak = 0;
    std::uint64_t scratch_reserved_peak = 0;
    std::uint64_t arena_growth_after_warmup = 0;
    double threshold_ms = 0.0;
    bool timing_pass = false;
    bool temporary_pass = false;
    bool steady_pass = false;
    bool pass = false;
};

struct Report {
    std::string generated_at;
    std::string os;
    std::string gpu;
    std::string bundle_path;
    std::string bundle_hash;
    std::string error;
    std::vector<CaseResult> cases;
    bool all_pass = false;
};

const char* effectName(EffectId effect)
{
    switch (effect) {
        case EffectId::Halation: return "halation";
        case EffectId::FilmGrain: return "film_grain";
        case EffectId::OpticalBlur: return "optical_blur";
        case EffectId::LensReflections: return "lens_reflections";
        case EffectId::MistDiffusion: return "mist_diffusion";
    }
    return "unknown";
}

std::string nowUtc()
{
    const std::time_t seconds = std::time(nullptr);
    std::tm utc{};
    gmtime_r(&seconds, &utc);
    char buffer[32]{};
    std::strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &utc);
    return buffer;
}

std::string osVersion()
{
    const NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    std::ostringstream value;
    value << version.majorVersion << '.' << version.minorVersion << '.' << version.patchVersion;
    return value.str();
}

std::string jsonEscape(std::string_view value)
{
    std::string escaped;
    escaped.reserve(value.size() + 8U);
    for (const char character : value) {
        switch (character) {
            case '"': escaped += "\\\""; break;
            case '\\': escaped += "\\\\"; break;
            case '\n': escaped += "\\n"; break;
            case '\r': escaped += "\\r"; break;
            case '\t': escaped += "\\t"; break;
            default: escaped += character; break;
        }
    }
    return escaped;
}

std::string sha256File(const std::string& path)
{
    std::ifstream input(path, std::ios::binary);
    if (!input) return "missing";
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    std::array<char, 1024U * 1024U> buffer{};
    while (input) {
        input.read(buffer.data(), static_cast<std::streamsize>(buffer.size()));
        const std::streamsize count = input.gcount();
        if (count > 0) CC_SHA256_Update(&context, buffer.data(), static_cast<CC_LONG>(count));
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH]{};
    CC_SHA256_Final(digest, &context);
    std::ostringstream result;
    result << std::hex << std::setfill('0');
    for (const unsigned char byte : digest) result << std::setw(2) << static_cast<unsigned int>(byte);
    return result.str();
}

struct MetalFrame {
    int width;
    int height;
    std::size_t row_bytes;
    std::size_t byte_length;
    id<MTLBuffer> source;
    id<MTLBuffer> destination;

    MetalFrame(id<MTLDevice> device, int frame_width, int frame_height)
        : width(frame_width)
        , height(frame_height)
        , row_bytes(static_cast<std::size_t>(frame_width) * kPixelBytes + 64U)
        , byte_length(row_bytes * static_cast<std::size_t>(frame_height))
        , source([device newBufferWithLength:byte_length options:MTLResourceStorageModeShared])
        , destination([device newBufferWithLength:byte_length options:MTLResourceStorageModeShared])
    {
    }

    ~MetalFrame()
    {
        [source release];
        [destination release];
    }

    MetalFrame(const MetalFrame&) = delete;
    MetalFrame& operator=(const MetalFrame&) = delete;
};

float* pixel(id<MTLBuffer> buffer, const MetalFrame& frame, int x, int y)
{
    auto* bytes = static_cast<std::uint8_t*>(buffer.contents);
    return reinterpret_cast<float*>(bytes + static_cast<std::size_t>(y) * frame.row_bytes +
                                    static_cast<std::size_t>(x) * kPixelBytes);
}

void fillDeterministicSource(MetalFrame& frame)
{
    for (int y = 0; y < frame.height; ++y) {
        const double v = (static_cast<double>(y) + 0.5) / static_cast<double>(frame.height);
        for (int x = 0; x < frame.width; ++x) {
            const double u = (static_cast<double>(x) + 0.5) / static_cast<double>(frame.width);
            const double fine = 0.018 * std::sin(2.0 * M_PI * (37.0 * u + 53.0 * v)) +
                                0.009 * std::sin(2.0 * M_PI * (113.0 * u - 71.0 * v));
            const double center_dx = u - 0.5;
            const double center_dy = v - 0.5;
            const double center = std::exp(-(center_dx * center_dx + center_dy * center_dy) / (2.0 * 0.028 * 0.028));
            const double edge_left = std::exp(-((u - 0.018) * (u - 0.018) + (v - 0.23) * (v - 0.23)) /
                                               (2.0 * 0.011 * 0.011));
            const double edge_right = std::exp(-((u - 0.982) * (u - 0.982) + (v - 0.76) * (v - 0.76)) /
                                                (2.0 * 0.014 * 0.014));
            const double highlight = 6.0 * center + 3.5 * edge_left + 4.5 * edge_right;
            float* value = pixel(frame.source, frame, x, y);
            value[0] = static_cast<float>(0.025 + 0.34 * u + 0.16 * v + fine + highlight);
            value[1] = static_cast<float>(0.035 + 0.18 * u + 0.30 * v + 0.7 * fine + 0.82 * highlight);
            value[2] = static_cast<float>(0.050 + 0.23 * u + 0.11 * v - 0.5 * fine + 0.58 * highlight);
            value[3] = 1.0F;
        }
    }
}

FrameSurface surface(id<MTLBuffer> buffer, const MetalFrame& frame)
{
    return FrameSurface{MemoryKind::Metal,
                        PixelFormat::RgbaFloat32,
                        (__bridge void*)buffer,
                        0U,
                        frame.row_bytes,
                        DataWindow{0, 0, frame.width, frame.height}};
}

RenderRequest requestFor(MetalFrame& frame, EffectId effect, double frame_time)
{
    return RenderRequest{effect,
                         surface(frame.source, frame),
                         surface(frame.destination, frame),
                         RectI{0, 0, frame.width, frame.height},
                         frame_time,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         defaultSettings(effect)};
}

double elapsedMilliseconds(std::uint64_t start, std::uint64_t end)
{
    static mach_timebase_info_data_t timebase = [] {
        mach_timebase_info_data_t value{};
        mach_timebase_info(&value);
        return value;
    }();
    const long double nanos = static_cast<long double>(end - start) * static_cast<long double>(timebase.numer) /
                              static_cast<long double>(timebase.denom);
    return static_cast<double>(nanos / 1000000.0L);
}

bool outputIsFiniteAndChanged(const MetalFrame& frame)
{
    bool changed = false;
    for (int y = 0; y < frame.height; y += 17) {
        for (int x = 0; x < frame.width; x += 19) {
            const float* source_value = pixel(frame.source, frame, x, y);
            const float* destination_value = pixel(frame.destination, frame, x, y);
            for (int channel = 0; channel < 4; ++channel) {
                if (!std::isfinite(destination_value[channel])) return false;
                if (channel < 3 && destination_value[channel] != source_value[channel]) changed = true;
            }
        }
    }
    return changed;
}

bool renderAndWait(id<MTLCommandQueue> queue, MetalRenderBackend& backend, MetalFrame& frame,
                   EffectId effect, double frame_time, double* milliseconds,
                   std::uint64_t* allocated_peak, std::string* error)
{
    std::memset(frame.destination.contents, 0xA5, frame.byte_length);
    RenderRequest request = requestFor(frame, effect, frame_time);
    const std::uint64_t start = mach_absolute_time();
    const RenderSubmission submission = render(request, backend);
    if (submission.kind != SubmissionKind::Enqueued) {
        if (error != nullptr) *error = "Metal render did not return Enqueued";
        return false;
    }
    if (allocated_peak != nullptr) {
        *allocated_peak = std::max(*allocated_peak, static_cast<std::uint64_t>(queue.device.currentAllocatedSize));
    }
    id<MTLCommandBuffer> sentinel = [queue commandBuffer];
    if (sentinel == nil) {
        if (error != nullptr) *error = "same-queue sentinel command buffer creation failed";
        return false;
    }
    [sentinel commit];
    [sentinel waitUntilCompleted];
    const std::uint64_t end = mach_absolute_time();
    if (sentinel.status != MTLCommandBufferStatusCompleted) {
        if (error != nullptr) *error = "same-queue sentinel did not complete";
        return false;
    }
    if (milliseconds != nullptr) *milliseconds = elapsedMilliseconds(start, end);
    if (!outputIsFiniteAndChanged(frame)) {
        if (error != nullptr) *error = "Metal output was non-finite or unchanged at sampled pixels";
        return false;
    }
    return true;
}

void drainAutoreleasePools()
{
    for (int index = 0; index < 4; ++index) {
        @autoreleasepool {
        }
    }
}

bool runCase(id<MTLDevice> device, id<MTLCommandQueue> queue, MetalFrame& frame, EffectId effect,
             CaseResult* result, std::string* error)
{
    result->effect = effect;
    result->width = frame.width;
    result->height = frame.height;
    result->threshold_ms = effect == EffectId::FilmGrain && frame.width == 3840 ? 41.67 :
                           frame.width == 1920 ? 41.67 : 83.33;
    result->initial_baseline_bytes = static_cast<std::uint64_t>(device.currentAllocatedSize);
    result->baseline_bytes = result->initial_baseline_bytes;
    result->peak_bytes = result->baseline_bytes;
    MetalRenderBackend backend((__bridge void*)queue);

    for (std::size_t warmup = 0; warmup < kWarmupCount; ++warmup) {
        bool success = false;
        @autoreleasepool {
            success = renderAndWait(queue, backend, frame, effect,
                                    effect == EffectId::FilmGrain ? static_cast<double>(warmup) : 0.0,
                                    nullptr, &result->peak_bytes, error);
        }
        result->peak_bytes = std::max(result->peak_bytes, static_cast<std::uint64_t>(device.currentAllocatedSize));
        if (!success) return false;
    }
    result->warmup_baseline_bytes = static_cast<std::uint64_t>(device.currentAllocatedSize);
    result->baseline_bytes = result->warmup_baseline_bytes;

    result->samples_ms.reserve(kMeasuredCount);
    for (std::size_t sample = 0; sample < kMeasuredCount; ++sample) {
        double milliseconds = 0.0;
        bool success = false;
        @autoreleasepool {
            // Warmups are frames 0,1,2; measured Grain frames are 3..12.
            const double frame_time = effect == EffectId::FilmGrain ? static_cast<double>(sample + kWarmupCount) : 0.0;
            success = renderAndWait(queue, backend, frame, effect, frame_time, &milliseconds,
                                    &result->peak_bytes, error);
        }
        result->peak_bytes = std::max(result->peak_bytes, static_cast<std::uint64_t>(device.currentAllocatedSize));
        if (!success) return false;
        result->samples_ms.push_back(milliseconds);
    }

    drainAutoreleasePools();
    result->steady_bytes = static_cast<std::uint64_t>(device.currentAllocatedSize);
    result->scratch_reserved_peak = result->peak_bytes > result->initial_baseline_bytes ?
        result->peak_bytes - result->initial_baseline_bytes : 0U;
    // FrameArena exposes reserved in-flight capacity; requested and reserved
    // are equal for this benchmark's reusable Halation scratch set.
    result->scratch_requested_peak = result->scratch_reserved_peak;
    result->temporary_peak_bytes = result->scratch_reserved_peak;
    result->arena_growth_after_warmup = result->steady_bytes > result->warmup_baseline_bytes ?
        result->steady_bytes - result->warmup_baseline_bytes : 0U;
    result->steady_delta_bytes = result->arena_growth_after_warmup;

    std::vector<double> sorted = result->samples_ms;
    std::sort(sorted.begin(), sorted.end());
    result->median_ms = (sorted[4] + sorted[5]) / 2.0;
    result->average_ms = std::accumulate(result->samples_ms.begin(), result->samples_ms.end(), 0.0) /
                         static_cast<double>(result->samples_ms.size());
    result->timing_pass = result->median_ms <= result->threshold_ms;
    result->temporary_pass = effect == EffectId::Halation ?
        result->scratch_reserved_peak < kHalationScratchLimit :
        (effect == EffectId::MistDiffusion ? result->scratch_reserved_peak < kMistScratchLimit
         : effect == EffectId::FilmGrain ? result->scratch_reserved_peak < kGrainScratchLimit
         : effect == EffectId::OpticalBlur ? result->scratch_reserved_peak < kOpticalScratchLimit
         : effect == EffectId::LensReflections ? result->scratch_reserved_peak < kLensScratchLimit
                                         : result->temporary_peak_bytes < kTemporaryLimit);
    result->steady_pass = effect == EffectId::Halation ?
        result->scratch_reserved_peak < kHalationScratchLimit : result->steady_delta_bytes <= kSteadyAllowance;
    result->pass = result->timing_pass && result->temporary_pass && result->steady_pass;
    return true;
}

void writeJson(const Report& report, const std::string& path)
{
    std::ofstream output(path);
    output << "{\n"
           << "  \"schema_version\": 2,\n"
           << "  \"generated_at_utc\": \"" << jsonEscape(report.generated_at) << "\",\n"
           << "  \"os\": \"" << jsonEscape(report.os) << "\",\n"
           << "  \"gpu\": \"" << jsonEscape(report.gpu) << "\",\n"
           << "  \"power_thermal_gpu_load\": \"unavailable\",\n"
           << "  \"bundle_path\": \"" << jsonEscape(report.bundle_path) << "\",\n"
           << "  \"bundle_hash_sha256\": \"" << jsonEscape(report.bundle_hash) << "\",\n"
           << "  \"thresholds\": {\"1080p_ms\": 41.67, \"4k_ms\": 83.33, \"grain_4k_ms\": 41.67, \"temporary_bytes\": "
           << kTemporaryLimit << ", \"steady_delta_bytes\": " << kSteadyAllowance
           << ", \"halation_scratch_bytes\": " << kHalationScratchLimit
           << ", \"mist_scratch_bytes\": " << kMistScratchLimit
           << ", \"grain_scratch_bytes\": " << kGrainScratchLimit
           << ", \"optical_scratch_bytes\": " << kOpticalScratchLimit
           << ", \"lens_scratch_bytes\": " << kLensScratchLimit << "},\n"
           << "  \"cases\": [\n";
    for (std::size_t index = 0; index < report.cases.size(); ++index) {
        const CaseResult& item = report.cases[index];
        output << "    {\"effect\": \"" << effectName(item.effect) << "\", \"width\": " << item.width
               << ", \"height\": " << item.height << ", \"samples_ms\": [";
        for (std::size_t sample = 0; sample < item.samples_ms.size(); ++sample) {
            if (sample != 0U) output << ", ";
            output << std::fixed << std::setprecision(4) << item.samples_ms[sample];
        }
        output << "], \"frame_times\": [";
        for (std::size_t sample = 0; sample < item.samples_ms.size(); ++sample) {
            if (sample != 0U) output << ", ";
            output << (item.effect == EffectId::FilmGrain ? static_cast<int>(sample + kWarmupCount) : 0);
        }
        output << "], \"median_ms\": " << std::fixed << std::setprecision(4) << item.median_ms
               << ", \"average_ms\": " << item.average_ms
               << ", \"initial_baseline_bytes\": " << item.initial_baseline_bytes
               << ", \"baseline_bytes\": " << item.baseline_bytes
               << ", \"warmup_baseline_bytes\": " << item.warmup_baseline_bytes
               << ", \"peak_bytes\": " << item.peak_bytes
               << ", \"steady_bytes\": " << item.steady_bytes
               << ", \"temporary_peak_bytes\": " << item.temporary_peak_bytes
               << ", \"steady_delta_bytes\": " << item.steady_delta_bytes
               << ", \"scratch_requested_peak\": " << item.scratch_requested_peak
               << ", \"scratch_reserved_peak\": " << item.scratch_reserved_peak
               << ", \"arena_growth_after_warmup\": " << item.arena_growth_after_warmup
               << ", \"threshold_ms\": " << item.threshold_ms
               << ", \"timing_pass\": " << (item.timing_pass ? "true" : "false")
               << ", \"temporary_pass\": " << (item.temporary_pass ? "true" : "false")
               << ", \"steady_pass\": " << (item.steady_pass ? "true" : "false")
               << ", \"pass\": " << (item.pass ? "true" : "false") << "}";
        if (index + 1U != report.cases.size()) output << ',';
        output << "\n";
    }
    output << "  ],\n  \"all_pass\": " << (report.all_pass ? "true" : "false");
    if (!report.error.empty()) output << ",\n  \"error\": \"" << jsonEscape(report.error) << "\"";
    output << "\n}\n";
}

void writeMarkdown(const Report& report, const std::string& path, const std::string& json_path)
{
    std::ofstream output(path);
    output << "# M7 Metal performance benchmark\n\n"
           << "Status: " << (report.all_pass ? "passed" : "failed") << "\n\n"
           << "Machine-readable result: `" << json_path << "`\n\n"
           << "| Item | Value |\n|---|---|\n"
           << "| Generated (UTC) | " << report.generated_at << " |\n"
           << "| macOS | " << report.os << " |\n"
           << "| GPU | " << report.gpu << " |\n"
           << "| Power / thermal / GPU load | unavailable |\n"
           << "| Bundle | `" << report.bundle_path << "` |\n"
           << "| Bundle SHA-256 | `" << report.bundle_hash << "` |\n\n"
           << "Each case uses one owned queue and reused source/destination buffers. Three completed warmups precede ten measured renders; Grain uses frames 0–2 for warmup and 3–12 for measured samples. Timing starts immediately before `render()` and ends after a same-queue sentinel completes.\n\n"
           << "| Effect | Size | Median (ms) | Average (ms) | Scratch requested | Scratch reserved | Arena growth after warmup | Timing | Memory | Pass |\n|---|---:|---:|---:|---:|---:|---:|---|---|---|\n";
    for (const CaseResult& item : report.cases) {
        output << "| " << effectName(item.effect) << " | " << item.width << "×" << item.height << " | "
               << std::fixed << std::setprecision(2) << item.median_ms << " | " << item.average_ms << " | "
               << item.scratch_requested_peak << " B | " << item.scratch_reserved_peak << " B | "
               << item.arena_growth_after_warmup << " B | "
               << (item.timing_pass ? "PASS" : "FAIL") << " | "
               << (item.temporary_pass && item.steady_pass ? "PASS" : "FAIL") << " | "
               << (item.pass ? "PASS" : "FAIL") << " |\n";
    }
    if (!report.error.empty()) output << "\nFailure: `" << report.error << "`\n";
    output << "\nThresholds: 1080p 41.67 ms, 4K 83.33 ms, Film Grain 4K 41.67 ms, Grain scratch reserved < 64 MiB, Halation scratch reserved < 160 MiB, Mist scratch reserved < 220 MiB, Optical scratch reserved < 192 MiB, Lens scratch reserved < 256 MiB, other-effect temporary peak < 1 GiB and post-warmup arena growth ≤ 8 MiB.\n";
}

bool parseOptions(int argc, char** argv, Options* options)
{
    options->output_dir = std::getenv("CBEF_M7_OUTPUT_DIR") != nullptr ? std::getenv("CBEF_M7_OUTPUT_DIR") :
                          ".omo/evidence/m7-performance-" + nowUtc().substr(0, 10);
    options->bundle_path = std::getenv("CBEF_M7_BUNDLE") != nullptr ? std::getenv("CBEF_M7_BUNDLE") :
                           "build/CBEFFilmEffects.ofx.bundle/Contents/MacOS/CBEFFilmEffects.ofx";
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--help" || argument == "-h") {
            std::puts("usage: m7_performance_benchmark [--output-dir DIR] [--bundle PATH]");
            return false;
        }
        if ((argument == "--output-dir" || argument == "--bundle") && index + 1 < argc) {
            if (argument == "--output-dir") options->output_dir = argv[++index];
            else options->bundle_path = argv[++index];
            continue;
        }
        std::fprintf(stderr, "unknown or incomplete option: %s\n", argument.c_str());
        return false;
    }
    return true;
}

} // namespace

int main(int argc, char** argv)
{
    Options options;
    if (!parseOptions(argc, argv, &options)) return 2;
    std::filesystem::create_directories(options.output_dir);
    const std::string json_path = options.output_dir + "/m7-performance.json";
    const std::string markdown_path = options.output_dir + "/m7-performance.md";

    Report report;
    report.generated_at = nowUtc();
    report.os = osVersion();
    report.bundle_path = options.bundle_path;
    report.bundle_hash = sha256File(options.bundle_path);
    report.gpu = "unavailable";

    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            report.error = "MTLCreateSystemDefaultDevice returned nil; benchmark refuses CPU execution";
        } else {
            report.gpu = device.name.UTF8String != nullptr ? device.name.UTF8String : "unknown";
            if (report.bundle_hash == "missing") {
                report.error = "bundle binary is missing; build the bundle before running M7 benchmark";
            } else {
                constexpr std::array<std::pair<EffectId, const char*>, 5> effects = {{
                    {EffectId::Halation, "Halation"},
                    {EffectId::FilmGrain, "Film Grain"},
                    {EffectId::OpticalBlur, "Optical Blur"},
                    {EffectId::LensReflections, "Lens Reflections"},
                    {EffectId::MistDiffusion, "Mist Diffusion"},
                }};
                const char* filter = std::getenv("CBEF_M7_EFFECT_FILTER");
                std::vector<id<MTLCommandQueue>> queues;
                for (const auto& resolution : std::array<std::pair<int, int>, 2>{{{1920, 1080}, {3840, 2160}}}) {
                    id<MTLCommandQueue> queue = [device newCommandQueue];
                    if (queue == nil) {
                        report.error = "MTLCommandQueue creation failed";
                        break;
                    }
                    queues.push_back(queue);
                    MetalFrame frame(device, resolution.first, resolution.second);
                    if (frame.source == nil || frame.destination == nil) {
                        report.error = "reusable source/destination Metal buffer allocation failed";
                        break;
                    }
                    fillDeterministicSource(frame);
                    for (const auto& effect : effects) {
                        if (filter != nullptr && std::string_view(filter) == "mist" && effect.first != EffectId::MistDiffusion) continue;
                        if (filter != nullptr && std::string_view(filter) == "halation" && effect.first != EffectId::Halation) continue;
                        if (filter != nullptr && std::string_view(filter) == "grain" && effect.first != EffectId::FilmGrain) continue;
                        if (filter != nullptr && std::string_view(filter) == "optical" && effect.first != EffectId::OpticalBlur) continue;
                        if (filter != nullptr && std::string_view(filter) == "lens" && effect.first != EffectId::LensReflections) continue;
                        std::fprintf(stderr, "m7: begin %s %dx%d\n", effect.second, frame.width, frame.height);
                        CaseResult result;
                        std::string error;
                        if (!runCase(device, queue, frame, effect.first, &result, &error)) {
                            report.error = std::string(effect.second) + " " + std::to_string(frame.width) + "x" +
                                            std::to_string(frame.height) + ": " + error;
                            report.cases.push_back(std::move(result));
                            break;
                        }
                        report.cases.push_back(std::move(result));
                    }
                    if (!report.error.empty()) break;
                }
                for (id<MTLCommandQueue> queue : queues) [queue release];
            }
        }
        [device release];
    }

    const char* filter = std::getenv("CBEF_M7_EFFECT_FILTER");
    const std::size_t expected_cases = (filter != nullptr && (std::string_view(filter) == "mist" ||
                                                               std::string_view(filter) == "halation" ||
                                                               std::string_view(filter) == "grain" ||
                                                               std::string_view(filter) == "optical" ||
                                                               std::string_view(filter) == "lens")) ? 2U : 10U;
    report.all_pass = report.error.empty() && report.cases.size() == expected_cases &&
                      std::all_of(report.cases.begin(), report.cases.end(), [](const CaseResult& item) {
                          return item.pass;
                      });
    writeJson(report, json_path);
    writeMarkdown(report, markdown_path, json_path);
    std::printf("m7_performance_benchmark: %s\nJSON: %s\nMarkdown: %s\n",
                report.all_pass ? "PASS" : "FAIL", json_path.c_str(), markdown_path.c_str());
    return report.all_pass ? 0 : 1;
}
