#import <Metal/Metal.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

#include "cbef/RenderCore.h"

namespace {
using namespace cbef;
constexpr std::size_t kPixelBytes = sizeof(float) * 4U;

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    Frame(int width, int height, int x = 0, int y = 0)
        : bounds{x, y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + 16U)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), 0xA5U)
    {
    }
};

float* pixel(std::vector<std::uint8_t>& bytes, const Frame& frame, int x, int y)
{
    return reinterpret_cast<float*>(bytes.data() + static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                    static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes);
}

const float* pixel(const std::vector<std::uint8_t>& bytes, const Frame& frame, int x, int y)
{
    return reinterpret_cast<const float*>(bytes.data() + static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                          static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes);
}

RenderRequest requestFor(Frame& frame)
{
    const FrameSurface source{MemoryKind::Cpu, PixelFormat::RgbaFloat32, frame.source.data(), 0U, frame.row_bytes,
                              frame.bounds};
    const FrameSurface destination{MemoryKind::Cpu, PixelFormat::RgbaFloat32, frame.destination.data(), 0U,
                                   frame.row_bytes, frame.bounds};
    return RenderRequest{EffectId::LensReflections,
                         source,
                         destination,
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height},
                         0.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         defaultSettings(EffectId::LensReflections)};
}

void fill(Frame& frame, float value, float alpha = 1.0F)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* p = pixel(frame.source, frame, x, y);
            p[0] = value;
            p[1] = value;
            p[2] = value;
            p[3] = alpha;
        }
    }
}

void impulse(Frame& frame, int x, int y, float value = 1.0F)
{
    fill(frame, 0.0F);
    float* p = pixel(frame.source, frame, x, y);
    p[0] = value;
    p[1] = value;
    p[2] = value;
}

bool setDouble(Settings& settings, const char* id, double value)
{
    return setSetting(settings, id, value);
}

bool render(Frame& frame, Settings settings)
{
    RenderRequest request = requestFor(frame);
    request.settings = std::move(settings);
    CpuRenderBackend backend;
    return cbef::render(request, backend).kind == SubmissionKind::Completed;
}

#if defined(CBEF_ENABLE_METAL_TEST)
const float* metalPixel(const void* bytes, const Frame& frame, int x, int y)
{
    const auto* base = static_cast<const std::uint8_t*>(bytes);
    return reinterpret_cast<const float*>(base + static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                          static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes);
}
#endif

double luma(const Frame& frame, int x, int y)
{
    const float* p = pixel(frame.destination, frame, x, y);
    return 0.27411851 * std::max(0.0F, p[0]) + 0.87363190 * std::max(0.0F, p[1]) -
           0.14775041 * std::max(0.0F, p[2]);
}

double energy(const Frame& frame)
{
    double result = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            result += luma(frame, x, y);
        }
    }
    return result;
}

int fail(const char* message)
{
    std::fprintf(stderr, "lens_reflections_render_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) return fail(message); \
    } while (false)

int testElementsOnlyHostSettings()
{
    Frame frame(257, 129);
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* source = pixel(frame.source, frame, x, y);
            source[0] = 0.08F + 0.55F * static_cast<float>(x) / static_cast<float>(frame.bounds.width - 1);
            source[1] = 0.05F + 0.42F * static_cast<float>(y) / static_cast<float>(frame.bounds.height - 1);
            source[2] = 0.03F + 0.16F * static_cast<float>((x + 2 * y) % 37) / 36.0F;
            source[3] = 1.0F;
        }
    }

    Settings settings = defaultSettings(EffectId::LensReflections);
    CHECK(setSetting(settings, "working_mode", 2) && setSetting(settings, "output_view", 5) &&
              setSetting(settings, "source_mode", 1) && setDouble(settings, "manual_x", 30.0) &&
              setDouble(settings, "manual_y", -20.0) && setDouble(settings, "manual_size", 4.0) &&
              setDouble(settings, "manual_intensity", 200.0) && setDouble(settings, "amount", 100.0) &&
              setDouble(settings, "spread", 120.0) && render(frame, settings),
          "Resolve host Elements Only settings must render through the public seam");

    std::size_t source_like_pixels = 0U;
    std::size_t non_black_pixels = 0U;
    double source_distance = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float* source = pixel(frame.source, frame, x, y);
            const float* output = pixel(frame.destination, frame, x, y);
            const double distance = std::abs(static_cast<double>(output[0]) - source[0]) +
                                    std::abs(static_cast<double>(output[1]) - source[1]) +
                                    std::abs(static_cast<double>(output[2]) - source[2]);
            source_distance += distance;
            source_like_pixels += distance < 1.0e-3 ? 1U : 0U;
            non_black_pixels += std::max({std::abs(output[0]), std::abs(output[1]), std::abs(output[2])}) > 1.0e-4F
                                    ? 1U
                                    : 0U;
        }
    }
    const std::size_t pixel_count = static_cast<std::size_t>(frame.bounds.width) *
                                    static_cast<std::size_t>(frame.bounds.height);
    CHECK(source_distance / static_cast<double>(pixel_count) > 0.10,
          "Elements Only must not preserve the full source image");
    CHECK(source_like_pixels * 20U < pixel_count,
          "Elements Only must place optical elements over a black diagnostic background");
    CHECK(non_black_pixels > 0U, "Elements Only must retain the generated optical elements");
    return 0;
}

