#import <Metal/Metal.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <limits>
#include <vector>

#include "cbef/RenderCore.h"

namespace {

using namespace cbef;
using cbef::MetalRenderBackend;
constexpr std::size_t kPixelBytes = sizeof(float) * 4U;
constexpr std::uint8_t kSentinel = 0xA5U;

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    Frame(int width, int height, int x = 0, int y = 0, std::size_t padding = 16U)
        : bounds{x, y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + padding)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), kSentinel)
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
    return reinterpret_cast<const float*>(bytes.data() +
                                          static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                          static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes);
}

FrameSurface surface(void* data, const Frame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, frame.bounds};
}

RenderRequest requestFor(Frame& frame)
{
    return RenderRequest{EffectId::MistDiffusion,
                         surface(frame.source.data(), frame),
                         surface(frame.destination.data(), frame),
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height},
                         0.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         defaultSettings(EffectId::MistDiffusion)};
}

int fail(const char* message)
{
    std::fprintf(stderr, "mist_render_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) return fail(message); \
    } while (false)

void fill(Frame& frame, float value, float alpha = 1.0F)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* output = pixel(frame.source, frame, x, y);
            output[0] = value;
            output[1] = value;
            output[2] = value;
            output[3] = alpha;
        }
    }
}

void fillImpulse(Frame& frame)
{
    fill(frame, 0.0F);
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    float* center = pixel(frame.source, frame, center_x, center_y);
    center[0] = 1.0F;
    center[1] = 1.0F;
    center[2] = 1.0F;
}

bool linear(Settings& settings)
{
    return setSetting(settings, "working_mode", 1);
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

double luminanceAt(const Frame& frame, int x, int y)
{
    const float* value = pixel(frame.destination, frame, x, y);
    return std::max(0.0, 0.27411851 * std::max(0.0F, value[0]) + 0.87363190 * std::max(0.0F, value[1]) -
                              0.14775041 * std::max(0.0F, value[2]));
}

double componentEnergy(const Frame& frame)
{
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    double energy = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            if (std::abs(x - center_x) <= 1 && std::abs(y - center_y) <= 1) continue;
            energy += luminanceAt(frame, x, y);
        }
    }
    return energy;
}

double halfRadius(const Frame& frame)
{
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    double peak = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            if (std::abs(x - center_x) <= 1 && std::abs(y - center_y) <= 1) continue;
            peak = std::max(peak, luminanceAt(frame, x, y));
        }
    }
    const double threshold = peak * 0.5;
    double previous = luminanceAt(frame, center_x + 2, center_y);
    for (int x = center_x + 3; x < frame.bounds.x + frame.bounds.width; ++x) {
        const double current = luminanceAt(frame, x, center_y);
        if (current < threshold && previous >= threshold) {
            const double fraction = (threshold - current) / std::max(previous - current, 1.0e-12);
            return static_cast<double>(x - center_x) - fraction;
        }
        previous = current;
    }
    return static_cast<double>(frame.bounds.width / 2);
}

int testDefinitionAndIdentity()
{
    const EffectDefinition& definition = effectDefinition(EffectId::MistDiffusion);
    CHECK(definition.parameters.size() == 10U, "Mist definition must contain four common and six effect parameters");
    CHECK(definition.presets.size() == 10U, "Mist must expose all ten Black and White Grade presets");
    CHECK(settingsUsePreset(defaultSettings(EffectId::MistDiffusion)), "default settings must match the default preset");
    Settings white = settingsForPreset(EffectId::MistDiffusion, 9U);
    CHECK(settingChoice(white, "mode") == 1 && settingChoice(white, "density") == 4,
          "White 1 preset expansion must select White mode and density 1");
    Frame frame(3, 2, 4, -2);
    fill(frame, 0.2F);
    const std::array<std::uint32_t, 4> original = {0x7FC01234U, 0xBF800000U, 0x3F400000U, 0x00000000U};
    std::memcpy(pixel(frame.source, frame, 4, -2), original.data(), kPixelBytes);
    Settings identity = defaultSettings(EffectId::MistDiffusion);
    CHECK(setDouble(identity, "mix", 0.0), "Mix zero must be accepted");
    CHECK(render(frame, identity), "Mist identity render must complete");
    std::array<std::uint32_t, 4> copied{};
    std::memcpy(copied.data(), pixel(frame.destination, frame, 4, -2), kPixelBytes);
    CHECK(copied == original, "Mist identity must preserve every source bit including hidden RGB");
    return 0;
}

