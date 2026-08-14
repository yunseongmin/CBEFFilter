#import <Metal/Metal.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <limits>
#include <numeric>
#include <vector>

#include "cbef/RenderCore.h"

namespace {

using cbef::AlphaAssociation;
using cbef::CpuRenderBackend;
using cbef::DataWindow;
using cbef::EffectDefinition;
using cbef::EffectId;
using cbef::FrameSurface;
using cbef::MemoryKind;
using cbef::MetalRenderBackend;
using cbef::PixelFormat;
using cbef::RectI;
using cbef::RenderRequest;
using cbef::RenderScale;
using cbef::RenderSubmission;
using cbef::SubmissionKind;

constexpr float kAlphaEpsilon = 1.0e-6F;
constexpr std::size_t kRgbaBytes = sizeof(float) * 4U;
constexpr std::uint8_t kSentinel = 0xA5U;

int fail(const char* message)
{
    std::fprintf(stderr, "halation_render_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) { \
            return fail(message); \
        } \
    } while (false)

struct CpuFrame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    CpuFrame(int width, int height, int x = 0, int y = 0, std::size_t row_padding = 0U)
        : bounds{x, y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kRgbaBytes + row_padding)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), kSentinel)
    {
    }
};

FrameSurface cpuSurface(void* data, const CpuFrame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, frame.bounds};
}

float* pixel(std::vector<std::uint8_t>& storage, const CpuFrame& frame, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - frame.bounds.y);
    const std::size_t column = static_cast<std::size_t>(x - frame.bounds.x);
    return reinterpret_cast<float*>(storage.data() + row * frame.row_bytes + column * kRgbaBytes);
}

const float* pixel(const std::vector<std::uint8_t>& storage, const CpuFrame& frame, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - frame.bounds.y);
    const std::size_t column = static_cast<std::size_t>(x - frame.bounds.x);
    return reinterpret_cast<const float*>(storage.data() + row * frame.row_bytes + column * kRgbaBytes);
}

RenderRequest requestFor(CpuFrame& frame)
{
    return RenderRequest{EffectId::Halation,
                         cpuSurface(frame.source.data(), frame),
                         cpuSurface(frame.destination.data(), frame),
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height},
                         12.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         cbef::defaultSettings(EffectId::Halation)};
}

void fill(CpuFrame& frame, float red, float green, float blue, float alpha = 1.0F)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* value = pixel(frame.source, frame, x, y);
            value[0] = red;
            value[1] = green;
            value[2] = blue;
            value[3] = alpha;
        }
    }
}

bool setLinear(cbef::Settings& settings)
{
    return cbef::setSetting(settings, "working_mode", 1);
}

int testDefinition()
{
    const EffectDefinition& definition = cbef::effectDefinition(EffectId::Halation);
    CHECK(definition.parameters.size() == 18U,
          "Halation must append Color Emphasis and Color Strength after its existing parameters");
    CHECK(definition.presets.size() == 5U,
          "Halation must preserve three existing preset ordinals and append two emphasis presets");
    const cbef::ParameterDefinition& color_emphasis = definition.parameters[16];
    CHECK(std::strcmp(color_emphasis.id, "color_emphasis") == 0 && color_emphasis.choices.size() == 5U &&
              std::string_view(color_emphasis.choices[4]) == "Auto (Scene Adaptive)" &&
              std::get<int>(color_emphasis.default_value) == 0,
          "Halation must append Auto without changing prior Color Emphasis ordinals or the default");
    CHECK(std::get<double>(cbef::defaultSettings(EffectId::Halation).values[4]) == 22.0,
          "Subtle 35 must remain the default Halation preset");
    const cbef::Settings warm_negative = cbef::settingsForPreset(EffectId::Halation, 1U);
    CHECK(std::get<double>(cbef::settingValue(warm_negative, "amount")) == 38.0,
          "Warm Negative must expand its specified Amount");
    CHECK(std::get<bool>(cbef::settingValue(warm_negative, "highlights_only")),
          "Warm Negative must retain Highlights Only");
    return 0;
}