int testDefinitionAndIdentity()
{
    const EffectDefinition& definition = effectDefinition(EffectId::LensReflections);
    CHECK(definition.parameters.size() == 26U,
          "Lens Reflections must expose the stable v1 controls plus deterministic source-map controls");
    CHECK(definition.presets.size() == 3U, "Lens Reflections must expose three presets");
    CHECK(settingsUsePreset(defaultSettings(EffectId::LensReflections)), "default settings must match Clean Prime");
    Settings vintage = settingsForPreset(EffectId::LensReflections, 1U);
    CHECK(settingChoice(vintage, "lens_model") == 1 && std::get<double>(settingValue(vintage, "amount")) == 35.0,
          "Vintage Prime must expand model and amount");

    Frame frame(3, 2, 4, -2);
    fill(frame, 0.2F);
    const std::array<std::uint32_t, 4> original = {0x7FC01234U, 0xBF800000U, 0x3F400000U, 0x3F000000U};
    std::memcpy(pixel(frame.source, frame, 4, -2), original.data(), kPixelBytes);
    Settings identity = defaultSettings(EffectId::LensReflections);
    CHECK(setDouble(identity, "mix", 0.0) && render(frame, identity), "Mix zero identity must render");
    std::array<std::uint32_t, 4> copied{};
    std::memcpy(copied.data(), pixel(frame.destination, frame, 4, -2), kPixelBytes);
    CHECK(copied == original, "Mix zero must preserve exact source bits");
    return 0;
}

int testThresholdAndCentroid()
{
    Frame matte(9, 1);
    fill(matte, static_cast<float>(0.18 * std::exp2(1.5)));
    Settings matte_settings = defaultSettings(EffectId::LensReflections);
    CHECK(setSetting(matte_settings, "working_mode", 1) && setDouble(matte_settings, "threshold", 2.5) &&
              setDouble(matte_settings, "amount", 100.0) && setSetting(matte_settings, "output_view", 2) &&
              render(matte, matte_settings),
          "threshold matte render must complete");
    CHECK(pixel(matte.destination, matte, 4, 0)[0] <= 1.0e-6F, "one stop below threshold must be matte zero");

    Frame frame(257, 129);
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    impulse(frame, center_x + 52, center_y);
    Settings settings = defaultSettings(EffectId::LensReflections);
    CHECK(setSetting(settings, "working_mode", 1) && setDouble(settings, "threshold", -2.0) &&
              setDouble(settings, "amount", 100.0) && setDouble(settings, "spread", 65.0) &&
              setDouble(settings, "blur", 0.0) && setDouble(settings, "chroma", 0.0) &&
              setSetting(settings, "output_view", 1) && render(frame, settings),
          "centroid component render must complete");
    double weighted_x = 0.0;
    double weighted = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const double value = luma(frame, x, y);
            weighted += value;
            weighted_x += static_cast<double>(x) * value;
        }
    }
    const double expected = static_cast<double>(center_x) -
                            0.65 * (static_cast<double>(center_x + 52) - static_cast<double>(center_x)) * 0.330;
    CHECK(std::abs(weighted_x / weighted - expected) <= 0.25, "ghost centroid must follow the center-axis affine mapping");
    return 0;
}

int testThresholdPopping()
{
    Frame low(33, 17);
    Frame high(33, 17);
    const int center_x = low.bounds.x + low.bounds.width / 2;
    const int center_y = low.bounds.y + low.bounds.height / 2;
    const float threshold = static_cast<float>(0.18 * std::exp2(2.5));
    impulse(low, center_x, center_y, threshold * std::exp2(-0.01));
    impulse(high, center_x, center_y, threshold * std::exp2(0.01));
    Settings low_settings = defaultSettings(EffectId::LensReflections);
    Settings high_settings = low_settings;
    CHECK(setSetting(low_settings, "working_mode", 1) && setSetting(high_settings, "working_mode", 1) &&
              setDouble(low_settings, "threshold", 2.5) && setDouble(high_settings, "threshold", 2.5) &&
              setDouble(low_settings, "amount", 100.0) && setDouble(high_settings, "amount", 100.0) &&
              setDouble(low_settings, "blur", 0.0) && setDouble(high_settings, "blur", 0.0) &&
              setSetting(low_settings, "output_view", 1) && setSetting(high_settings, "output_view", 1) &&
              render(low, low_settings) && render(high, high_settings),
          "threshold continuity renders must complete");
    const double input_delta = static_cast<double>(threshold * (std::exp2(0.01) - std::exp2(-0.01)));
    CHECK(energy(high) - energy(low) <= input_delta * 1.25 + 1.0e-6,
          "one-stop source knee must avoid threshold popping");
    return 0;
}

