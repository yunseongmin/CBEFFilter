#import <Metal/Metal.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <numeric>
#include <vector>

#include "cbef/RenderCore.h"

namespace {

using namespace cbef;
constexpr std::size_t kPixelBytes = sizeof(float) * 4U;
constexpr std::uint8_t kDestinationSentinel = 0xA5U;

struct Frame {
    DataWindow bounds;
    int render_width;
    int render_height;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    Frame(int width, int height, int output_width = -1, int output_height = -1)
        : bounds{0, 0, width, height}
        , render_width(output_width > 0 ? output_width : width)
        , render_height(output_height > 0 ? output_height : height)
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + 16U)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), 0xA5U)
    {
    }
};

float* pixel(std::vector<std::uint8_t>& bytes, const Frame& frame, int x, int y)
{
    return reinterpret_cast<float*>(bytes.data() + static_cast<std::size_t>(y) * frame.row_bytes +
                                    static_cast<std::size_t>(x) * kPixelBytes);
}

const float* pixel(const std::vector<std::uint8_t>& bytes, const Frame& frame, int x, int y)
{
    return reinterpret_cast<const float*>(bytes.data() + static_cast<std::size_t>(y) * frame.row_bytes +
                                          static_cast<std::size_t>(x) * kPixelBytes);
}

FrameSurface surface(void* data, const Frame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, frame.bounds};
}

RenderRequest request(Frame& frame, double time)
{
    return RenderRequest{EffectId::FilmGrain,
                         surface(frame.source.data(), frame),
                         surface(frame.destination.data(), frame),
                         RectI{0, 0, frame.render_width, frame.render_height},
                         time,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         defaultSettings(EffectId::FilmGrain)};
}

int fail(const char* message)
{
    std::fprintf(stderr, "film_grain_render_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) return fail(message); \
    } while (false)

void fill(Frame& frame, float value = 0.18F)
{
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            float* p = pixel(frame.source, frame, x, y);
            p[0] = value;
            p[1] = value;
            p[2] = value;
            p[3] = 1.0F;
        }
    }
}

int renderOne(Frame& frame, double time, std::vector<float>& values, bool component = false)
{
    CpuRenderBackend backend;
    RenderRequest render_request = request(frame, time);
    setSetting(render_request.settings, "working_mode", 1);
    if (component) setSetting(render_request.settings, "output_view", 1);
    if (render(render_request, backend).kind != SubmissionKind::Completed) return 1;
    values.resize(static_cast<std::size_t>(frame.render_width) * frame.render_height * 3U);
    std::size_t index = 0;
    for (int y = 0; y < frame.render_height; ++y) {
        for (int x = 0; x < frame.render_width; ++x) {
            const float* p = pixel(frame.destination, frame, x, y);
            values[index++] = p[0];
            values[index++] = p[1];
            values[index++] = p[2];
        }
    }
    return 0;
}

std::vector<double> radialSpectrum(const std::vector<float>& values, int width, int height, double canonical_scale)
{
    constexpr int kBins = 9;
    std::vector<double> power(kBins, 0.0);
    std::vector<int> counts(kBins, 0);
    const double pi = std::acos(-1.0);
    for (int ky = 0; ky < height; ++ky) {
        for (int kx = 0; kx <= width / 2; ++kx) {
            if (kx == 0 && ky == 0) continue;
            const double fx = static_cast<double>(kx) / width;
            const double fy = static_cast<double>(ky <= height / 2 ? ky : ky - height) / height;
            const double frequency = std::sqrt(fx * fx + fy * fy) * canonical_scale;
            const int bin = static_cast<int>(std::floor((frequency - 0.05) / 0.05));
            if (bin < 0 || bin >= kBins) continue;
            double real = 0.0;
            double imaginary = 0.0;
            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < width; ++x) {
                    const double value = static_cast<double>(values[(static_cast<std::size_t>(y) * width + x) * 3U]) -
                                         0.18;
                    const double phase = 2.0 * pi * (fx * x + fy * y);
                    real += value * std::cos(phase);
                    imaginary -= value * std::sin(phase);
                }
            }
            power[static_cast<std::size_t>(bin)] += real * real + imaginary * imaginary;
            counts[static_cast<std::size_t>(bin)] += 1;
        }
    }
    for (int bin = 0; bin < kBins; ++bin) {
        if (counts[static_cast<std::size_t>(bin)] > 0) {
            power[static_cast<std::size_t>(bin)] /= counts[static_cast<std::size_t>(bin)];
        }
    }
    const double total_power = std::accumulate(power.begin(), power.end(), 0.0);
    if (total_power > 0.0) {
        for (double& value : power) value /= total_power;
    }
    return power;
}