int testThresholdAndOutputViews()
{
    CpuRenderBackend backend;
    CpuFrame frame(9, 3, 4, -2, 16U);
    fill(frame, 0.18F * std::exp2(-0.76F), 0.18F * std::exp2(-0.76F),
         0.18F * std::exp2(-0.76F));
    RenderRequest request = requestFor(frame);
    CHECK(setLinear(request.settings), "test must select DWG Linear");
    CHECK(cbef::setSetting(request.settings, "source_smoothness", 0.0),
          "test must select a narrow source smoothness knee");
    CHECK(cbef::setSetting(request.settings, "threshold", 0.0), "test must select threshold zero");
    CHECK(cbef::setSetting(request.settings, "output_view", 2), "test must select Highlight Matte");
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
          "threshold matte render must complete");
    CHECK(pixel(frame.destination, frame, 8, -1)[0] <= kAlphaEpsilon,
          "a patch below the fixed 0.75-stop knee must produce no matte");

    std::fill(frame.destination.begin(), frame.destination.end(), kSentinel);
    CHECK(cbef::setSetting(request.settings, "highlights_only", false),
          "test must disable Highlights Only");
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
          "full-positive matte render must complete");
    const float matte = pixel(frame.destination, frame, 8, -1)[0];
    CHECK(std::abs(matte - 1.0F) <= 1.0e-6F,
          "Highlights Only off must expose every positive opaque pixel in the matte");
    return 0;
}

int testHaloShapeColourAndCore()
{
    CpuRenderBackend backend;
    CpuFrame frame(513, 257);
    fill(frame, 0.0F, 0.0F, 0.0F);
    constexpr int center_x = 256;
    constexpr int center_y = 128;
    float* source = pixel(frame.source, frame, center_x, center_y);
    source[0] = 1.0F;
    source[1] = 1.0F;
    source[2] = 1.0F;
    source[3] = 1.0F;

    RenderRequest request = requestFor(frame);
    CHECK(setLinear(request.settings), "test must select DWG Linear");
    CHECK(cbef::setSetting(request.settings, "amount", 100.0), "test must increase Amount");
    CHECK(cbef::setSetting(request.settings, "radius", 0.65), "test must select the default visible radius");
    CHECK(cbef::setSetting(request.settings, "threshold", -2.0), "test must include the impulse as a highlight");
    CHECK(cbef::setSetting(request.settings, "warmth", 100.0), "test must select warm target gains");
    CHECK(cbef::setSetting(request.settings, "saturation", 100.0), "test must preserve the warm target chroma");
    CHECK(cbef::setSetting(request.settings, "output_view", 1), "test must select Halation Component");
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
          "Halation component render must complete");

    const float core_luma = 0.27411851F * pixel(frame.destination, frame, center_x, center_y)[0] +
                            0.87363190F * pixel(frame.destination, frame, center_x, center_y)[1] -
                            0.14775041F * pixel(frame.destination, frame, center_x, center_y)[2];
    CHECK(core_luma <= 0.02F, "core subtraction must limit the highlight-core change to two percent");

    int peak = center_x + 1;
    float peak_value = 0.0F;
    for (int x = center_x + 1; x < frame.bounds.width; ++x) {
        const float value = pixel(frame.destination, frame, x, center_y)[0];
        if (value > peak_value) {
            peak_value = value;
            peak = x;
        }
    }
    CHECK(peak_value > 1.0e-5F, "a bright edge must create an exterior halo");
    const float* peak_rgb = pixel(frame.destination, frame, peak, center_y);
    CHECK(peak_rgb[0] >= peak_rgb[1] && peak_rgb[1] >= peak_rgb[2],
          "the neutral default source must produce a warm R >= G >= B halo");
    for (int x = peak + 1; x < frame.bounds.width; ++x) {
        CHECK(pixel(frame.destination, frame, x, center_y)[0] <=
                  pixel(frame.destination, frame, x - 1, center_y)[0] + 1.0e-5F,
              "the exterior halo profile must be monotonically non-increasing after its peak");
    }
    return 0;
}