int testModelEnergyAndAmount()
{
    for (int model = 0; model < 3; ++model) {
        Frame frame(257, 129);
        impulse(frame, 220, 64);
        Settings settings = defaultSettings(EffectId::LensReflections);
        CHECK(setSetting(settings, "working_mode", 1) && setSetting(settings, "lens_model", model) &&
                  setDouble(settings, "threshold", -2.0) && setDouble(settings, "amount", 100.0) &&
                  setDouble(settings, "spread", 65.0) && setDouble(settings, "blur", 0.0) &&
                  setDouble(settings, "chroma", 0.0) && setSetting(settings, "output_view", 1) &&
                  render(frame, settings),
              "model energy render must complete");
        const double total = energy(frame);
        CHECK(std::abs(total - 1.0) <= 0.03, "model ghost energies must sum to the defined unit ratio");
    }

    Frame low(129, 65);
    Frame high(129, 65);
    impulse(low, 100, 32);
    impulse(high, 100, 32);
    Settings low_settings = defaultSettings(EffectId::LensReflections);
    Settings high_settings = low_settings;
    CHECK(setSetting(low_settings, "working_mode", 1) && setSetting(high_settings, "working_mode", 1) &&
              setDouble(low_settings, "threshold", -2.0) && setDouble(high_settings, "threshold", -2.0) &&
              setDouble(low_settings, "amount", 25.0) && setDouble(high_settings, "amount", 100.0) &&
              setDouble(low_settings, "blur", 0.0) && setDouble(high_settings, "blur", 0.0) &&
              setSetting(low_settings, "output_view", 1) && setSetting(high_settings, "output_view", 1) &&
              render(low, low_settings) && render(high, high_settings),
          "amount renders must complete");
    CHECK(energy(high) >= energy(low), "reflection energy must be monotonic with Amount");
    return 0;
}

int testOffscreenAlphaHdrAndResolution()
{
    Frame frame(129, 65);
    impulse(frame, frame.bounds.x, 32);
    Settings settings = defaultSettings(EffectId::LensReflections);
    CHECK(setSetting(settings, "working_mode", 1) && setDouble(settings, "threshold", -2.0) &&
              setDouble(settings, "spread", 200.0) && setDouble(settings, "blur", 0.0) &&
              setDouble(settings, "amount", 100.0) && setSetting(settings, "output_view", 1) && render(frame, settings),
          "offscreen render must complete");
    CHECK(luma(frame, frame.bounds.x + frame.bounds.width - 1, 32) <= 1.0e-6,
          "offscreen ghosts must not wrap to the opposite edge");

    Frame alpha(5, 1);
    fill(alpha, 100.0F, 0.0F);
    float* transparent = pixel(alpha.source, alpha, 2, 0);
    transparent[3] = 0.0F;
    Settings alpha_settings = defaultSettings(EffectId::LensReflections);
    CHECK(setSetting(alpha_settings, "working_mode", 1) && setDouble(alpha_settings, "threshold", -2.0) &&
              setDouble(alpha_settings, "amount", 100.0) && render(alpha, alpha_settings),
          "transparent HDR render must complete");
    CHECK(std::abs(pixel(alpha.destination, alpha, 2, 0)[0]) <= 1.0e-6F &&
              std::isfinite(pixel(alpha.destination, alpha, 2, 0)[0]),
          "transparent hidden HDR RGB must be suppressed");

    Frame low(1920, 1080);
    Frame high(3840, 2160);
    impulse(low, 960, 540);
    impulse(high, 1920, 1080);
    Settings low_settings = defaultSettings(EffectId::LensReflections);
    Settings high_settings = low_settings;
    CHECK(setSetting(low_settings, "working_mode", 1) && setSetting(high_settings, "working_mode", 1) &&
              setDouble(low_settings, "threshold", -2.0) && setDouble(high_settings, "threshold", -2.0) &&
              setDouble(low_settings, "blur", 0.0) && setDouble(high_settings, "blur", 0.0) &&
              setSetting(low_settings, "output_view", 1) && setSetting(high_settings, "output_view", 1) &&
              render(low, low_settings) && render(high, high_settings),
          "resolution renders must complete");
    CHECK(std::abs(energy(low) - energy(high)) / std::max(energy(low), 1.0e-9) <= 0.03,
          "scaled reflection energy must remain resolution stable");
    return 0;
}

