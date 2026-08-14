#import <Metal/Metal.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <limits>
#include <string>
#include <vector>

#include "cbef/RenderCore.h"

namespace {

using cbef::AlphaAssociation;
using cbef::BackendKind;
using cbef::CpuRenderBackend;
using cbef::DataWindow;
using cbef::EffectId;
using cbef::Error;
using cbef::FrameSurface;
using cbef::MemoryKind;
using cbef::MetalRenderBackend;
using cbef::ParameterType;
using cbef::PixelFormat;
using cbef::RectI;
using cbef::RenderRequest;
using cbef::RenderScale;
using cbef::RenderSubmission;
using cbef::Settings;
using cbef::SettingValue;
using cbef::SubmissionKind;
using cbef::WorkingMode;

constexpr std::uint8_t kDestinationSentinel = 0xA5;
constexpr std::size_t kRgbaBytes = sizeof(float) * 4U;

int fail(const char* message)
{
    std::fprintf(stderr, "headless_render_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) { \
            return fail(message); \
        } \
    } while (false)

struct CpuFrame {
    DataWindow bounds{5, -3, 3, 2};
    std::size_t row_bytes = 64;
    std::vector<std::uint8_t> source = std::vector<std::uint8_t>(row_bytes * 2U, 0U);
    std::vector<std::uint8_t> destination = std::vector<std::uint8_t>(row_bytes * 2U,
                                                                       kDestinationSentinel);
};

FrameSurface cpuSurface(void* data, const CpuFrame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes,
                        frame.bounds};
}

float* pixel(std::vector<std::uint8_t>& storage, const CpuFrame& frame, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - frame.bounds.y);
    const std::size_t column = static_cast<std::size_t>(x - frame.bounds.x);
    return reinterpret_cast<float*>(storage.data() + row * frame.row_bytes + column * kRgbaBytes);
}

RenderRequest requestFor(CpuFrame& frame, EffectId effect)
{
    return RenderRequest{effect,
                         cpuSurface(frame.source.data(), frame),
                         cpuSurface(frame.destination.data(), frame),
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height},
                         12.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         cbef::defaultSettings(effect)};
}

bool isFailedWith(const RenderSubmission& submission, Error error)
{
    return submission.kind == SubmissionKind::Failed && submission.error == error;
}