int testDensityAndWhiteRadius()
{
    std::array<double, 5> energy{};
    for (int density = 0; density < 5; ++density) {
        Frame frame(129, 129);
        fillImpulse(frame);
        Settings settings = defaultSettings(EffectId::MistDiffusion);
        CHECK(linear(settings), "linear working mode must be accepted");
        CHECK(setSetting(settings, "density", density), "density choice must be accepted");
        CHECK(setDouble(settings, "diffusion", 50.0) && setDouble(settings, "bloom", 0.0) &&
                  setDouble(settings, "contrast", 0.0) && setDouble(settings, "texture", 0.0) &&
                  setSetting(settings, "output_view", 1),
              "density fixture settings must be accepted");
        CHECK(render(frame, settings), "density component render must complete");
        energy[static_cast<std::size_t>(density)] = componentEnergy(frame);
    }
    CHECK(energy[0] < energy[1] && energy[1] < energy[2] && energy[2] < energy[3] && energy[3] < energy[4],
          "Black density must increase diffusion component energy monotonically");

    Frame black(513, 513);
    Frame white(513, 513);
    fillImpulse(black);
    fillImpulse(white);
    Settings black_settings = defaultSettings(EffectId::MistDiffusion);
    Settings white_settings = defaultSettings(EffectId::MistDiffusion);
    CHECK(linear(black_settings) && linear(white_settings), "linear working mode must be accepted");
    CHECK(setSetting(black_settings, "density", 1) && setSetting(white_settings, "density", 1) &&
              setDouble(black_settings, "diffusion", 50.0) && setDouble(white_settings, "diffusion", 50.0) &&
              setDouble(black_settings, "bloom", 0.0) && setDouble(white_settings, "bloom", 0.0) &&
              setDouble(black_settings, "contrast", 0.0) && setDouble(white_settings, "contrast", 0.0) &&
              setDouble(black_settings, "texture", 0.0) && setDouble(white_settings, "texture", 0.0) &&
              setSetting(black_settings, "output_view", 1) && setSetting(white_settings, "output_view", 1) &&
              setSetting(white_settings, "mode", 1),
          "White and Black radius fixture settings must be accepted");
    CHECK(render(black, black_settings) && render(white, white_settings), "radius component renders must complete");
    const double black_radius = halfRadius(black);
    const double white_radius = halfRadius(white);
    CHECK(white_radius / black_radius >= 1.20, "White diffusion radius must be at least 1.20x Black");
    return 0;
}

int testShadowMtfAlphaHdrAndEdges()
{
    Frame black(129, 65);
    Frame white(129, 65);
    fill(black, 0.05F);
    fill(white, 0.05F);
    CHECK(render(black, defaultSettings(EffectId::MistDiffusion)) &&
              render(white, settingsForPreset(EffectId::MistDiffusion, 5U)),
          "default Black and White renders must complete");
    const double black_lift = luminanceAt(black, 64, 32) - 0.05;
    const double white_lift = luminanceAt(white, 64, 32) - 0.05;
    CHECK(white_lift > 0.0 && black_lift <= white_lift * 0.60, "Black shadow lift must be at most 60% of White");

    Frame frame(9, 3, 4, -2, 32U);
    fill(frame, -0.25F);
    float* hdr = pixel(frame.source, frame, 8, -1);
    hdr[0] = 2.5F;
    hdr[1] = 1.5F;
    hdr[2] = -0.25F;
    hdr[3] = 1.0F;
    float* transparent = pixel(frame.source, frame, 10, 0);
    transparent[0] = 100.0F;
    transparent[1] = 50.0F;
    transparent[2] = 25.0F;
    transparent[3] = 0.0F;
    Settings settings = defaultSettings(EffectId::MistDiffusion);
    CHECK(linear(settings) && setDouble(settings, "diffusion", 50.0) && setDouble(settings, "bloom", 20.0) &&
              setDouble(settings, "contrast", 20.0),
          "HDR fixture settings must be accepted");
    RenderRequest request = requestFor(frame);
    request.settings = settings;
    request.render_window = RectI{5, -1, 12, 1};
    CpuRenderBackend backend;
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed, "HDR render must complete");
    CHECK(std::isfinite(pixel(frame.destination, frame, 8, -1)[2]) && pixel(frame.destination, frame, 8, -1)[2] < -0.20F,
          "HDR signed negative residual must survive Mist");
    CHECK(std::abs(pixel(frame.destination, frame, 10, 0)[0]) <= 1.0e-6F,
          "transparent hidden RGB must not leak through Mist");
    CHECK(frame.destination.front() == kSentinel, "bytes outside the render window must be preserved");
    return 0;
}

