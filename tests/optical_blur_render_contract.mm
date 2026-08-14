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
constexpr std::uint8_t kSentinel = 0xA5U;

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    Frame(int width, int height, int x = 0, int y = 0)
        : bounds{x, y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + 32U)
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
    return reinterpret_cast<const float*>(bytes.data() + static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                          static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes);
}

FrameSurface surface(void* data, const Frame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, frame.bounds};
}

RenderRequest requestFor(Frame& frame)
{
    Settings settings = defaultSettings(EffectId::OpticalBlur);
    // Legacy M5 regression remains a parity baseline; v2 field controls are exercised separately.
    setSetting(settings, "lens_profile", 0);
    setSetting(settings, "bokeh_bias", 0.0);
    setSetting(settings, "cat_eye", 0.0);
    return RenderRequest{EffectId::OpticalBlur,
                         surface(frame.source.data(), frame),
                         surface(frame.destination.data(), frame),
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height},
                         0.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         std::move(settings)};
}

int fail(const char* message)
{
    std::fprintf(stderr, "optical_blur_render_contract: %s\n", message);
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
            float* value_at_pixel = pixel(frame.source, frame, x, y);
            value_at_pixel[0] = value;
            value_at_pixel[1] = value;
            value_at_pixel[2] = value;
            value_at_pixel[3] = alpha;
        }
    }
}

void fillImpulse(Frame& frame, float value = 1.0F)
{
    fill(frame, 0.0F);
    float* impulse = pixel(frame.source, frame, frame.bounds.x + frame.bounds.width / 2,
                           frame.bounds.y + frame.bounds.height / 2);
    impulse[0] = value;
    impulse[1] = value;
    impulse[2] = value;
}

bool setDouble(Settings& settings, const char* id, double value)
{
    return setSetting(settings, id, value);
}