int testEffectDefinitions()
{
    constexpr std::array<EffectId, 5> effects = {
        EffectId::Halation,
        EffectId::FilmGrain,
        EffectId::OpticalBlur,
        EffectId::LensReflections,
        EffectId::MistDiffusion,
    };

    constexpr std::array<std::array<const char*, 10>, 5> expected_ids = {{
        {{"working_mode", "output_view", "mix", "preset", "amount", "radius", "threshold",
          "highlights_only", "warmth", "saturation"}},
        {{"working_mode", "output_view", "mix", "preset", "format", "amount", "size", "softness",
          "chroma", "shadow"}},
        {{"working_mode", "output_view", "mix", "preset", "blur", "blades", "curvature", "rotation",
          "anamorphism", "highlight_response"}},
        {{"working_mode", "output_view", "mix", "preset", "amount", "threshold", "lens_model", "spread",
          "blur", "chroma"}},
        {{"working_mode", "output_view", "mix", "preset", "mode", "density", "diffusion", "bloom",
          "contrast", "texture"}},
    }};

    CHECK(cbef::effectDefinitions().size() == effects.size(), "five Effect Definitions are required");
    for (std::size_t effect_index = 0; effect_index < effects.size(); ++effect_index) {
        const cbef::EffectDefinition& definition = cbef::effectDefinition(effects[effect_index]);
        std::vector<std::string> ids;
        for (const cbef::ParameterDefinition& parameter : definition.parameters) {
            CHECK(parameter.id != nullptr && parameter.id[0] != '\0', "parameter ID must be stable");
            CHECK(std::find(ids.begin(), ids.end(), parameter.id) == ids.end(),
                  "parameter ID must be unique inside an effect");
            ids.emplace_back(parameter.id);
            CHECK(parameter.default_value.index() == static_cast<std::size_t>(parameter.type),
                  "parameter default must match its declared type");
        }
        for (const char* expected_id : expected_ids[effect_index]) {
            CHECK(std::find(ids.begin(), ids.end(), expected_id) != ids.end(),
                  "Effect Definition is missing a required parameter");
        }

        Settings defaults = cbef::defaultSettings(effects[effect_index]);
        CHECK(defaults.effect == effects[effect_index], "default settings belong to the requested effect");
        CHECK(cbef::settingsUsePreset(defaults), "default settings must expand the default preset");
        for (std::size_t preset = 0; preset < definition.presets.size(); ++preset) {
            Settings expanded = cbef::settingsForPreset(effects[effect_index], preset);
            CHECK(cbef::settingsUsePreset(expanded), "preset expansion must be recognized as a preset");
            CHECK(cbef::settingChoice(expanded, "preset") == static_cast<int>(preset),
                  "expanded settings must retain their preset selection");
        }

        Settings custom = defaults;
        const char* mutable_parameter = definition.parameters.back().id;
        const SettingValue original = cbef::settingValue(custom, mutable_parameter);
        if (std::holds_alternative<double>(original)) {
            CHECK(cbef::setSetting(custom, mutable_parameter, std::get<double>(original) + 0.001),
                  "setting mutation must succeed");
        } else if (std::holds_alternative<std::int64_t>(original)) {
            CHECK(cbef::setSetting(custom, mutable_parameter, std::get<std::int64_t>(original) + 1),
                  "setting mutation must succeed");
        } else if (std::holds_alternative<bool>(original)) {
            CHECK(cbef::setSetting(custom, mutable_parameter, !std::get<bool>(original)),
                  "setting mutation must succeed");
        } else {
            const int option = std::get<int>(original);
            CHECK(cbef::setSetting(custom, mutable_parameter, option == 0 ? 1 : 0),
                  "setting mutation must succeed");
        }
        CHECK(!cbef::settingsUsePreset(custom), "editing a preset-controlled value must select Custom");
    }
    return 0;
}

int testInvalidRequests()
{
    CpuRenderBackend backend;
    CpuFrame frame;
    RenderRequest request = requestFor(frame, EffectId::Halation);

    request.effect = static_cast<EffectId>(99);
    CHECK(isFailedWith(cbef::render(request, backend), Error::UnsupportedEffectId),
          "unknown effect must fail before writing");

    request = requestFor(frame, EffectId::Halation);
    request.source.pixel_format = PixelFormat::Unsupported;
    CHECK(isFailedWith(cbef::render(request, backend), Error::UnsupportedPixelFormat),
          "unsupported pixel format must fail");

    request = requestFor(frame, EffectId::Halation);
    request.source.data_window.width = 0;
    CHECK(isFailedWith(cbef::render(request, backend), Error::InvalidDimensions),
          "zero-width source must fail");

    request = requestFor(frame, EffectId::Halation);
    request.destination.row_bytes = 49U;
    CHECK(isFailedWith(cbef::render(request, backend), Error::InvalidStride),
          "non-four-byte aligned stride must fail");

    request = requestFor(frame, EffectId::Halation);
    request.destination.data_window.x += 1;
    CHECK(isFailedWith(cbef::render(request, backend), Error::MismatchedSurfaceBounds),
          "different source and destination bounds must fail");

    request = requestFor(frame, EffectId::Halation);
    request.render_window.x1 -= 1;
    CHECK(isFailedWith(cbef::render(request, backend), Error::InvalidRenderWindow),
          "render window outside destination must fail");

    request = requestFor(frame, EffectId::Halation);
    request.frame_time = std::numeric_limits<double>::infinity();
    CHECK(isFailedWith(cbef::render(request, backend), Error::InvalidFrameTime),
          "infinite frame time must fail");

    request = requestFor(frame, EffectId::Halation);
    request.settings = cbef::defaultSettings(EffectId::FilmGrain);
    CHECK(isFailedWith(cbef::render(request, backend), Error::SettingsTypeMismatch),
          "settings for another effect must fail");

    request = requestFor(frame, EffectId::Halation);
    CHECK(cbef::setSetting(request.settings, "amount", 500.0), "test must alter Amount");
    CHECK(isFailedWith(cbef::render(request, backend), Error::SettingOutOfRange),
          "out-of-range setting must fail rather than clamp");

    request = requestFor(frame, EffectId::Halation);
    CHECK(cbef::setSetting(request.settings, "amount", std::numeric_limits<double>::quiet_NaN()),
          "test must alter Amount");
    CHECK(isFailedWith(cbef::render(request, backend), Error::NonFiniteSetting),
          "non-finite setting must fail");

    request = requestFor(frame, EffectId::Halation);
    request.destination.data = request.source.data;
    CHECK(isFailedWith(cbef::render(request, backend), Error::AliasedSurfaces),
          "aliased CPU source and destination must fail");

    request = requestFor(frame, EffectId::Halation);
    request.destination.data = static_cast<unsigned char*>(request.source.data) + 4U;
    CHECK(isFailedWith(cbef::render(request, backend), Error::AliasedSurfaces),
          "partially overlapping CPU surfaces must fail");

    return 0;
}