double mtf(const Frame& frame, double frequency)
{
    const int width = frame.bounds.width;
    const int height = frame.bounds.height;
    double cosine = 0.0;
    double sine = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + width; ++x) {
            const double phase = 2.0 * std::acos(-1.0) * frequency * static_cast<double>(x - frame.bounds.x);
            const double value = luminanceAt(frame, x, y) - 0.18;
            cosine += value * std::cos(phase);
            sine += value * std::sin(phase);
        }
    }
    return 2.0 * std::sqrt(cosine * cosine + sine * sine) / static_cast<double>(width * height) / 0.08;
}

void fillSine(Frame& frame, double frequency)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const double phase = 2.0 * std::acos(-1.0) * frequency * static_cast<double>(x - frame.bounds.x);
            float* output = pixel(frame.source, frame, x, y);
            const float value = static_cast<float>(0.18 + 0.08 * std::cos(phase));
            output[0] = value;
            output[1] = value;
            output[2] = value;
            output[3] = 1.0F;
        }
    }
}

double scaledEnergy(const Frame& frame)
{
    return componentEnergy(frame);
}

std::vector<float> downsample2(const Frame& frame)
{
    const int width = frame.bounds.width / 2;
    const int height = frame.bounds.height / 2;
    std::vector<float> result(static_cast<std::size_t>(width) * static_cast<std::size_t>(height), 0.0F);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            float sum = 0.0F;
            for (int dy = 0; dy < 2; ++dy) {
                for (int dx = 0; dx < 2; ++dx) {
                    sum += static_cast<float>(luminanceAt(frame, 2 * x + dx, 2 * y + dy));
                }
            }
            result[static_cast<std::size_t>(y * width + x)] = sum * 0.25F;
        }
    }
    return result;
}