void disableV2FieldControls(Settings& settings)
{
    setSetting(settings, "lens_profile", 0);
    setDouble(settings, "bokeh_bias", 0.0);
    setDouble(settings, "cat_eye", 0.0);
    setDouble(settings, "vignetting", 0.0);
    setDouble(settings, "coma", 0.0);
    setDouble(settings, "astigmatism", 0.0);
    setDouble(settings, "field_curvature", 0.0);
    setDouble(settings, "chromatic_aberration", 0.0);
    setSetting(settings, "quality", 1);
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

double luminanceAt(const Frame& frame, int x, int y)
{
    const float* value = pixel(frame.destination, frame, x, y);
    return std::max(0.0, 0.27411851 * std::max(0.0F, value[0]) + 0.87363190 * std::max(0.0F, value[1]) -
                              0.14775041 * std::max(0.0F, value[2]));
}

bool analyticApertureContains(double x, double y, int blades, double curvature, double rotation)
{
    const double radius = std::sqrt(x * x + y * y);
    if (radius > 1.0) return false;
    const double pi = std::acos(-1.0);
    const double sector = 2.0 * pi / static_cast<double>(std::clamp(blades, 3, 16));
    double angle = std::fmod(std::atan2(y, x) - rotation * pi / 180.0, sector);
    if (angle < 0.0) angle += sector;
    angle = std::abs(angle - 0.5 * sector);
    const double polygon_radius = std::cos(0.5 * sector) / std::max(std::cos(angle), 1.0e-9);
    const double blend = std::clamp(curvature / 100.0, 0.0, 1.0);
    return radius <= polygon_radius * (1.0 - blend) + blend;
}

int testDefinitionAndIdentity()
{
    const EffectDefinition& definition = effectDefinition(EffectId::OpticalBlur);
    CHECK(definition.parameters.size() == 19U, "Optical Blur definition must contain four common and fifteen effect parameters");
    CHECK(definition.presets.size() == 3U, "Optical Blur must expose three presets");
    CHECK(settingsUsePreset(defaultSettings(EffectId::OpticalBlur)), "default settings must match the default preset");
    Settings anamorphic = settingsForPreset(EffectId::OpticalBlur, 2U);
    CHECK(std::get<std::int64_t>(settingValue(anamorphic, "blades")) == 8 &&
              std::abs(std::get<double>(settingValue(anamorphic, "anamorphism")) - 2.0) < 1.0e-8,
          "Anamorphic preset must expand all aperture parameters");

    Frame frame(3, 2, 4, -2);
    fill(frame, 0.2F);
    const std::array<std::uint32_t, 4> original = {0x7FC01234U, 0xBF800000U, 0x3F400000U, 0x00000000U};
    std::memcpy(pixel(frame.source, frame, 4, -2), original.data(), kPixelBytes);
    Settings identity = defaultSettings(EffectId::OpticalBlur);
    disableV2FieldControls(identity);
    CHECK(setDouble(identity, "mix", 0.0), "Mix zero must be accepted");
    CHECK(render(frame, identity), "Optical Blur identity render must complete");
    std::array<std::uint32_t, 4> copied{};
    std::memcpy(copied.data(), pixel(frame.destination, frame, 4, -2), kPixelBytes);
    CHECK(copied == original, "Optical Blur identity must preserve every source bit");

    Settings blur_zero = defaultSettings(EffectId::OpticalBlur);
    disableV2FieldControls(blur_zero);
    CHECK(setDouble(blur_zero, "blur", 0.0) && render(frame, blur_zero), "Blur zero identity must complete");
    std::memcpy(copied.data(), pixel(frame.destination, frame, 4, -2), kPixelBytes);
    CHECK(copied == original, "Blur zero must preserve every source bit");
    return 0;
}

int testKernelAndAnamorphism()
{
    Frame constant(97, 73);
    fill(constant, 0.31F);
    Settings constant_settings = defaultSettings(EffectId::OpticalBlur);
    disableV2FieldControls(constant_settings);
    CHECK(setSetting(constant_settings, "working_mode", 1) && setDouble(constant_settings, "blur", 3.0) &&
              setDouble(constant_settings, "highlight_response", 0.0) && render(constant, constant_settings),
          "constant aperture render must complete");
    for (int y = 0; y < constant.bounds.height; ++y) {
        for (int x = 0; x < constant.bounds.width; ++x) {
            CHECK(std::abs(pixel(constant.destination, constant, x, y)[0] - 0.31F) <= 1.0e-5F,
                  "unit-sum aperture must preserve a constant image");
        }
    }

    Frame impulse(129, 129);
    fillImpulse(impulse);
    Settings settings = defaultSettings(EffectId::OpticalBlur);
    disableV2FieldControls(settings);
    CHECK(setSetting(settings, "working_mode", 1) && setDouble(settings, "blur", 4.0) &&
              setDouble(settings, "highlight_response", 0.0) && setSetting(settings, "output_view", 1) &&
              setDouble(settings, "anamorphism", 2.0) && render(impulse, settings),
          "anamorphic aperture render must complete");
    const double center_x = impulse.bounds.x + impulse.bounds.width / 2;
    const double center_y = impulse.bounds.y + impulse.bounds.height / 2;
    double sum = 0.0;
    double first_x = 0.0;
    double first_y = 0.0;
    double second_x = 0.0;
    double second_y = 0.0;
    for (int y = impulse.bounds.y; y < impulse.bounds.y + impulse.bounds.height; ++y) {
        for (int x = impulse.bounds.x; x < impulse.bounds.x + impulse.bounds.width; ++x) {
            const double weight = luminanceAt(impulse, x, y);
            const double dx = x - center_x;
            const double dy = y - center_y;
            sum += weight;
            first_x += dx * weight;
            first_y += dy * weight;
            second_x += dx * dx * weight;
            second_y += dy * dy * weight;
        }
    }
    CHECK(std::abs(sum - 1.0) <= 1.0e-5, "aperture kernel must have unit sum");
    CHECK(std::abs(first_x / sum) <= 0.05 && std::abs(first_y / sum) <= 0.05,
          "aperture kernel centroid must remain centered");
    CHECK(std::abs(std::sqrt(second_x / second_y) - 2.0) <= 0.08,
          "aperture second moment must track anamorphism");
    return 0;
}

int testAnalyticMaskAndScaledPsnr()
{
    Frame mask(161, 161);
    fillImpulse(mask);
    Settings mask_settings = defaultSettings(EffectId::OpticalBlur);
    disableV2FieldControls(mask_settings);
    CHECK(setSetting(mask_settings, "working_mode", 1) && setDouble(mask_settings, "blur", 4.0) &&
              setDouble(mask_settings, "curvature", 0.0) && setSetting(mask_settings, "blades", std::int64_t{7}) &&
              setDouble(mask_settings, "rotation", 19.0) && setDouble(mask_settings, "highlight_response", 0.0) &&
              setSetting(mask_settings, "output_view", 1),
          "analytic aperture fixture settings must be accepted");
    CHECK(render(mask, mask_settings), "analytic aperture fixture must render");
    const double center_x = mask.bounds.x + mask.bounds.width / 2;
    const double center_y = mask.bounds.y + mask.bounds.height / 2;
    const double radius_y = static_cast<double>(mask.bounds.height) * 4.0 / 100.0;
    std::size_t intersection = 0U;
    std::size_t union_count = 0U;
    for (int y = mask.bounds.y; y < mask.bounds.y + mask.bounds.height; ++y) {
        for (int x = mask.bounds.x; x < mask.bounds.x + mask.bounds.width; ++x) {
            const bool actual = luminanceAt(mask, x, y) > 1.0e-8;
            const double px = (x - center_x) / radius_y;
            const double py = (y - center_y) / radius_y;
            bool target = false;
            for (int sy = 0; sy < 4 && !target; ++sy) {
                for (int sx = 0; sx < 4; ++sx) {
                    const double sample_x = -px + (static_cast<double>(sx) + 0.5) / (4.0 * radius_y) -
                                            0.5 / radius_y;
                    const double sample_y = -py + (static_cast<double>(sy) + 0.5) / (4.0 * radius_y) -
                                            0.5 / radius_y;
                    if (analyticApertureContains(sample_x, sample_y, 7, 0.0, 19.0)) {
                        target = true;
                        break;
                    }
                }
            }
            if (actual && target) ++intersection;
            if (actual || target) ++union_count;
        }
    }
    CHECK(union_count != 0U && static_cast<double>(intersection) / static_cast<double>(union_count) >= 0.95,
          "binary aperture support must match analytic polygon mask");

    Frame low(32, 1080);
    Frame high(64, 2160);
    for (int y = low.bounds.y; y < low.bounds.y + low.bounds.height; ++y) {
        for (int x = low.bounds.x; x < low.bounds.x + low.bounds.width; ++x) {
            const float value = static_cast<float>(0.10 + 0.0002 * y + 0.002 * x);
            float* output = pixel(low.source, low, x, y);
            output[0] = value;
            output[1] = value;
            output[2] = value;
            output[3] = 1.0F;
        }
    }
    for (int y = high.bounds.y; y < high.bounds.y + high.bounds.height; ++y) {
        for (int x = high.bounds.x; x < high.bounds.x + high.bounds.width; ++x) {
            const float value = static_cast<float>(0.10 + 0.0002 * (y * 0.5) + 0.002 * (x * 0.5));
            float* output = pixel(high.source, high, x, y);
            output[0] = value;
            output[1] = value;
            output[2] = value;
            output[3] = 1.0F;
        }
    }
    Settings low_settings = defaultSettings(EffectId::OpticalBlur);
    disableV2FieldControls(low_settings);
    Settings high_settings = low_settings;
    CHECK(setSetting(low_settings, "working_mode", 1) && setSetting(high_settings, "working_mode", 1) &&
              setDouble(low_settings, "blur", 0.30) && setDouble(high_settings, "blur", 0.30) &&
              setDouble(low_settings, "highlight_response", 0.0) && setDouble(high_settings, "highlight_response", 0.0) &&
              setSetting(low_settings, "output_view", 1) && setSetting(high_settings, "output_view", 1) &&
              render(low, low_settings) && render(high, high_settings),
          "1080 and 2160 aperture renders must complete");
    double mse = 0.0;
    double low_energy = 0.0;
    double high_energy = 0.0;
    for (int y = 0; y < low.bounds.height; ++y) {
        for (int x = 0; x < low.bounds.width; ++x) {
            const double low_value = luminanceAt(low, x, y);
            const double high_value = (luminanceAt(high, 2 * x, 2 * y) + luminanceAt(high, 2 * x + 1, 2 * y) +
                                       luminanceAt(high, 2 * x, 2 * y + 1) + luminanceAt(high, 2 * x + 1, 2 * y + 1)) /
                                      4.0;
            const double delta = low_value - high_value;
            mse += delta * delta;
            low_energy += low_value;
            high_energy += high_value;
        }
    }
    mse /= static_cast<double>(low.bounds.width * low.bounds.height);
    CHECK(mse > 0.0 && 10.0 * std::log10(1.0 / mse) >= 45.0, "1080/4K aperture PSNR must exceed 45 dB");
    CHECK(std::abs(low_energy - high_energy) / low_energy <= 0.01, "1080/4K aperture energy must remain stable");

    Frame low_impulse(32, 1080);
    Frame high_impulse(64, 2160);
    fillImpulse(low_impulse);
    fillImpulse(high_impulse);
    CHECK(render(low_impulse, low_settings) && render(high_impulse, high_settings),
          "1080 and 2160 impulse renders must complete");
    double low_second = 0.0;
    double high_second = 0.0;
    for (int y = 0; y < low_impulse.bounds.height; ++y) {
        for (int x = 0; x < low_impulse.bounds.width; ++x) {
            low_second += (y - low_impulse.bounds.height / 2.0) * (y - low_impulse.bounds.height / 2.0) *
                          luminanceAt(low_impulse, x, y);
        }
    }
    for (int y = 0; y < high_impulse.bounds.height; ++y) {
        for (int x = 0; x < high_impulse.bounds.width; ++x) {
            high_second += (y - high_impulse.bounds.height / 2.0) * (y - high_impulse.bounds.height / 2.0) *
                           luminanceAt(high_impulse, x, y);
        }
    }
    CHECK(std::abs(std::sqrt(high_second / low_second) / 2.0 - 1.0) <= 0.02,
          "1080/4K aperture radius must remain canonical");
    return 0;
}

int testHighlightAlphaHdrAndResolution()
{
    std::array<double, 3> energy{};
    for (int index = 0; index < 3; ++index) {
        Frame frame(65, 65);
        fillImpulse(frame, 4.0F);
        Settings settings = defaultSettings(EffectId::OpticalBlur);
        disableV2FieldControls(settings);
        CHECK(setSetting(settings, "working_mode", 1) && setDouble(settings, "blur", 3.0) &&
                  setDouble(settings, "highlight_response", static_cast<double>(index * 100)) &&
                  setSetting(settings, "output_view", 2) && render(frame, settings),
              "highlight component render must complete");
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                energy[static_cast<std::size_t>(index)] += luminanceAt(frame, x, y);
            }
        }
    }
    CHECK(energy[0] <= energy[1] + 1.0e-6 && energy[1] <= energy[2] + 1.0e-6,
          "highlight component energy must be monotonic with response");

    Frame frame(11, 5, -3, 7);
    fill(frame, -0.25F);
    float* hdr = pixel(frame.source, frame, 2, 9);
    hdr[0] = 2.5F;
    hdr[1] = 1.5F;
    hdr[2] = -0.25F;
    hdr[3] = 1.0F;
    float* transparent = pixel(frame.source, frame, -2, 8);
    transparent[0] = 100.0F;
    transparent[1] = 50.0F;
    transparent[2] = 25.0F;
    transparent[3] = 0.0F;
    Settings settings = defaultSettings(EffectId::OpticalBlur);
    disableV2FieldControls(settings);
    CHECK(setSetting(settings, "working_mode", 1) && setDouble(settings, "blur", 2.0) && render(frame, settings),
          "HDR and alpha render must complete");
    CHECK(std::isfinite(pixel(frame.destination, frame, 2, 9)[2]), "HDR output must remain finite");
    CHECK(std::abs(pixel(frame.destination, frame, -2, 8)[0]) <= 1.0e-6F,
          "transparent hidden RGB must not leak");
    CHECK(pixel(frame.destination, frame, 2, 9)[3] == 1.0F && pixel(frame.destination, frame, -2, 8)[3] == 0.0F,
          "alpha must be preserved");

    Frame low(96, 64);
    Frame high(192, 128);
    fillImpulse(low);
    fillImpulse(high);
    Settings low_settings = defaultSettings(EffectId::OpticalBlur);
    disableV2FieldControls(low_settings);
    Settings high_settings = low_settings;
    CHECK(setSetting(low_settings, "working_mode", 1) && setSetting(high_settings, "working_mode", 1) &&
              setDouble(low_settings, "blur", 3.0) && setDouble(high_settings, "blur", 3.0) &&
              setDouble(low_settings, "highlight_response", 0.0) && setDouble(high_settings, "highlight_response", 0.0) &&
              setSetting(low_settings, "output_view", 1) && setSetting(high_settings, "output_view", 1) &&
              render(low, low_settings) && render(high, high_settings),
          "scaled aperture renders must complete");
    double low_energy = 0.0;
    double high_energy = 0.0;
    for (int y = 0; y < low.bounds.height; ++y) {
        for (int x = 0; x < low.bounds.width; ++x) low_energy += luminanceAt(low, x, y);
    }
    for (int y = 0; y < high.bounds.height; ++y) {
        for (int x = 0; x < high.bounds.width; ++x) high_energy += luminanceAt(high, x, y);
    }
    CHECK(std::abs(low_energy - high_energy) / low_energy <= 0.03, "scaled aperture energy must remain stable");
    return 0;
}