int testAlphaHdrEdgesAndIdentity()
{
    CpuRenderBackend backend;
    CpuFrame frame(17, 9, 3, -4, 32U);
    fill(frame, -0.25F, 0.05F, 2.5F, 1.0F);
    float* transparent = pixel(frame.source, frame, 10, 0);
    transparent[0] = 100.0F;
    transparent[1] = 50.0F;
    transparent[2] = 25.0F;
    transparent[3] = 0.0F;
    RenderRequest request = requestFor(frame);
    CHECK(setLinear(request.settings), "test must select DWG Linear");
    CHECK(cbef::setSetting(request.settings, "amount", 100.0), "test must make Final non-identity");
    CHECK(cbef::setSetting(request.settings, "radius", 2.0), "test must choose a spatial radius");
    CHECK(cbef::setSetting(request.settings, "threshold", -2.0), "test must include HDR positive pixels");
    request.render_window = RectI{4, -3, 19, 4};
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
          "HDR and alpha render must complete");
    for (int channel = 0; channel < 3; ++channel) {
        CHECK(std::isfinite(pixel(frame.destination, frame, 4, -3)[channel]),
              "finite HDR input must remain finite");
    }
    CHECK(pixel(frame.destination, frame, 4, -3)[0] < -0.20F,
          "signed negative residual must survive the Halation operation");
    for (int channel = 0; channel < 3; ++channel) {
        CHECK(std::abs(pixel(frame.destination, frame, 10, 0)[channel]) <= kAlphaEpsilon,
              "transparent hidden RGB must never emit a halo");
    }
    std::uint32_t source_alpha = 0U;
    std::uint32_t destination_alpha = 0U;
    std::memcpy(&source_alpha, &pixel(frame.source, frame, 4, -3)[3], sizeof(source_alpha));
    std::memcpy(&destination_alpha, &pixel(frame.destination, frame, 4, -3)[3], sizeof(destination_alpha));
    CHECK(source_alpha == destination_alpha, "Halation must retain the alpha bit pattern");
    CHECK(frame.destination.front() == kSentinel, "Halation must preserve bytes outside the render window");

    CpuFrame identity(3, 2);
    RenderRequest identity_request = requestFor(identity);
    const std::array<std::uint32_t, 4> original = {0x7FC01234U, 0xBF800000U, 0x3F400000U, 0x00000000U};
    std::memcpy(pixel(identity.source, identity, 0, 0), original.data(), kRgbaBytes);
    CHECK(cbef::setSetting(identity_request.settings, "amount", 0.0), "test must select Amount identity");
    CHECK(cbef::render(identity_request, backend).kind == SubmissionKind::Completed,
          "Amount zero must complete with identity copy");
    std::array<std::uint32_t, 4> copied{};
    std::memcpy(copied.data(), pixel(identity.destination, identity, 0, 0), kRgbaBytes);
    CHECK(copied == original, "Amount zero Final must retain every source float bit");
    return 0;
}

float sinc(float value)
{
    if (std::abs(value) < 1.0e-6F) {
        return 1.0F;
    }
    const float angle = static_cast<float>(M_PI) * value;
    return std::sin(angle) / angle;
}

std::vector<float> lanczosDownsample(const CpuFrame& frame, int output_width, int output_height)
{
    std::vector<float> result(static_cast<std::size_t>(output_width) * static_cast<std::size_t>(output_height) * 3U,
                              0.0F);
    const float scale_x = static_cast<float>(frame.bounds.width) / static_cast<float>(output_width);
    const float scale_y = static_cast<float>(frame.bounds.height) / static_cast<float>(output_height);
    for (int y = 0; y < output_height; ++y) {
        const float source_y = (static_cast<float>(y) + 0.5F) * scale_y - 0.5F;
        const int first_y = static_cast<int>(std::floor(source_y - 3.0F + 1.0F));
        const int last_y = static_cast<int>(std::ceil(source_y + 3.0F));
        for (int x = 0; x < output_width; ++x) {
            const float source_x = (static_cast<float>(x) + 0.5F) * scale_x - 0.5F;
            const int first_x = static_cast<int>(std::floor(source_x - 3.0F + 1.0F));
            const int last_x = static_cast<int>(std::ceil(source_x + 3.0F));
            std::array<float, 3> total = {0.0F, 0.0F, 0.0F};
            float weight_total = 0.0F;
            for (int sample_y = first_y; sample_y <= last_y; ++sample_y) {
                const float wy = sinc(source_y - static_cast<float>(sample_y)) *
                                 sinc((source_y - static_cast<float>(sample_y)) / 3.0F);
                const int clamped_y = std::clamp(sample_y, 0, frame.bounds.height - 1);
                for (int sample_x = first_x; sample_x <= last_x; ++sample_x) {
                    const float wx = sinc(source_x - static_cast<float>(sample_x)) *
                                     sinc((source_x - static_cast<float>(sample_x)) / 3.0F);
                    const float weight = wx * wy;
                    const int clamped_x = std::clamp(sample_x, 0, frame.bounds.width - 1);
                    const float* value = pixel(frame.destination, frame, frame.bounds.x + clamped_x,
                                               frame.bounds.y + clamped_y);
                    for (int channel = 0; channel < 3; ++channel) {
                        total[static_cast<std::size_t>(channel)] += weight * value[channel];
                    }
                    weight_total += weight;
                }
            }
            const std::size_t index = (static_cast<std::size_t>(y) * static_cast<std::size_t>(output_width) +
                                       static_cast<std::size_t>(x)) * 3U;
            for (int channel = 0; channel < 3; ++channel) {
                result[index + static_cast<std::size_t>(channel)] =
                    total[static_cast<std::size_t>(channel)] / weight_total;
            }
        }
    }
    return result;
}