int testMtfTextureAndResolution()
{
    constexpr double frequency = 0.25;
    Frame black(128, 64);
    Frame white(128, 64);
    fillSine(black, frequency);
    fillSine(white, frequency);
    Settings black_settings = defaultSettings(EffectId::MistDiffusion);
    Settings white_settings = settingsForPreset(EffectId::MistDiffusion, 5U);
    CHECK(linear(black_settings) && linear(white_settings), "MTF working mode must be accepted");
    CHECK(render(black, black_settings) && render(white, white_settings), "MTF renders must complete");
    CHECK(mtf(black, frequency) >= 0.80 && mtf(white, frequency) >= 0.65,
          "Black and White default MTF must meet the preservation floor");

    std::array<double, 3> texture_mtf{};
    for (int index = 0; index < 3; ++index) {
        Frame frame(128, 64);
        fillSine(frame, frequency);
        Settings settings = defaultSettings(EffectId::MistDiffusion);
        CHECK(linear(settings) && setDouble(settings, "texture", static_cast<double>(index * 50)),
              "Texture fixture settings must be accepted");
        CHECK(render(frame, settings), "Texture render must complete");
        texture_mtf[static_cast<std::size_t>(index)] = mtf(frame, frequency);
    }
    CHECK(texture_mtf[0] <= texture_mtf[1] + 1.0e-5 && texture_mtf[1] <= texture_mtf[2] + 1.0e-5,
          "increasing Texture must not reduce MTF");

    Frame low(512, 288);
    Frame high(1024, 576);
    fillImpulse(low);
    fillImpulse(high);
    Settings low_settings = defaultSettings(EffectId::MistDiffusion);
    Settings high_settings = low_settings;
    CHECK(linear(low_settings) && linear(high_settings) && setSetting(low_settings, "density", 3) &&
              setSetting(high_settings, "density", 3) && setDouble(low_settings, "diffusion", 100.0) &&
              setDouble(high_settings, "diffusion", 100.0) && setDouble(low_settings, "bloom", 0.0) &&
              setDouble(high_settings, "bloom", 0.0) && setDouble(low_settings, "contrast", 0.0) &&
              setDouble(high_settings, "contrast", 0.0) && setDouble(low_settings, "texture", 100.0) &&
              setDouble(high_settings, "texture", 100.0) && setSetting(low_settings, "output_view", 1) &&
              setSetting(high_settings, "output_view", 1),
          "resolution fixture settings must be accepted");
    CHECK(render(low, low_settings) && render(high, high_settings), "resolution renders must complete");
    const double low_radius = halfRadius(low) / low.bounds.height;
    const double high_radius = halfRadius(high) / high.bounds.height;
    CHECK(std::abs(low_radius - high_radius) <= 0.001, "Mist radius must remain stable across output resolutions");
    CHECK(std::abs(scaledEnergy(low) - scaledEnergy(high)) / scaledEnergy(low) <= 0.03,
          "Mist low-frequency energy must remain within three percent across resolutions");
    const std::vector<float> downsampled = downsample2(high);
    double squared_error = 0.0;
    for (std::size_t index = 0; index < downsampled.size(); ++index) {
        const int x = static_cast<int>(index % static_cast<std::size_t>(low.bounds.width));
        const int y = static_cast<int>(index / static_cast<std::size_t>(low.bounds.width));
        const double difference = static_cast<double>(downsampled[index]) - luminanceAt(low, x, y);
        squared_error += difference * difference;
    }
    const double mse = squared_error / static_cast<double>(downsampled.size());
    CHECK(mse > 0.0 && 10.0 * std::log10(1.0 / mse) >= 45.0, "1080/4K scaled Mist PSNR must exceed 45 dB");
    return 0;
}

int testDiagnosticViews()
{
    Frame matte(5, 1);
    fill(matte, 0.18F);
    pixel(matte.source, matte, 3, 0)[0] = 0.18F * 8.0F;
    pixel(matte.source, matte, 3, 0)[1] = 0.18F * 8.0F;
    pixel(matte.source, matte, 3, 0)[2] = 0.18F * 8.0F;
    Settings matte_settings = defaultSettings(EffectId::MistDiffusion);
    CHECK(linear(matte_settings) && setSetting(matte_settings, "output_view", 2),
          "Highlight Matte view must be selectable");
    CHECK(render(matte, matte_settings), "Highlight Matte render must complete");
    CHECK(std::abs(pixel(matte.destination, matte, 0, 0)[0]) <= 1.0e-6F &&
              pixel(matte.destination, matte, 3, 0)[0] > 0.9F,
          "Highlight Matte must be the defined smoothstep response");

    Frame component_a(33, 17);
    Frame component_b(33, 17);
    fillImpulse(component_a);
    component_b.source = component_a.source;
    Settings component_settings = defaultSettings(EffectId::MistDiffusion);
    CHECK(linear(component_settings) && setSetting(component_settings, "output_view", 1) &&
              setDouble(component_settings, "mix", 0.0),
          "Diffusion Component settings must be accepted");
    CHECK(render(component_a, component_settings), "pre-Mix component render must complete");
    CHECK(setDouble(component_settings, "mix", 100.0), "Mix override must be accepted");
    CHECK(render(component_b, component_settings), "full-Mix component render must complete");
    for (int y = 0; y < component_a.bounds.height; ++y) {
        for (int x = 0; x < component_a.bounds.width; ++x) {
            CHECK(std::memcmp(pixel(component_a.destination, component_a, x, y),
                              pixel(component_b.destination, component_b, x, y), kPixelBytes) == 0,
                  "Diffusion Component must ignore common Mix");
        }
    }
    return 0;
}