#if defined(CBEF_ENABLE_METAL_TEST)
int testMetalParityAndCrop()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "a Metal device is required for Optical Blur parity");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "a Metal command queue is required for Optical Blur parity");

        Frame frame(37, 29, -5, 7);
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                float* value = pixel(frame.source, frame, x, y);
                value[0] = static_cast<float>(0.15 + 0.01 * (x - frame.bounds.x));
                value[1] = static_cast<float>(0.20 + 0.005 * (y - frame.bounds.y));
                value[2] = static_cast<float>(0.10 + 0.002 * (x + y));
                value[3] = 0.75F;
            }
        }
        float* highlight = pixel(frame.source, frame, frame.bounds.x + 18, frame.bounds.y + 12);
        highlight[0] = 3.0F;
        highlight[1] = 2.0F;
        highlight[2] = 1.0F;
        float* hidden = pixel(frame.source, frame, frame.bounds.x + 2, frame.bounds.y + 2);
        hidden[0] = 50.0F;
        hidden[1] = 20.0F;
        hidden[2] = 10.0F;
        hidden[3] = 0.0F;

        RenderRequest cpu_request = requestFor(frame);
        cpu_request.render_window = RectI{frame.bounds.x + 3, frame.bounds.y + 4,
                                          frame.bounds.x + frame.bounds.width - 2,
                                          frame.bounds.y + frame.bounds.height - 3};
        CHECK(setSetting(cpu_request.settings, "working_mode", 1) &&
                  setDouble(cpu_request.settings, "blur", 2.4) &&
                  setSetting(cpu_request.settings, "blades", std::int64_t{7}) &&
                  setDouble(cpu_request.settings, "curvature", 15.0) &&
                  setDouble(cpu_request.settings, "rotation", 23.0) &&
                  setDouble(cpu_request.settings, "anamorphism", 1.6) &&
                  setDouble(cpu_request.settings, "highlight_response", 80.0) &&
                  setSetting(cpu_request.settings, "lens_profile", 0) &&
                  setDouble(cpu_request.settings, "bokeh_bias", 0.0) &&
                  setDouble(cpu_request.settings, "cat_eye", 0.0),
              "Optical Blur parity settings must be accepted");
        cpu_request.alpha_association = AlphaAssociation::Premultiplied;
        CpuRenderBackend cpu_backend;
        CHECK(cbef::render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
              "CPU Optical Blur reference must complete");

        const NSUInteger length = static_cast<NSUInteger>(frame.source.size());
        id<MTLBuffer> source = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "Metal Optical Blur buffers must allocate");
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, kSentinel, frame.destination.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)source,
                                            0U, frame.row_bytes, frame.bounds};
        metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                 (__bridge void*)destination, 0U, frame.row_bytes, frame.bounds};
        MetalRenderBackend metal_backend((__bridge void*)queue);
        CHECK(cbef::render(metal_request, metal_backend).kind == SubmissionKind::Enqueued,
              "Metal Optical Blur must submit to the host queue");
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "same-queue sentinel must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted, "same-queue sentinel must complete");

        float maximum_error = 0.0F;
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                const float* expected = pixel(frame.destination, frame, x, y);
                const float* actual = metalPixel(destination.contents, frame, x, y);
                const bool in_window = x >= cpu_request.render_window.x1 && x < cpu_request.render_window.x2 &&
                                       y >= cpu_request.render_window.y1 && y < cpu_request.render_window.y2;
                if (in_window) {
                    for (int channel = 0; channel < 3; ++channel) {
                        maximum_error = std::max(maximum_error, std::abs(expected[channel] - actual[channel]));
                    }
                    CHECK(std::memcmp(&expected[3], &actual[3], sizeof(float)) == 0,
                          "Optical Blur Metal must preserve alpha bits");
                } else {
                    const auto* row = static_cast<const std::uint8_t*>(destination.contents) +
                                      static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes;
                    CHECK(row[static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes] == kSentinel,
                          "Optical Blur must preserve destination bytes outside the crop");
                }
            }
        }
        CHECK(maximum_error <= 2.0e-4F, "CPU and Metal Optical Blur must agree within 2e-4");
        [source release];
        [destination release];
        [queue release];
    }
    return 0;
}