void lowPass(std::vector<float>& image, int width, int height)
{
    constexpr std::array<float, 7> weights = {0.00443305F, 0.05400558F, 0.24203622F, 0.39905028F,
                                               0.24203622F, 0.05400558F, 0.00443305F};
    std::vector<float> horizontal(image.size(), 0.0F);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            for (int tap = -3; tap <= 3; ++tap) {
                const int sample_x = std::clamp(x + tap, 0, width - 1);
                const std::size_t source_index =
                    (static_cast<std::size_t>(y) * static_cast<std::size_t>(width) + sample_x) * 3U;
                const std::size_t destination_index =
                    (static_cast<std::size_t>(y) * static_cast<std::size_t>(width) + x) * 3U;
                for (int channel = 0; channel < 3; ++channel) {
                    horizontal[destination_index + static_cast<std::size_t>(channel)] +=
                        weights[static_cast<std::size_t>(tap + 3)] * image[source_index + static_cast<std::size_t>(channel)];
                }
            }
        }
    }
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            const std::size_t destination_index =
                (static_cast<std::size_t>(y) * static_cast<std::size_t>(width) + x) * 3U;
            std::fill_n(image.begin() + static_cast<std::ptrdiff_t>(destination_index), 3, 0.0F);
            for (int tap = -3; tap <= 3; ++tap) {
                const int sample_y = std::clamp(y + tap, 0, height - 1);
                const std::size_t source_index =
                    (static_cast<std::size_t>(sample_y) * static_cast<std::size_t>(width) + x) * 3U;
                for (int channel = 0; channel < 3; ++channel) {
                    image[destination_index + static_cast<std::size_t>(channel)] +=
                        weights[static_cast<std::size_t>(tap + 3)] * horizontal[source_index + static_cast<std::size_t>(channel)];
                }
            }
        }
    }
}

float psnr(const std::vector<float>& left, const std::vector<float>& right)
{
    double squared_error = 0.0;
    for (std::size_t index = 0; index < left.size(); ++index) {
        const double difference = static_cast<double>(left[index]) - right[index];
        squared_error += difference * difference;
    }
    const double mse = squared_error / static_cast<double>(left.size());
    return mse == 0.0 ? std::numeric_limits<float>::infinity()
                      : static_cast<float>(10.0 * std::log10(1.0 / mse));
}

float profileHalfRadius(const CpuFrame& frame)
{
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    float peak = 0.0F;
    int peak_x = center_x + 1;
    for (int x = center_x + 1; x < frame.bounds.x + frame.bounds.width; ++x) {
        const float value = pixel(frame.destination, frame, x, center_y)[0];
        if (value > peak) {
            peak = value;
            peak_x = x;
        }
    }
    const float half = peak * 0.5F;
    for (int x = peak_x + 1; x < frame.bounds.x + frame.bounds.width; ++x) {
        const float previous = pixel(frame.destination, frame, x - 1, center_y)[0];
        const float current = pixel(frame.destination, frame, x, center_y)[0];
        if (current <= half) {
            const float fraction = (half - current) / std::max(previous - current, 1.0e-8F);
            return (static_cast<float>(x - 1 - center_x) + fraction) / static_cast<float>(frame.bounds.height);
        }
    }
    return std::numeric_limits<float>::infinity();
}

double componentEnergy(const CpuFrame& frame)
{
    double total = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float* value = pixel(frame.destination, frame, x, y);
            total += std::abs(value[0]) + std::abs(value[1]) + std::abs(value[2]);
        }
    }
    return total / static_cast<double>(frame.bounds.width * frame.bounds.height);
}