int testExactIdentityCopy()
{
    CpuRenderBackend backend;
    CpuFrame frame;
    RenderRequest request = requestFor(frame, EffectId::Halation);
    request.render_window = RectI{6, -2, 7, -1};
    CHECK(cbef::setSetting(request.settings, "amount", 0.0), "test must set identity Amount");

    constexpr std::array<std::uint32_t, 4> source_words = {
        0x7FC01234U,
        0xBF800000U,
        0x3F400000U,
        0x00000000U,
    };
    std::memcpy(pixel(frame.source, frame, 6, -2), source_words.data(), kRgbaBytes);
    const RenderSubmission submission = cbef::render(request, backend);
    CHECK(submission.kind == SubmissionKind::Completed, "CPU identity must complete synchronously");

    std::array<std::uint32_t, 4> destination_words{};
    std::memcpy(destination_words.data(), pixel(frame.destination, frame, 6, -2), kRgbaBytes);
    CHECK(destination_words == source_words, "identity must preserve all RGBA float bits including hidden RGB");

    for (std::size_t byte = 0; byte < frame.destination.size(); ++byte) {
        const std::size_t changed_start = frame.row_bytes + kRgbaBytes;
        const std::size_t changed_end = changed_start + kRgbaBytes;
        if (byte < changed_start || byte >= changed_end) {
            CHECK(frame.destination[byte] == kDestinationSentinel,
                  "identity must preserve destination bytes outside the render window");
        }
    }
    return 0;
}