#if defined(CBEF_ENABLE_METAL_TEST)
int testMetalParityAndCrop()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "a Metal device is required for Lens Reflections parity");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "a Metal command queue is required for Lens Reflections parity");

        Frame frame(37, 29, -5, 7);
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                float* value = pixel(frame.source, frame, x, y);
                value[0] = static_cast<float>(0.12 + 0.004 * (x - frame.bounds.x));
                value[1] = static_cast<float>(0.16 + 0.003 * (y - frame.bounds.y));
                value[2] = static_cast<float>(0.10 + 0.002 * (x + y));
                value[3] = 0.75F;
            }
        }
        float* highlight = pixel(frame.source, frame, frame.bounds.x + 26, frame.bounds.y + 14);
        highlight[0] = 4.0F;
        highlight[1] = 2.5F;
        highlight[2] = 1.0F;
        float* hidden = pixel(frame.source, frame, frame.bounds.x + 2, frame.bounds.y + 2);
        hidden[0] = 100.0F;
        hidden[1] = 50.0F;
        hidden[2] = 25.0F;
        hidden[3] = 0.0F;

        RenderRequest cpu_request = requestFor(frame);
        cpu_request.render_window = RectI{frame.bounds.x + 3, frame.bounds.y + 4,
                                          frame.bounds.x + frame.bounds.width - 2,
                                          frame.bounds.y + frame.bounds.height - 3};
        cpu_request.alpha_association = AlphaAssociation::Premultiplied;
        CHECK(setSetting(cpu_request.settings, "working_mode", 1) &&
                  setSetting(cpu_request.settings, "lens_model", 1) &&
                  setDouble(cpu_request.settings, "threshold", -1.0) &&
                  setDouble(cpu_request.settings, "amount", 73.0) &&
                  setDouble(cpu_request.settings, "spread", 83.0) &&
                  setDouble(cpu_request.settings, "blur", 0.8) &&
                  setDouble(cpu_request.settings, "chroma", 37.0) &&
                  setDouble(cpu_request.settings, "anamorphism", 1.4),
              "Lens Reflections parity settings must be accepted");
        CpuRenderBackend cpu_backend;
        CHECK(cbef::render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
              "CPU Lens Reflections reference must complete");

        const NSUInteger length = static_cast<NSUInteger>(frame.source.size());
        id<MTLBuffer> source = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "Metal Lens Reflections buffers must allocate");
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, 0xA5, frame.destination.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)source,
                                            0U, frame.row_bytes, frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, frame.row_bytes, frame.bounds};
        MetalRenderBackend metal_backend((__bridge void*)queue);
        CHECK(cbef::render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "Metal Lens Reflections must submit to the host queue");
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "same-queue sentinel must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted, "same-queue sentinel must complete");

        float maximum_error = 0.0F;
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                const bool in_window = x >= cpu_request.render_window.x1 && x < cpu_request.render_window.x2 &&
                                       y >= cpu_request.render_window.y1 && y < cpu_request.render_window.y2;
                if (in_window) {
                    const float* expected = pixel(frame.destination, frame, x, y);
                    const float* actual = metalPixel(destination.contents, frame, x, y);
                    for (int channel = 0; channel < 3; ++channel) {
                        maximum_error = std::max(maximum_error, std::abs(expected[channel] - actual[channel]));
                    }
                    CHECK(std::memcmp(&expected[3], &actual[3], sizeof(float)) == 0,
                          "Lens Reflections Metal must preserve alpha bits");
                } else {
                    const auto* row = static_cast<const std::uint8_t*>(destination.contents) +
                                      static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes;
                    CHECK(row[static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes] == 0xA5U,
                          "Lens Reflections must preserve destination bytes outside the crop");
                }
            }
        }
        CHECK(maximum_error <= 2.0e-4F, "CPU and Metal Lens Reflections must agree within 2e-4");
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
    if (testElementsOnlyHostSettings() != 0 || testDefinitionAndIdentity() != 0 ||
        testThresholdAndCentroid() != 0 || testThresholdPopping() != 0 ||
        testModelEnergyAndAmount() != 0 || testOffscreenAlphaHdrAndResolution() != 0) {
        return 1;
    }
#if defined(CBEF_ENABLE_METAL_TEST)
    if (testMetalParityAndCrop() != 0) return 1;
    std::puts("lens_reflections_render_contract: PASS (CPU + Metal M6 Lens Reflections)");
#else
    std::puts("lens_reflections_render_contract: PASS (CPU M6 Lens Reflections)");
#endif
    return 0;
}