int testV2MetalModelMatrix()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "a Metal device is required for the v2 Optical matrix");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "a Metal queue is required for the v2 Optical matrix");
        Frame frame(65, 61, -7, 5);
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                float* value = pixel(frame.source, frame, x, y);
                const float u = static_cast<float>(x - frame.bounds.x) / static_cast<float>(frame.bounds.width - 1);
                const float v = static_cast<float>(y - frame.bounds.y) / static_cast<float>(frame.bounds.height - 1);
                value[0] = -0.35F + 1.7F * u + 0.15F * std::sin(17.0F * v);
                value[1] = 0.08F + 2.1F * v;
                value[2] = 1.4F - 1.8F * u + 0.2F * std::cos(13.0F * v);
                value[3] = 0.35F + 0.65F * (0.25F + 0.75F * u);
            }
        }
        float* transparent = pixel(frame.source, frame, frame.bounds.x, frame.bounds.y + frame.bounds.height / 2);
        transparent[0] = 40.0F;
        transparent[1] = -20.0F;
        transparent[2] = 10.0F;
        transparent[3] = 0.0F;
        const NSUInteger length = static_cast<NSUInteger>(frame.source.size());
        id<MTLBuffer> source = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:length options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "v2 Optical matrix buffers must allocate");
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        const RectI crop{frame.bounds.x + 3, frame.bounds.y + 4,
                         frame.bounds.x + frame.bounds.width - 2,
                         frame.bounds.y + frame.bounds.height - 3};
        double total_error = 0.0;
        std::size_t compared = 0U;
        float maximum_error = 0.0F;
        for (int quality = 0; quality < 3; ++quality) {
            for (int view = 0; view < 5; ++view) {
                Settings settings = defaultSettings(EffectId::OpticalBlur);
                CHECK(setSetting(settings, "working_mode", 1) && setDouble(settings, "blur", 4.0) &&
                          setSetting(settings, "blades", std::int64_t{7}) && setDouble(settings, "curvature", 35.0) &&
                          setDouble(settings, "rotation", 31.0) && setDouble(settings, "anamorphism", 1.8) &&
                          setDouble(settings, "highlight_response", 75.0) && setSetting(settings, "lens_profile", 2) &&
                          setDouble(settings, "bokeh_bias", 28.0) && setDouble(settings, "cat_eye", 62.0) &&
                          setDouble(settings, "vignetting", 35.0) && setDouble(settings, "coma", 48.0) &&
                          setDouble(settings, "astigmatism", 41.0) && setDouble(settings, "field_curvature", 33.0) &&
                          setDouble(settings, "chromatic_aberration", 55.0) && setSetting(settings, "quality", quality) &&
                          setSetting(settings, "output_view", view),
                      "v2 Optical matrix settings must be accepted");
                std::fill(frame.destination.begin(), frame.destination.end(), kSentinel);
                RenderRequest cpu_request = requestFor(frame);
                cpu_request.render_window = crop;
                cpu_request.settings = settings;
                CpuRenderBackend cpu_backend;
                CHECK(cbef::render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
                      "v2 Optical CPU matrix render must complete");
                std::memset(destination.contents, kSentinel, frame.destination.size());
                RenderRequest metal_request = cpu_request;
                metal_request.source = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                    (__bridge void*)source, 0U, frame.row_bytes, frame.bounds};
                metal_request.destination = FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32,
                                                         (__bridge void*)destination, 0U, frame.row_bytes, frame.bounds};
                MetalRenderBackend backend((__bridge void*)queue);
                CHECK(cbef::render(metal_request, backend).kind == SubmissionKind::Enqueued,
                      "v2 Optical Metal matrix render must enqueue");
                id<MTLCommandBuffer> sentinel = [queue commandBuffer];
                CHECK(sentinel != nil, "v2 Optical matrix sentinel must allocate");
                [sentinel commit];
                [sentinel waitUntilCompleted];
                CHECK(sentinel.status == MTLCommandBufferStatusCompleted,
                      "v2 Optical matrix command stream must complete");
                for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
                    for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                        const bool inside = x >= crop.x1 && x < crop.x2 && y >= crop.y1 && y < crop.y2;
                        if (!inside) {
                            const auto* row = static_cast<const std::uint8_t*>(destination.contents) +
                                static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes;
                            CHECK(row[static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes] == kSentinel,
                                  "v2 Optical must retain crop sentinels");
                            continue;
                        }
                        const float* expected = pixel(frame.destination, frame, x, y);
                        const float* actual = metalPixel(destination.contents, frame, x, y);
                        for (int channel = 0; channel < 3; ++channel) {
                            const float error = std::abs(expected[channel] - actual[channel]);
                            CHECK(std::isfinite(actual[channel]), "v2 Optical Metal output must remain finite");
                            maximum_error = std::max(maximum_error, error);
                            total_error += error;
                            ++compared;
                        }
                        CHECK(std::memcmp(&expected[3], &actual[3], sizeof(float)) == 0,
                              "v2 Optical Metal must preserve alpha bits");
                    }
                }
            }
        }
        const double mean_error = total_error / static_cast<double>(compared);
        CHECK(maximum_error <= 2.0e-4F && mean_error <= 2.0e-5,
              "v2 Optical CPU and Metal matrix must satisfy maximum and mean parity");
        std::printf("v2 optical parity max=%.8f mean=%.8f\n", maximum_error, mean_error);
        [source release];
        [destination release];
        [queue release];
    }
    return 0;
}