#if defined(CBEF_ENABLE_METAL_TEST)
int testMetalParityAndContracts()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "a Metal device is required for Mist parity");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "a Metal command queue is required for Mist parity");
        Frame frame(37, 23, -5, 7, 32U);
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                float* value = pixel(frame.source, frame, x, y);
                value[0] = 0.02F + 0.004F * static_cast<float>((x - frame.bounds.x) % 9);
                value[1] = 0.03F + 0.003F * static_cast<float>((y - frame.bounds.y) % 7);
                value[2] = 0.04F + 0.002F * static_cast<float>((x + y) % 11);
                value[3] = 0.35F + 0.01F * static_cast<float>((x + y) % 20);
            }
        }
        float* highlight = pixel(frame.source, frame, 14, 18);
        highlight[0] = 2.5F;
        highlight[1] = 1.6F;
        highlight[2] = 0.7F;
        float* transparent = pixel(frame.source, frame, 3, 11);
        transparent[0] = 100.0F;
        transparent[1] = -50.0F;
        transparent[2] = 25.0F;
        transparent[3] = 0.0F;

        RenderRequest cpu_request = requestFor(frame);
        CHECK(linear(cpu_request.settings), "Metal Mist test must select DWG Linear");
        CHECK(setSetting(cpu_request.settings, "mode", 1) && setSetting(cpu_request.settings, "density", 2) &&
                  setDouble(cpu_request.settings, "diffusion", 62.0) &&
                  setDouble(cpu_request.settings, "bloom", 48.0) &&
                  setDouble(cpu_request.settings, "contrast", 32.0) &&
                  setDouble(cpu_request.settings, "texture", 41.0),
              "Metal Mist settings must be accepted");
        cpu_request.render_window = RectI{-1, 10, 29, 26};
        cpu_request.alpha_association = AlphaAssociation::Premultiplied;
        CpuRenderBackend cpu_backend;
        CHECK(cbef::render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
              "CPU Mist reference must complete");
        const std::vector<std::uint8_t> expected = frame.destination;

        id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size()
                                                          options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "Metal Mist buffers must allocate");
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, kSentinel, frame.destination.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)source,
                                            0U, frame.row_bytes, frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, frame.row_bytes, frame.bounds};
        MetalRenderBackend metal_backend((__bridge void*)queue);
        CHECK(cbef::render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "Metal Mist must enqueue on the supplied command queue");
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "Metal Mist sentinel command buffer must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted,
              "Metal Mist sentinel must complete before reading output");

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
                CHECK(expected_alpha == actual_alpha, "Metal Mist must preserve alpha bits exactly");
            }
        }
        CHECK(maximum_error <= 2.0e-4F, "CPU and Metal Mist must agree within 2e-4");
        CHECK(std::abs(pixel(actual, frame, 3, 11)[0]) <= 1.0e-6F &&
                  std::abs(pixel(actual, frame, 3, 11)[1]) <= 1.0e-6F &&
                  std::abs(pixel(actual, frame, 3, 11)[2]) <= 1.0e-6F,
              "Metal Mist transparent hidden RGB must remain zero");
        for (int y = 0; y < frame.bounds.height; ++y) {
            const std::size_t row_padding_start = static_cast<std::size_t>(y) * frame.row_bytes +
                                                   static_cast<std::size_t>(frame.bounds.width) * kPixelBytes;
            for (std::size_t byte = row_padding_start; byte < static_cast<std::size_t>(y + 1) * frame.row_bytes;
                 ++byte) {
                CHECK(actual[byte] == kSentinel, "Metal Mist must preserve destination row padding");
            }
        }
        std::array<std::uint8_t, kPixelBytes> sentinel_pixel{};
        sentinel_pixel.fill(kSentinel);
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                if (x >= cpu_request.render_window.x1 && x < cpu_request.render_window.x2 &&
                    y >= cpu_request.render_window.y1 && y < cpu_request.render_window.y2) {
                    continue;
                }
                CHECK(std::memcmp(pixel(actual, frame, x, y), sentinel_pixel.data(), kPixelBytes) == 0,
                      "Metal Mist must preserve pixels outside the render window");
            }
        }

        std::memset(destination.contents, kSentinel, frame.destination.size());
        CHECK(setDouble(metal_request.settings, "mix", 0.0), "Metal Mist identity settings must be accepted");
        CHECK(cbef::render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "Metal Mist identity must enqueue on the supplied queue");
        sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "Metal Mist identity sentinel must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted,
              "Metal Mist identity sentinel must complete");
        std::memcpy(actual.data(), destination.contents, actual.size());
        for (int y = cpu_request.render_window.y1; y < cpu_request.render_window.y2; ++y) {
            for (int x = cpu_request.render_window.x1; x < cpu_request.render_window.x2; ++x) {
                CHECK(std::memcmp(pixel(frame.source, frame, x, y), pixel(actual, frame, x, y), kPixelBytes) == 0,
                      "Metal Mist identity must preserve every RGBA float bit");
            }
        }
        [source release];
        [destination release];
        [queue release];
    }
    return 0;
}