double canonicalDiameter(const std::vector<double>& spectrum, int /*height*/)
{
    double weighted_frequency = 0.0;
    double total = 0.0;
    for (std::size_t bin = 0; bin < spectrum.size(); ++bin) {
        const double frequency = 0.075 + 0.05 * static_cast<double>(bin);
        weighted_frequency += frequency * spectrum[bin];
        total += spectrum[bin];
    }
    return total > 0.0 ? 1.0 / (weighted_frequency / total) : 0.0;
}

double axisSpectrumEnergy(const std::vector<float>& values, int width, int height, bool horizontal)
{
    const double pi = std::acos(-1.0);
    double total = 0.0;
    const int limit = horizontal ? width / 2 : height / 2;
    for (int frequency = 1; frequency <= limit; ++frequency) {
        double real = 0.0;
        double imaginary = 0.0;
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                const double value = static_cast<double>(values[(static_cast<std::size_t>(y) * width + x) * 3U]) -
                                     0.18;
                const double phase = 2.0 * pi *
                                     (horizontal ? static_cast<double>(frequency * x) / width
                                                 : static_cast<double>(frequency * y) / height);
                real += value * std::cos(phase);
                imaginary -= value * std::sin(phase);
            }
        }
        total += real * real + imaginary * imaginary;
    }
    return total;
}

int testDefinitionAndIdentity()
{
    const EffectDefinition& definition = effectDefinition(EffectId::FilmGrain);
    CHECK(definition.parameters.size() == 19U, "Film Grain definition must contain common, capture, and population parameters");
    CHECK(definition.presets.size() == 6U, "Film Grain must expose six generic capture presets");
    CHECK(settingsUsePreset(defaultSettings(EffectId::FilmGrain)), "default settings must expand the default preset");
    Frame frame(3, 2);
    fill(frame);
    std::array<std::uint32_t, 4> original = {0x7FC01234U, 0x3F400000U, 0xBF800000U, 0x00000000U};
    std::memcpy(pixel(frame.source, frame, 0, 0), original.data(), kPixelBytes);
    RenderRequest render_request = request(frame, 0.0);
    CHECK(setSetting(render_request.settings, "amount", 0.0), "Amount zero must be accepted");
    CpuRenderBackend backend;
    CHECK(render(render_request, backend).kind == SubmissionKind::Completed, "identity render must complete");
    std::array<std::uint32_t, 4> copied{};
    std::memcpy(copied.data(), pixel(frame.destination, frame, 0, 0), kPixelBytes);
    CHECK(copied == original, "Amount zero must preserve source float bits");
    return 0;
}

int testDeterminismAndSubframes()
{
    Frame frame(32, 24);
    fill(frame);
    std::vector<float> first;
    std::vector<float> second;
    std::vector<float> subframe;
    CHECK(renderOne(frame, 7.0, first) == 0, "first grain render must complete");
    CHECK(renderOne(frame, 7.0, second) == 0, "second grain render must complete");
    CHECK(first == second, "same frame and settings must be bit-identical");
    CHECK(renderOne(frame, 7.49, subframe) == 0, "subframe grain render must complete");
    CHECK(first == subframe, "half-away rounded subframe must reuse the same field");
    return 0;
}