int testV2EightKCrop()
{
    @autoreleasepool {
        constexpr int width = 7680;
        constexpr int height = 4320;
        constexpr std::size_t row_bytes = static_cast<std::size_t>(width) * kPixelBytes;
        constexpr std::size_t byte_length = row_bytes * static_cast<std::size_t>(height);
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "a Metal device is required for the 8K Optical crop");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLBuffer> source = [device newBufferWithLength:byte_length options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:byte_length options:MTLResourceStorageModeShared];
        CHECK(queue != nil && source != nil && destination != nil, "8K Optical buffers must allocate");
        std::memset(source.contents, 0, byte_length);
        std::memset(destination.contents, kSentinel, byte_length);
        auto* source_values = static_cast<float*>(source.contents);
        const std::size_t pixel_count = static_cast<std::size_t>(width) * static_cast<std::size_t>(height);
        for (std::size_t index = 0; index < pixel_count; ++index) source_values[4U * index + 3U] = 1.0F;
        const std::size_t center = static_cast<std::size_t>(height / 2) * static_cast<std::size_t>(width) + width / 2;
        source_values[4U * center + 0U] = 4.0F;
        source_values[4U * center + 1U] = 2.0F;
        source_values[4U * center + 2U] = -0.5F;
        Settings settings = defaultSettings(EffectId::OpticalBlur);
        CHECK(setSetting(settings, "working_mode", 1) && setDouble(settings, "blur", 0.25) &&
                  setSetting(settings, "lens_profile", 3) && setDouble(settings, "cat_eye", 55.0) &&
                  setDouble(settings, "coma", 35.0) && setDouble(settings, "astigmatism", 30.0) &&
                  setDouble(settings, "field_curvature", 25.0) &&
                  setDouble(settings, "chromatic_aberration", 20.0) && setSetting(settings, "quality", 0),
              "8K Optical settings must be accepted");
        const DataWindow bounds{0, 0, width, height};
        const RectI crop{width / 2 - 16, height / 2 - 16, width / 2 + 16, height / 2 + 16};
        RenderRequest request{EffectId::OpticalBlur,
                              FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)source,
                                           0U, row_bytes, bounds},
                              FrameSurface{MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)destination,
                                           0U, row_bytes, bounds},
                              crop, 0.0, RenderScale{1.0, 1.0}, AlphaAssociation::Straight, settings};
        MetalRenderBackend backend((__bridge void*)queue);
        CHECK(cbef::render(request, backend).kind == SubmissionKind::Enqueued,
              "8K Optical crop must enqueue on Metal");
        id<MTLCommandBuffer> sentinel = [queue commandBuffer];
        CHECK(sentinel != nil, "8K Optical sentinel must allocate");
        [sentinel commit];
        [sentinel waitUntilCompleted];
        CHECK(sentinel.status == MTLCommandBufferStatusCompleted, "8K Optical crop must complete");
        const auto* destination_values = static_cast<const float*>(destination.contents);
        CHECK(std::isfinite(destination_values[4U * center + 0U]) &&
                  std::isfinite(destination_values[4U * center + 1U]) &&
                  std::isfinite(destination_values[4U * center + 2U]) &&
                  destination_values[4U * center + 3U] == 1.0F,
              "8K Optical crop must remain finite and preserve alpha");
        const auto* destination_bytes = static_cast<const std::uint8_t*>(destination.contents);
        CHECK(destination_bytes[0] == kSentinel, "8K Optical crop must preserve bytes outside the render window");
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
    if (testDefinitionAndIdentity() != 0) return 1;
    if (testKernelAndAnamorphism() != 0) return 1;
    if (testAnalyticMaskAndScaledPsnr() != 0) return 1;
    if (testHighlightAlphaHdrAndResolution() != 0) return 1;
#if defined(CBEF_ENABLE_METAL_TEST)
    if (testMetalParityAndCrop() != 0) return 1;
    if (testV2MetalModelMatrix() != 0) return 1;
    if (testV2EightKCrop() != 0) return 1;
#endif
#if defined(CBEF_ENABLE_METAL_TEST)
    std::puts("optical_blur_render_contract: PASS (CPU + Metal M5 Optical Blur)");
#else
    std::puts("optical_blur_render_contract: PASS");
#endif
    return 0;
}