int testAlphaAndDiagnosticOrdering()
{
    CpuRenderBackend backend;
    CpuFrame frame;
    RenderRequest request = requestFor(frame, EffectId::Halation);
    request.settings = cbef::defaultSettings(EffectId::Halation);
    CHECK(cbef::setSetting(request.settings, "working_mode", 1), "test must select DWG Linear");
    CHECK(cbef::setSetting(request.settings, "amount", 100.0), "test must make scaffold non-identity");
    CHECK(cbef::setSetting(request.settings, "mix", 100.0), "test must select full mix");
    *pixel(frame.source, frame, 5, -3) = 0.2F;
    pixel(frame.source, frame, 5, -3)[1] = 0.3F;
    pixel(frame.source, frame, 5, -3)[2] = 0.4F;
    pixel(frame.source, frame, 5, -3)[3] = 1.0F;
    pixel(frame.source, frame, 6, -3)[0] = 99.0F;
    pixel(frame.source, frame, 6, -3)[1] = -50.0F;
    pixel(frame.source, frame, 6, -3)[2] = 1.0F;
    pixel(frame.source, frame, 6, -3)[3] = 0.0F;

    const RenderSubmission full_submission = cbef::render(request, backend);
    CHECK(full_submission.kind == SubmissionKind::Completed, "non-identity CPU render must complete");
    const std::array<float, 3> full = {pixel(frame.destination, frame, 5, -3)[0],
                                       pixel(frame.destination, frame, 5, -3)[1],
                                       pixel(frame.destination, frame, 5, -3)[2]};
    std::uint32_t source_alpha = 0;
    std::uint32_t destination_alpha = 0;
    std::memcpy(&source_alpha, &pixel(frame.source, frame, 5, -3)[3], sizeof(source_alpha));
    std::memcpy(&destination_alpha, &pixel(frame.destination, frame, 5, -3)[3], sizeof(destination_alpha));
    CHECK(source_alpha == destination_alpha, "non-identity alpha must be bit-identical");
    CHECK(std::abs(pixel(frame.destination, frame, 6, -3)[0]) <= 1.0e-6F &&
              std::abs(pixel(frame.destination, frame, 6, -3)[1]) <= 1.0e-6F &&
              std::abs(pixel(frame.destination, frame, 6, -3)[2]) <= 1.0e-6F,
          "transparent straight hidden RGB must not leak in non-identity output");

    std::fill(frame.destination.begin(), frame.destination.end(), kDestinationSentinel);
    CHECK(cbef::setSetting(request.settings, "mix", 0.0), "test must select zero mix");
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed, "zero Mix identity must complete");
    for (int channel = 0; channel < 4; ++channel) {
        std::uint32_t source_bit = 0;
        std::uint32_t destination_bit = 0;
        std::memcpy(&source_bit, &pixel(frame.source, frame, 5, -3)[channel], sizeof(source_bit));
        std::memcpy(&destination_bit, &pixel(frame.destination, frame, 5, -3)[channel], sizeof(destination_bit));
        CHECK(source_bit == destination_bit, "Final Mix zero must take the exact identity path");
    }

    std::fill(frame.destination.begin(), frame.destination.end(), kDestinationSentinel);
    CHECK(cbef::setSetting(request.settings, "mix", 50.0), "test must select half mix");
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed, "half Mix must complete");
    for (int channel = 0; channel < 3; ++channel) {
        const float original = pixel(frame.source, frame, 5, -3)[channel];
        const float halfway = pixel(frame.destination, frame, 5, -3)[channel];
        CHECK(std::abs((halfway - original) - 0.5F * (full[static_cast<std::size_t>(channel)] - original)) <
                  1.0e-6F,
              "Final Mix must be linear after the effect result is formed");
    }

    CHECK(cbef::setSetting(request.settings, "output_view", 1), "test must select Component view");
    CHECK(cbef::setSetting(request.settings, "mix", 0.0), "test must use Mix zero in diagnostics");
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
          "diagnostic view must render even when Final identity would apply");
    const std::array<float, 3> component_at_zero_mix = {pixel(frame.destination, frame, 5, -3)[0],
                                                         pixel(frame.destination, frame, 5, -3)[1],
                                                         pixel(frame.destination, frame, 5, -3)[2]};
    CHECK(cbef::setSetting(request.settings, "mix", 100.0), "test must use Mix full in diagnostics");
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
          "diagnostic view must complete at full Mix");
    for (int channel = 0; channel < 3; ++channel) {
        CHECK(std::abs(component_at_zero_mix[static_cast<std::size_t>(channel)] -
                           pixel(frame.destination, frame, 5, -3)[channel]) <
                  1.0e-7F,
              "diagnostic Component must ignore Mix");
    }

    CpuFrame premultiplied_frame;
    RenderRequest premultiplied = requestFor(premultiplied_frame, EffectId::Halation);
    premultiplied.alpha_association = AlphaAssociation::Premultiplied;
    premultiplied.render_scale = RenderScale{0.01, 1.0};
    CHECK(cbef::setSetting(premultiplied.settings, "working_mode", 1), "test must select DWG Linear");
    CHECK(cbef::setSetting(premultiplied.settings, "amount", 100.0), "test must make scaffold non-identity");
    CHECK(cbef::setSetting(premultiplied.settings, "radius", 5.0), "test must widen the Halation sample");
    CHECK(cbef::setSetting(premultiplied.settings, "threshold", -2.0),
          "test must include the premultiplied Halation sample in the highlight range");
    CHECK(cbef::setSetting(premultiplied.settings, "highlights_only", false),
          "test must exercise the premultiplied Halation path without threshold gating");
    pixel(premultiplied_frame.source, premultiplied_frame, 5, -3)[0] = 0.1F;
    pixel(premultiplied_frame.source, premultiplied_frame, 5, -3)[1] = 0.05F;
    pixel(premultiplied_frame.source, premultiplied_frame, 5, -3)[2] = 0.025F;
    pixel(premultiplied_frame.source, premultiplied_frame, 5, -3)[3] = 0.5F;
    pixel(premultiplied_frame.source, premultiplied_frame, 6, -3)[0] = 100.0F;
    pixel(premultiplied_frame.source, premultiplied_frame, 6, -3)[1] = 100.0F;
    pixel(premultiplied_frame.source, premultiplied_frame, 6, -3)[2] = 100.0F;
    pixel(premultiplied_frame.source, premultiplied_frame, 6, -3)[3] = 1.0F;
    CHECK(cbef::render(premultiplied, backend).kind == SubmissionKind::Completed,
          "premultiplied non-identity render must complete");
    std::memcpy(&source_alpha, &pixel(premultiplied_frame.source, premultiplied_frame, 5, -3)[3],
                sizeof(source_alpha));
    std::memcpy(&destination_alpha, &pixel(premultiplied_frame.destination, premultiplied_frame, 5, -3)[3],
                sizeof(destination_alpha));
    CHECK(source_alpha == destination_alpha, "premultiplied alpha must remain bit-identical");
    CHECK(pixel(premultiplied_frame.destination, premultiplied_frame, 5, -3)[0] > 0.1F,
          "premultiplied output must be re-associated after the dummy effect");
    return 0;
}