int testTemporalAndStatisticalContract()
{
    Frame frame(64, 48);
    fill(frame);
    std::vector<std::vector<float>> frames;
    for (int frame_index = 0; frame_index < 48; ++frame_index) {
        std::vector<float> values;
        CHECK(renderOne(frame, static_cast<double>(frame_index), values) == 0, "statistical frame must complete");
        frames.push_back(std::move(values));
    }
    const std::size_t count = frames.front().size();
    double mean = 0.0;
    double square = 0.0;
    double correlation = 0.0;
    double next_mean = 0.0;
    double next_square = 0.0;
    double previous_mean = 0.0;
    double previous_square = 0.0;
    for (const auto& values : frames) {
        for (float value : values) {
            const double delta = std::log2(std::max(static_cast<double>(value), 1.0e-8) / 0.18);
            mean += delta;
            square += delta * delta;
        }
    }
    mean /= static_cast<double>(count * frames.size());
    square = std::sqrt(square / static_cast<double>(count * frames.size()));
    CHECK(std::abs(mean) < 5.0e-4, "48-frame gray mean must have negligible bias");
    CHECK(square >= 0.95 * 0.0224 && square <= 1.05 * 0.0224,
          "48-frame log-exposure RMS must match the default sigma_stop");
    for (float value : frames[0]) previous_mean += std::log2(std::max(static_cast<double>(value), 1.0e-8) / 0.18);
    previous_mean /= static_cast<double>(count);
    for (float value : frames[0]) {
        const double delta = std::log2(std::max(static_cast<double>(value), 1.0e-8) / 0.18) - previous_mean;
        previous_square += delta * delta;
    }
    for (float value : frames[1]) next_mean += std::log2(std::max(static_cast<double>(value), 1.0e-8) / 0.18);
    next_mean /= static_cast<double>(count);
    for (std::size_t index = 0; index < count; ++index) {
        const double delta = std::log2(std::max(static_cast<double>(frames[1][index]), 1.0e-8) / 0.18) - next_mean;
        next_square += delta * delta;
        correlation += (std::log2(std::max(static_cast<double>(frames[0][index]), 1.0e-8) / 0.18) -
                        previous_mean) * delta;
    }
    CHECK(std::abs(correlation / std::sqrt(previous_square * next_square)) < 0.1,
          "neighbor frame correlation must remain below 0.1");
    return 0;
}

int testResolutionAndChannels()
{
    Frame small(64, 1080, 64, 64);
    Frame large(128, 2160, 128, 128);
    fill(small);
    fill(large);
    std::vector<float> small_values;
    std::vector<float> large_values;
    CHECK(renderOne(small, 4.0, small_values) == 0, "1080 proxy grain render must complete");
    CHECK(renderOne(large, 4.0, large_values) == 0, "4K proxy grain render must complete");
    double small_energy = 0.0;
    double large_energy = 0.0;
    double rgb_dot = 0.0;
    double red_energy = 0.0;
    double green_energy = 0.0;
    for (std::size_t index = 0; index < small_values.size(); ++index) {
        const double delta = static_cast<double>(small_values[index]) - 0.18;
        small_energy += delta * delta;
    }
    for (std::size_t index = 0; index < large_values.size(); ++index) {
        const double delta = static_cast<double>(large_values[index]) - 0.18;
        large_energy += delta * delta;
    }
    for (std::size_t index = 0; index + 2 < small_values.size(); index += 3) {
        const double red = static_cast<double>(small_values[index]) - 0.18;
        const double green = static_cast<double>(small_values[index + 1]) - 0.18;
        rgb_dot += red * green;
        red_energy += red * red;
        green_energy += green * green;
    }
    CHECK(small_energy > 0.0 && large_energy > 0.0, "both resolutions must contain grain energy");
    CHECK(std::abs(rgb_dot / std::sqrt(red_energy * green_energy) - 0.88) <= 0.05,
          "default chroma correlation must match one-minus-q");
    CHECK(std::isfinite(small_energy) && std::isfinite(large_energy), "resolution grain energy must be finite");
    const std::vector<double> small_spectrum =
        radialSpectrum(small_values, small.render_width, small.render_height, 1080.0 / 1080.0);
    const std::vector<double> large_spectrum =
        radialSpectrum(large_values, large.render_width, large.render_height, 2160.0 / 1080.0);
    std::vector<double> spectrum_differences;
    for (std::size_t index = 0; index < small_spectrum.size(); ++index) {
        if (small_spectrum[index] < 1.0e-4 || large_spectrum[index] < 1.0e-4) continue;
        spectrum_differences.push_back(std::abs(10.0 * std::log10(std::max(small_spectrum[index], 1.0e-20)) -
                                                 10.0 * std::log10(std::max(large_spectrum[index], 1.0e-20))));
    }
    std::sort(spectrum_differences.begin(), spectrum_differences.end());
    const double spectrum_median = spectrum_differences.empty()
                                       ? 0.0
                                       : spectrum_differences[spectrum_differences.size() / 2U];
    CHECK(spectrum_median <= 1.5,
          "normalized radial power spectrum must remain within 1.5 dB across resolutions");
    const double small_diameter = canonicalDiameter(small_spectrum, small.bounds.height);
    const double large_diameter = canonicalDiameter(large_spectrum, large.bounds.height);
    CHECK(std::abs(small_diameter / large_diameter - 1.0) <= 0.08,
          "canonical particle diameter must remain within eight percent across resolutions");
    const double horizontal = axisSpectrumEnergy(small_values, small.render_width, small.render_height, true);
    const double vertical = axisSpectrumEnergy(small_values, small.render_width, small.render_height, false);
    CHECK(std::abs(10.0 * std::log10(std::max(horizontal, 1.0e-20) /
                                     std::max(vertical, 1.0e-20))) <= 1.5,
          "horizontal and vertical spectrum energy must remain within 1.5 dB");
    for (std::size_t index = 0; index < small_spectrum.size(); ++index) {
        std::vector<double> local;
        const std::size_t first = index > 2U ? index - 2U : 0U;
        const std::size_t last = std::min(index + 2U, small_spectrum.size() - 1U);
        for (std::size_t neighbor = first; neighbor <= last; ++neighbor) {
            if (neighbor != index) local.push_back(small_spectrum[neighbor]);
        }
        std::sort(local.begin(), local.end());
        const double local_median = local[local.size() / 2U];
        CHECK(10.0 * std::log10(std::max(small_spectrum[index], 1.0e-20) /
                                std::max(local_median, 1.0e-20)) < 6.0,
              "each non-DC spectrum bin must remain below its local radial median spike limit");
    }
    return 0;
}