int renderResolutionFixture(CpuFrame& frame)
{
    fill(frame, 0.04F, 0.04F, 0.04F);
    const float scale = static_cast<float>(frame.bounds.height) / 1080.0F;
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    const float radius = 20.0F * scale;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float dx = static_cast<float>(x - center_x);
            const float dy = static_cast<float>(y - center_y);
            if (dx * dx + dy * dy <= radius * radius) {
                float* value = pixel(frame.source, frame, x, y);
                value[0] = 1.0F;
                value[1] = 1.0F;
                value[2] = 1.0F;
            }
        }
    }
    CpuRenderBackend backend;
    RenderRequest request = requestFor(frame);
    if (!setLinear(request.settings) || !cbef::setSetting(request.settings, "amount", 100.0) ||
        !cbef::setSetting(request.settings, "radius", 0.65) ||
        !cbef::setSetting(request.settings, "threshold", 0.0) ||
        !cbef::setSetting(request.settings, "output_view", 1)) {
        return fail("resolution fixture settings must be accepted");
    }
    return cbef::render(request, backend).kind == SubmissionKind::Completed ? 0
                                                                              : fail("resolution render must complete");
}

int testResolutionInvariance()
{
    CpuFrame image_1080(1920, 1080);
    CpuFrame image_4k(3840, 2160);
    if (const int result = renderResolutionFixture(image_1080); result != 0) {
        return result;
    }
    if (const int result = renderResolutionFixture(image_4k); result != 0) {
        return result;
    }
    std::vector<float> downsampled = lanczosDownsample(image_4k, 1920, 1080);
    std::vector<float> direct = lanczosDownsample(image_1080, 1920, 1080);
    lowPass(downsampled, 1920, 1080);
    lowPass(direct, 1920, 1080);
    CHECK(psnr(direct, downsampled) >= 45.0F,
          "1080p and 4K Halation results must meet the low-pass PSNR criterion");
    CHECK(std::abs(profileHalfRadius(image_1080) - profileHalfRadius(image_4k)) <= 0.001F,
          "Halation half-maximum radius must agree within 0.1 percent of frame height");
    const double energy_1080 = componentEnergy(image_1080);
    const double energy_4k = componentEnergy(image_4k);
    CHECK(std::abs(energy_1080 - energy_4k) / std::max(energy_1080, 1.0e-9) <= 0.03,
          "Halation low-frequency energy must agree within three percent across resolutions");
    return 0;
}