int testColourRoundTrips()
{
    constexpr std::array<WorkingMode, 3> modes = {
        WorkingMode::DwgIntermediate,
        WorkingMode::DwgLinear,
        WorkingMode::Rec709Gamma24,
    };
    CpuRenderBackend backend;
    for (const WorkingMode mode : modes) {
        CpuFrame frame;
        RenderRequest request = requestFor(frame, EffectId::OpticalBlur);
        CHECK(cbef::setSetting(request.settings, "working_mode", static_cast<int>(mode)),
              "test must select Working Mode");
        CHECK(cbef::setSetting(request.settings, "output_view", 1),
              "Blurred Image diagnostic must force the non-identity colour path");
        CHECK(cbef::setSetting(request.settings, "blur", 0.0), "test must keep the dummy result neutral");
        const std::array<float, 4> source = {-0.125F, 0.18F, 4.0F, 0.625F};
        std::memcpy(pixel(frame.source, frame, 5, -3), source.data(), kRgbaBytes);
        CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
              "non-identity colour roundtrip must complete");
        for (int channel = 0; channel < 3; ++channel) {
            CHECK(std::isfinite(pixel(frame.destination, frame, 5, -3)[channel]),
                  "finite HDR input must remain finite");
            CHECK(std::abs(pixel(frame.destination, frame, 5, -3)[channel] - source[static_cast<std::size_t>(channel)]) <
                      2.0e-6F,
                  "Working Mode decode and encode must preserve signed HDR RGB");
        }
        std::uint32_t source_alpha = 0;
        std::uint32_t destination_alpha = 0;
        std::memcpy(&source_alpha, &source[3], sizeof(source_alpha));
        std::memcpy(&destination_alpha, &pixel(frame.destination, frame, 5, -3)[3], sizeof(destination_alpha));
        CHECK(source_alpha == destination_alpha, "colour conversion must not transform alpha");
    }
    return 0;
}