#if defined(CBEF_ENABLE_METAL_TEST)
int testMetalParityAndContracts()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "a Metal device is required for Film Grain parity");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "a Metal command queue is required for Film Grain parity");

        Frame frame(23, 17);
        fill(frame, 0.18F);
        for (int y = 0; y < frame.bounds.height; ++y) {
            for (int x = 0; x < frame.bounds.width; ++x) {
                float* value = pixel(frame.source, frame, x, y);
                value[0] = 0.03F + 0.01F * static_cast<float>(x % 7);
                value[1] = 0.05F + 0.008F * static_cast<float>(y % 5);
                value[2] = 0.09F + 0.004F * static_cast<float>((x + y) % 11);
                value[3] = 0.35F + 0.02F * static_cast<float>((x + y) % 20);
            }
        }
        float* transparent = pixel(frame.source, frame, 4, 6);
        transparent[0] = 100.0F;
        transparent[1] = -50.0F;
        transparent[2] = 25.0F;
        transparent[3] = 0.0F;

        RenderRequest cpu_request = request(frame, 8.0);
        CHECK(setSetting(cpu_request.settings, "working_mode", 1), "Metal test must select DWG Linear");
        CHECK(setSetting(cpu_request.settings, "amount", 72.0), "Metal test must select non-zero Amount");
        CHECK(setSetting(cpu_request.settings, "size", 135.0), "Metal test must select grain Size");
        CHECK(setSetting(cpu_request.settings, "softness", 32.0), "Metal test must select grain Softness");
        CHECK(setSetting(cpu_request.settings, "chroma", 20.0), "Metal test must select grain Chroma");
        cpu_request.render_window = RectI{3, 2, 20, 15};
        cpu_request.alpha_association = AlphaAssociation::Premultiplied;
        CpuRenderBackend cpu_backend;
        CHECK(render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
              "CPU Film Grain reference must complete");
        const std::vector<std::uint8_t> expected = frame.destination;

        id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination =
            [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "Metal Film Grain buffers must allocate");
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, kDestinationSentinel, frame.destination.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)source,
                                            0U, frame.row_bytes, frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, frame.row_bytes, frame.bounds};
        MetalRenderBackend metal_backend((__bridge void*)queue);
        CHECK(render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "Metal Film Grain must enqueue on the supplied command queue");
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "Metal Film Grain sentinel command buffer must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted,
              "Metal Film Grain sentinel must complete before reading output");

        std::vector<std::uint8_t> actual(frame.destination.size(), 0U);
        std::memcpy(actual.data(), destination.contents, actual.size());
        float maximum_error = 0.0F;
        for (int y = cpu_request.render_window.y1; y < cpu_request.render_window.y2; ++y) {
            for (int x = cpu_request.render_window.x1; x < cpu_request.render_window.x2; ++x) {
                const float* expected_pixel = pixel(expected, frame, x, y);
                const float* actual_pixel = pixel(actual, frame, x, y);
                for (int channel = 0; channel < 3; ++channel) {
                    maximum_error = std::max(maximum_error, std::abs(expected_pixel[channel] - actual_pixel[channel]));
                }
                std::uint32_t expected_alpha = 0U;
                std::uint32_t actual_alpha = 0U;
                std::memcpy(&expected_alpha, &expected_pixel[3], sizeof(expected_alpha));
                std::memcpy(&actual_alpha, &actual_pixel[3], sizeof(actual_alpha));
                CHECK(expected_alpha == actual_alpha, "Metal Film Grain must preserve alpha bits exactly");
            }
        }
        CHECK(maximum_error <= 2.0e-4F, "CPU and Metal Film Grain must agree within 2e-4");
        CHECK(std::abs(pixel(actual, frame, 4, 6)[0]) <= 1.0e-6F &&
                  std::abs(pixel(actual, frame, 4, 6)[1]) <= 1.0e-6F &&
                  std::abs(pixel(actual, frame, 4, 6)[2]) <= 1.0e-6F,
              "Metal Film Grain transparent hidden RGB must remain zero");
        for (int y = 0; y < frame.bounds.height; ++y) {
            const std::size_t row_padding_start = static_cast<std::size_t>(y) * frame.row_bytes +
                                                   static_cast<std::size_t>(frame.bounds.width) * kPixelBytes;
            for (std::size_t byte = row_padding_start; byte < static_cast<std::size_t>(y + 1) * frame.row_bytes;
                 ++byte) {
                CHECK(actual[byte] == kDestinationSentinel,
                      "Metal Film Grain must preserve destination row padding");
            }
        }
        std::array<std::uint8_t, kPixelBytes> sentinel_pixel{};
        sentinel_pixel.fill(kDestinationSentinel);
        for (int y = 0; y < frame.bounds.height; ++y) {
            for (int x = 0; x < frame.bounds.width; ++x) {
                if (x >= cpu_request.render_window.x1 && x < cpu_request.render_window.x2 &&
                    y >= cpu_request.render_window.y1 && y < cpu_request.render_window.y2) {
                    continue;
                }
                CHECK(std::memcmp(pixel(actual, frame, x, y), sentinel_pixel.data(), kPixelBytes) == 0,
                      "Metal Film Grain must preserve pixels outside the render window");
            }
        }

        std::memset(destination.contents, kDestinationSentinel, frame.destination.size());
        CHECK(setSetting(metal_request.settings, "amount", 0.0), "Metal test must select Amount identity");
        CHECK(render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "Metal Film Grain identity must enqueue on the supplied queue");
        sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "Metal Film Grain identity sentinel must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted,
              "Metal Film Grain identity sentinel must complete");
        std::memcpy(actual.data(), destination.contents, actual.size());
        for (int y = cpu_request.render_window.y1; y < cpu_request.render_window.y2; ++y) {
            for (int x = cpu_request.render_window.x1; x < cpu_request.render_window.x2; ++x) {
                const float* source_pixel = pixel(frame.source, frame, x, y);
                const float* actual_pixel = pixel(actual, frame, x, y);
                CHECK(std::memcmp(source_pixel, actual_pixel, kPixelBytes) == 0,
                      "Metal Film Grain identity must preserve every RGBA float bit");
            }
        }
        for (int y = 0; y < frame.bounds.height; ++y) {
            for (int x = 0; x < frame.bounds.width; ++x) {
                if (x >= cpu_request.render_window.x1 && x < cpu_request.render_window.x2 &&
                    y >= cpu_request.render_window.y1 && y < cpu_request.render_window.y2) {
                    continue;
                }
                CHECK(std::memcmp(pixel(actual, frame, x, y), sentinel_pixel.data(), kPixelBytes) == 0,
                      "Metal Film Grain identity must preserve pixels outside the render window");
            }
        }
        [source release];
        [destination release];
        [queue release];
    }
    return 0;
}
#endif

} // namespace

int main()
{
    if (testDefinitionAndIdentity() != 0) return 1;
    if (testDeterminismAndSubframes() != 0) return 1;
    if (testTemporalAndStatisticalContract() != 0) return 1;
    if (testResolutionAndChannels() != 0) return 1;
#if defined(CBEF_ENABLE_METAL_TEST)
    if (testMetalParityAndContracts() != 0) return 1;
#endif
    std::puts("film_grain_render_contract: PASS");
    return 0;
}