#if defined(CBEF_ENABLE_METAL_TEST)
int testMetalParity()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "a Metal device is required for Halation parity");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "a Metal command queue is required for Halation parity");
        CpuFrame cpu_frame(97, 61, -4, 3, 16U);
        fill(cpu_frame, 0.03F, 0.04F, 0.05F, 0.75F);
        float* highlight = pixel(cpu_frame.source, cpu_frame, 41, 31);
        highlight[0] = 2.5F;
        highlight[1] = 1.7F;
        highlight[2] = 0.8F;
        float* hidden = pixel(cpu_frame.source, cpu_frame, 42, 31);
        hidden[0] = 10.0F;
        hidden[1] = 5.0F;
        hidden[2] = 2.0F;
        hidden[3] = 0.0F;
        RenderRequest cpu_request = requestFor(cpu_frame);
        CHECK(setLinear(cpu_request.settings), "test must select DWG Linear");
        CHECK(cbef::setSetting(cpu_request.settings, "amount", 100.0), "test must increase Amount");
        CHECK(cbef::setSetting(cpu_request.settings, "radius", 1.0), "test must select radius");
        CHECK(cbef::setSetting(cpu_request.settings, "threshold", -1.0), "test must select threshold");
        cpu_request.alpha_association = AlphaAssociation::Premultiplied;
        CpuRenderBackend cpu_backend;
        CHECK(cbef::render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
              "CPU Halation reference must complete");
        const std::vector<std::uint8_t> expected = cpu_frame.destination;

        const NSUInteger length = static_cast<NSUInteger>(cpu_frame.source.size());
        id<MTLBuffer> source = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "Metal Halation buffers must allocate");
        std::memcpy(source.contents, cpu_frame.source.data(), cpu_frame.source.size());
        std::memset(destination.contents, kSentinel, cpu_frame.destination.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)source,
                                            0U, cpu_frame.row_bytes, cpu_frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, cpu_frame.row_bytes,
                                                 cpu_frame.bounds};
        MetalRenderBackend metal_backend((__bridge void*)queue);
        CHECK(cbef::render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "Metal Halation must submit to the host queue");
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "same-queue sentinel must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted, "same-queue sentinel must complete");
        std::vector<std::uint8_t> actual(cpu_frame.destination.size(), 0U);
        std::memcpy(actual.data(), destination.contents, actual.size());
        float maximum_error = 0.0F;
        for (int y = cpu_frame.bounds.y; y < cpu_frame.bounds.y + cpu_frame.bounds.height; ++y) {
            for (int x = cpu_frame.bounds.x; x < cpu_frame.bounds.x + cpu_frame.bounds.width; ++x) {
                const float* expected_pixel = pixel(expected, cpu_frame, x, y);
                const float* actual_pixel = pixel(actual, cpu_frame, x, y);
                for (int channel = 0; channel < 3; ++channel) {
                    const float error = std::abs(expected_pixel[channel] - actual_pixel[channel]);
                    if (error > maximum_error) {
                        maximum_error = error;
                    }
                }
            }
        }
        CHECK(maximum_error <= 2.0e-4F, "CPU and Metal Halation must agree within 2e-4");
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
        CHECK(device != nil, "a Metal device is required for aligned Halation parity");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "a Metal command queue is required for aligned Halation parity");
        CpuFrame frame(16, 16, -2, 4, 16U);
        fill(frame, 0.03F, 0.04F, 0.05F, 0.75F);
        float* highlight = pixel(frame.source, frame, 5, 11);
        highlight[0] = 2.5F;
        highlight[1] = 1.7F;
        highlight[2] = 0.8F;
        float* hidden = pixel(frame.source, frame, 6, 11);
        hidden[0] = 10.0F;
        hidden[1] = 5.0F;
        hidden[2] = 2.0F;
        hidden[3] = 0.0F;
        RenderRequest cpu_request = requestFor(frame);
        CHECK(setLinear(cpu_request.settings) && cbef::setSetting(cpu_request.settings, "amount", 100.0) &&
                  cbef::setSetting(cpu_request.settings, "radius", 1.0) &&
                  cbef::setSetting(cpu_request.settings, "threshold", -1.0),
              "aligned Halation settings must be accepted");
        cpu_request.alpha_association = AlphaAssociation::Premultiplied;
        cpu_request.render_window = RectI{-1, 6, 13, 18};
        CpuRenderBackend cpu_backend;
        CHECK(cbef::render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
              "aligned CPU Halation reference must complete");
        const std::vector<std::uint8_t> expected = frame.destination;
        const NSUInteger length = static_cast<NSUInteger>(frame.source.size());
        id<MTLBuffer> source = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "aligned Halation buffers must allocate");
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, kSentinel, frame.destination.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)source,
                                            0U, frame.row_bytes, frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, frame.row_bytes, frame.bounds};
        MetalRenderBackend metal_backend((__bridge void*)queue);
        CHECK(cbef::render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "aligned Metal Halation must enqueue");
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "aligned Halation sentinel must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted, "aligned Halation sentinel must complete");
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
                CHECK(expected_alpha == actual_alpha, "aligned Halation must preserve alpha bits");
            }
        }
        CHECK(maximum_error <= 2.0e-4F, "aligned CPU and Metal Halation must agree within 2e-4");
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            const std::size_t row_padding_start = static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                                   static_cast<std::size_t>(frame.bounds.width) * kRgbaBytes;
            for (std::size_t byte = row_padding_start; byte < static_cast<std::size_t>(y - frame.bounds.y + 1) * frame.row_bytes;
                 ++byte) {
                CHECK(actual[byte] == kSentinel, "aligned Halation must preserve row padding");
            }
        }
        [source release];
        [destination release];
        [queue release];
    }
    return 0;
}
#endif

}

int main()
{
    if (const int result = testDefinition(); result != 0) {
        return result;
    }
    if (const int result = testThresholdAndOutputViews(); result != 0) {
        return result;
    }
    if (const int result = testHaloShapeColourAndCore(); result != 0) {
        return result;
    }
    if (const int result = testAlphaHdrEdgesAndIdentity(); result != 0) {
        return result;
    }
    if (const int result = testResolutionInvariance(); result != 0) {
        return result;
    }
#if defined(CBEF_ENABLE_METAL_TEST)
    if (const int result = testMetalParity(); result != 0) {
        return result;
    }
    if (const int result = testMetalAlignedFastPathParity(); result != 0) {
        return result;
    }
#endif
    std::puts("halation_render_contract: PASS (CPU + Metal M2 Halation)");
    return 0;
}