#if defined(CBEF_ENABLE_METAL_TEST)
int testMetalParity()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "Apple Silicon Metal device is required for M1 verification");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "Metal command queue creation must succeed");

        CpuFrame cpu_frame;
        CpuFrame metal_frame;
        for (std::size_t byte = 0; byte < cpu_frame.source.size(); ++byte) {
            cpu_frame.source[byte] = static_cast<std::uint8_t>((byte * 29U) & 0xFFU);
            metal_frame.source[byte] = cpu_frame.source[byte];
        }
        std::fill(cpu_frame.destination.begin(), cpu_frame.destination.end(), kDestinationSentinel);
        std::fill(metal_frame.destination.begin(), metal_frame.destination.end(), kDestinationSentinel);
        for (int y = cpu_frame.bounds.y; y < cpu_frame.bounds.y + cpu_frame.bounds.height; ++y) {
            for (int x = cpu_frame.bounds.x; x < cpu_frame.bounds.x + cpu_frame.bounds.width; ++x) {
                float* cpu_pixel = pixel(cpu_frame.source, cpu_frame, x, y);
                float* metal_pixel = pixel(metal_frame.source, metal_frame, x, y);
                const float red = x == cpu_frame.bounds.x ? -0.1F : 1.8F;
                const float alpha = x == cpu_frame.bounds.x + 2 ? 0.0F : 0.75F;
                cpu_pixel[0] = metal_pixel[0] = red;
                cpu_pixel[1] = metal_pixel[1] = 0.22F;
                cpu_pixel[2] = metal_pixel[2] = 2.4F;
                cpu_pixel[3] = metal_pixel[3] = alpha;
            }
        }

        CpuRenderBackend cpu_backend;
        RenderRequest cpu_request = requestFor(cpu_frame, EffectId::LensReflections);
        cpu_request.render_window = RectI{6, -2, 7, -1};
        CHECK(cbef::setSetting(cpu_request.settings, "amount", 125.0), "test must make Metal workload non-identity");
        CHECK(cbef::setSetting(cpu_request.settings, "mix", 73.0), "test must select fractional Mix");
        CHECK(cbef::setSetting(cpu_request.settings, "working_mode", 2), "test must select Rec.709 Gamma 2.4");
        cpu_request.alpha_association = AlphaAssociation::Premultiplied;
        CHECK(cbef::render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
              "CPU reference must complete before Metal parity check");

        const NSUInteger length = static_cast<NSUInteger>(metal_frame.source.size());
        id<MTLBuffer> source = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "Metal frame buffers must allocate");
        std::memcpy(source.contents, metal_frame.source.data(), metal_frame.source.size());
        std::memset(destination.contents, kDestinationSentinel, metal_frame.destination.size());

        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                            (__bridge void*)source, 0U, metal_frame.row_bytes,
                                            metal_frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, metal_frame.row_bytes,
                                                 metal_frame.bounds};
        MetalRenderBackend metal_backend((__bridge void*)queue);
        const RenderSubmission submission = cbef::render(metal_request, metal_backend);
        CHECK(submission.kind == SubmissionKind::Enqueued,
              "Metal must return Enqueued after committing work to the supplied queue");

        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "sentinel command buffer must be created on the same host queue");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted,
              "same-queue sentinel must make the Metal destination readable");
        std::memcpy(metal_frame.destination.data(), destination.contents, metal_frame.destination.size());

        float max_error = 0.0F;
        for (int y = metal_request.render_window.y1; y < metal_request.render_window.y2; ++y) {
            for (int x = metal_request.render_window.x1; x < metal_request.render_window.x2; ++x) {
                const float* expected = pixel(cpu_frame.destination, cpu_frame, x, y);
                const float* actual = pixel(metal_frame.destination, metal_frame, x, y);
                for (int channel = 0; channel < 3; ++channel) {
                    CHECK(std::isfinite(actual[channel]), "Metal output must remain finite for finite input");
                    max_error = std::max(max_error, std::abs(expected[channel] - actual[channel]));
                }
                std::uint32_t expected_alpha = 0;
                std::uint32_t actual_alpha = 0;
                std::memcpy(&expected_alpha, &expected[3], sizeof(expected_alpha));
                std::memcpy(&actual_alpha, &actual[3], sizeof(actual_alpha));
                CHECK(expected_alpha == actual_alpha, "Metal must preserve alpha bits exactly");
            }
        }
        CHECK(max_error <= 2.0e-4F, "CPU and actual Metal output must meet the M1 parity tolerance");
        const std::size_t changed_start = metal_frame.row_bytes + kRgbaBytes;
        const std::size_t changed_end = changed_start + kRgbaBytes;
        for (std::size_t byte = 0; byte < metal_frame.destination.size(); ++byte) {
            if (byte < changed_start || byte >= changed_end) {
                CHECK(metal_frame.destination[byte] == kDestinationSentinel,
                      "Metal must preserve bytes outside the destination window");
            }
        }

        std::memset(destination.contents, kDestinationSentinel, metal_frame.destination.size());
        CHECK(cbef::setSetting(metal_request.settings, "amount", 0.0),
              "test must select the Metal identity path");
        CHECK(cbef::render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "Metal identity must enqueue its supplied host queue");
        sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "identity sentinel command buffer must be created on the same host queue");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted,
              "same-queue sentinel must make the Metal identity destination readable");
        std::memcpy(metal_frame.destination.data(), destination.contents, metal_frame.destination.size());
        for (int channel = 0; channel < 4; ++channel) {
            std::uint32_t expected = 0;
            std::uint32_t actual = 0;
            std::memcpy(&expected, &pixel(metal_frame.source, metal_frame, 6, -2)[channel], sizeof(expected));
            std::memcpy(&actual, &pixel(metal_frame.destination, metal_frame, 6, -2)[channel], sizeof(actual));
            CHECK(expected == actual, "Metal identity must preserve every RGBA bit");
        }
        for (std::size_t byte = 0; byte < metal_frame.destination.size(); ++byte) {
            if (byte < changed_start || byte >= changed_end) {
                CHECK(metal_frame.destination[byte] == kDestinationSentinel,
                      "Metal identity must preserve bytes outside the destination window");
            }
        }
    }
    return 0;
}
#endif

}

int main()
{
    if (const int result = testEffectDefinitions(); result != 0) {
        return result;
    }
    if (const int result = testInvalidRequests(); result != 0) {
        return result;
    }
    if (const int result = testExactIdentityCopy(); result != 0) {
        return result;
    }
    if (const int result = testAlphaAndDiagnosticOrdering(); result != 0) {
        return result;
    }
    if (const int result = testColourRoundTrips(); result != 0) {
        return result;
    }
#if defined(CBEF_ENABLE_METAL_TEST)
    if (const int result = testMetalParity(); result != 0) {
        return result;
    }
#endif
#if defined(CBEF_ENABLE_METAL_TEST)
    std::puts("headless_render_contract: PASS (CPU + Metal M1 contract)");
#else
    std::puts("headless_render_contract: PASS (CPU M1 contract)");
#endif
    return 0;
}