int testMetalAlignedFastPathParity()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "a Metal device is required for aligned Mist parity");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "a Metal command queue is required for aligned Mist parity");
        Frame frame(16, 16, -2, 4, 32U);
        fill(frame, 0.03F, 0.75F);
        float* highlight = pixel(frame.source, frame, 5, 11);
        highlight[0] = 2.5F;
        highlight[1] = 1.6F;
        highlight[2] = 0.7F;
        float* transparent = pixel(frame.source, frame, 6, 11);
        transparent[0] = 100.0F;
        transparent[1] = -50.0F;
        transparent[2] = 25.0F;
        transparent[3] = 0.0F;
        RenderRequest cpu_request = requestFor(frame);
        CHECK(linear(cpu_request.settings) && setSetting(cpu_request.settings, "mode", 1) &&
                  setSetting(cpu_request.settings, "density", 2) && setDouble(cpu_request.settings, "diffusion", 62.0) &&
                  setDouble(cpu_request.settings, "bloom", 48.0) && setDouble(cpu_request.settings, "contrast", 32.0) &&
                  setDouble(cpu_request.settings, "texture", 41.0),
              "aligned Mist settings must be accepted");
        cpu_request.render_window = RectI{-1, 6, 13, 18};
        cpu_request.alpha_association = AlphaAssociation::Premultiplied;
        CpuRenderBackend cpu_backend;
        CHECK(cbef::render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
              "aligned CPU Mist reference must complete");
        const std::vector<std::uint8_t> expected = frame.destination;
        id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size()
                                                          options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "aligned Mist buffers must allocate");
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, kSentinel, frame.destination.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)source,
                                            0U, frame.row_bytes, frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, frame.row_bytes, frame.bounds};
        MetalRenderBackend metal_backend((__bridge void*)queue);
        CHECK(cbef::render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "aligned Metal Mist must enqueue");
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "aligned Mist sentinel must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted, "aligned Mist sentinel must complete");
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
                CHECK(expected_alpha == actual_alpha, "aligned Mist must preserve alpha bits");
            }
        }
        CHECK(maximum_error <= 2.0e-4F, "aligned CPU and Metal Mist must agree within 2e-4");
        CHECK(std::abs(pixel(actual, frame, 6, 11)[0]) <= 1.0e-6F &&
                  std::abs(pixel(actual, frame, 6, 11)[1]) <= 1.0e-6F &&
                  std::abs(pixel(actual, frame, 6, 11)[2]) <= 1.0e-6F,
              "aligned Mist transparent hidden RGB must remain zero");
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
    if (testDensityAndWhiteRadius() != 0) return 1;
    if (testShadowMtfAlphaHdrAndEdges() != 0) return 1;
    if (testMtfTextureAndResolution() != 0) return 1;
    if (testDiagnosticViews() != 0) return 1;
#if defined(CBEF_ENABLE_METAL_TEST)
    if (testMetalParityAndContracts() != 0) return 1;
    if (testMetalAlignedFastPathParity() != 0) return 1;
#endif
    std::puts("mist_render_contract: PASS");
    return 0;
}
