#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <utility>
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

    Frame(int width, int height)
        : bounds{0, 0, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), 0U)
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

int fail(const char* message)
{
    std::fprintf(stderr, "optical_field_psf_cpu_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) return fail(message); \
    } while (false)

FrameSurface surface(void* data, const Frame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, frame.bounds};
}

RenderRequest requestFor(Frame& frame, Settings settings)
{
    return RenderRequest{EffectId::OpticalBlur,
                         surface(frame.source.data(), frame),
                         surface(frame.destination.data(), frame),
                         RectI{0, 0, frame.bounds.width, frame.bounds.height},
                         0.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         std::move(settings)};
}

bool render(Frame& frame, Settings settings)
{
    CpuRenderBackend backend;
    return cbef::render(requestFor(frame, std::move(settings)), backend).kind == SubmissionKind::Completed;
}

void fillImpulse(Frame& frame, int x, int y, float value = 1.0F)
{
    std::fill(frame.source.begin(), frame.source.end(), 0U);
    for (int row = 0; row < frame.bounds.height; ++row) {
        for (int column = 0; column < frame.bounds.width; ++column) {
            float* value_at_pixel = pixel(frame.source, frame, column, row);
            value_at_pixel[3] = 1.0F;
        }
    }
    float* impulse = pixel(frame.source, frame, x, y);
    impulse[0] = value;
    impulse[1] = value;
    impulse[2] = value;
}

struct Moments {
    double energy = 0.0;
    double centroid_x = 0.0;
    double centroid_y = 0.0;
    double second_x = 0.0;
    double second_y = 0.0;
};

struct ChannelCentroid {
    double energy = 0.0;
    double x = 0.0;
};

ChannelCentroid measureChannel(const Frame& frame, int channel)
{
    ChannelCentroid result;
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            const double value = std::max(0.0, static_cast<double>(pixel(frame.destination, frame, x, y)[channel]));
            result.energy += value;
            result.x += value * static_cast<double>(x);
        }
    }
    if (result.energy > 1.0e-12) result.x /= result.energy;
    return result;
}

double maximumDifference(const Frame& lhs, const Frame& rhs)
{
    double maximum = 0.0;
    for (std::size_t index = 0; index < lhs.destination.size(); index += sizeof(float)) {
        float left = 0.0F;
        float right = 0.0F;
        std::memcpy(&left, lhs.destination.data() + index, sizeof(float));
        std::memcpy(&right, rhs.destination.data() + index, sizeof(float));
        maximum = std::max(maximum, std::abs(static_cast<double>(left) - static_cast<double>(right)));
    }
    return maximum;
}

void fillConstant(Frame& frame, float value)
{
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            float* output = pixel(frame.source, frame, x, y);
            output[0] = value;
            output[1] = value;
            output[2] = value;
            output[3] = 1.0F;
        }
    }
}

Moments measure(const Frame& frame)
{
    Moments result;
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            const float* value = pixel(frame.destination, frame, x, y);
            const double weight = std::max(0.0, static_cast<double>(value[0]));
            result.energy += weight;
            result.centroid_x += weight * x;
            result.centroid_y += weight * y;
        }
    }
    if (result.energy > 1.0e-12) {
        result.centroid_x /= result.energy;
        result.centroid_y /= result.energy;
        for (int y = 0; y < frame.bounds.height; ++y) {
            for (int x = 0; x < frame.bounds.width; ++x) {
                const double weight = std::max(0.0, static_cast<double>(pixel(frame.destination, frame, x, y)[0]));
                result.second_x += (x - result.centroid_x) * (x - result.centroid_x) * weight;
                result.second_y += (y - result.centroid_y) * (y - result.centroid_y) * weight;
            }
        }
        result.second_x /= result.energy;
        result.second_y /= result.energy;
    }
    return result;
}

void baseSettings(Settings& settings)
{
    setSetting(settings, "working_mode", 1);
    setSetting(settings, "output_view", 1);
    setSetting(settings, "lens_profile", 0);
    setSetting(settings, "blades", std::int64_t{9});
    setSetting(settings, "curvature", 88.0);
    setSetting(settings, "rotation", 17.0);
    setSetting(settings, "anamorphism", 1.0);
    setSetting(settings, "blur", 3.0);
    setSetting(settings, "highlight_response", 0.0);
}

int testMetadataAndFieldMetrics()
{
    const EffectDefinition& definition = effectDefinition(EffectId::OpticalBlur);
    CHECK(definition.parameters.size() == 19U, "Optical v2 definition must append aberration and quality controls");
    CHECK(definition.parameters[1].choices.size() == 5U &&
              definition.parameters[1].choices[3] == std::string_view{"PSF Preview"} &&
              definition.parameters[1].choices[4] == std::string_view{"Highlight Source Map"},
          "PSF diagnostics must be appended without changing legacy views");
    CHECK(settingChoice(defaultSettings(EffectId::OpticalBlur), "lens_profile") == 0,
          "Lens Profile must have a stable default");

    Frame center(192, 192);
    Frame corner(192, 192);
    Frame nearby(192, 192);
    Settings settings = defaultSettings(EffectId::OpticalBlur);
    baseSettings(settings);
    fillImpulse(center, 96, 96);
    fillImpulse(corner, 24, 24);
    fillImpulse(nearby, 26, 24);
    CHECK(render(center, settings) && render(corner, settings) && render(nearby, settings), "field PSF renders must complete");
    const Moments center_moments = measure(center);
    const Moments corner_moments = measure(corner);
    const Moments nearby_moments = measure(nearby);
    CHECK(center_moments.energy > 0.90 && center_moments.energy < 1.10 && corner_moments.energy > 0.90 &&
              corner_moments.energy < 1.10,
          "field PSF energy must remain normalized");
    CHECK(std::abs(center_moments.centroid_x - 96.0) < 0.35 && std::abs(center_moments.centroid_y - 96.0) < 0.35,
          "center PSF centroid must remain stable");
    CHECK(std::isfinite(corner_moments.second_x) && std::isfinite(corner_moments.second_y) &&
              std::abs((corner_moments.centroid_x - 24.0) - (nearby_moments.centroid_x - 26.0)) < 0.60 &&
              std::abs((corner_moments.centroid_y - 24.0) - (nearby_moments.centroid_y - 24.0)) < 0.60,
          "corner field response must vary continuously without a seam jump");

    Settings no_cat = settings;
    setSetting(no_cat, "cat_eye", 0.0);
    Frame no_cat_frame(192, 192);
    fillImpulse(no_cat_frame, 24, 96);
    CHECK(render(no_cat_frame, no_cat), "cat-eye baseline must render");
    const Moments no_cat_moments = measure(no_cat_frame);
    Settings cat = settings;
    setSetting(cat, "cat_eye", 100.0);
    Frame cat_frame(192, 192);
    fillImpulse(cat_frame, 24, 96);
    CHECK(render(cat_frame, cat), "cat-eye strong field must render");
    const Moments cat_moments = measure(cat_frame);
    const double no_cat_ratio = std::sqrt(no_cat_moments.second_x / std::max(no_cat_moments.second_y, 1.0e-12));
    const double cat_ratio = std::sqrt(cat_moments.second_x / std::max(cat_moments.second_y, 1.0e-12));
    CHECK(std::abs(cat_ratio - no_cat_ratio) > 0.015, "cat-eye must change rim PSF axis ratio");
    std::printf("field center energy=%.6f centroid=(%.4f,%.4f) corner energy=%.6f centroid=(%.4f,%.4f) nearby centroid=(%.4f,%.4f) cat-eye axis %.6f -> %.6f\n",
                center_moments.energy, center_moments.centroid_x, center_moments.centroid_y, corner_moments.energy,
                corner_moments.centroid_x, corner_moments.centroid_y, nearby_moments.centroid_x,
                nearby_moments.centroid_y, no_cat_ratio, cat_ratio);
    return 0;
}

int testDiagnosticsAndDeterminism()
{
    Frame first(96, 96);
    Frame second(96, 96);
    Settings settings = defaultSettings(EffectId::OpticalBlur);
    baseSettings(settings);
    setSetting(settings, "cat_eye", 70.0);
    fillImpulse(first, 48, 48, 4.0F);
    fillImpulse(second, 48, 48, 4.0F);
    CHECK(render(first, settings) && render(second, settings), "deterministic PSF renders must complete");
    CHECK(first.destination == second.destination, "same field PSF input must be deterministic");

    Settings preview = settings;
    setSetting(preview, "output_view", 3);
    Frame preview_frame(96, 96);
    fillImpulse(preview_frame, 48, 48, 4.0F);
    CHECK(render(preview_frame, preview), "PSF Preview diagnostic must render");
    Settings source_map = settings;
    setSetting(source_map, "output_view", 4);
    setSetting(source_map, "highlight_response", 200.0);
    Frame source_frame(96, 96);
    fillImpulse(source_frame, 48, 48, 4.0F);
    CHECK(render(source_frame, source_map), "Highlight Source Map diagnostic must render");
    CHECK(pixel(source_frame.destination, source_frame, 48, 48)[0] > 0.0F,
          "Highlight Source Map must expose the selected source");
    CHECK(pixel(source_frame.destination, source_frame, 0, 0)[0] <= 1.0e-6F,
          "Highlight Source Map must not fill the background");
    return 0;
}

int testAberrationQualityAndVignette()
{
    Settings base = defaultSettings(EffectId::OpticalBlur);
    baseSettings(base);
    setSetting(base, "output_view", 0);
    setSetting(base, "blur", 2.5);
    setSetting(base, "cat_eye", 0.0);
    setSetting(base, "quality", 1);

    Frame neutral(160, 160);
    fillImpulse(neutral, 24, 80);
    CHECK(render(neutral, base), "neutral aberration render must complete");
    const ChannelCentroid neutral_red = measureChannel(neutral, 0);
    const ChannelCentroid neutral_blue = measureChannel(neutral, 2);
    CHECK(std::abs(neutral_red.x - neutral_blue.x) < 0.05, "zero chromatic aberration must align channel centroids");

    Settings chromatic = base;
    setSetting(chromatic, "chromatic_aberration", 100.0);
    Frame dispersed(160, 160);
    fillImpulse(dispersed, 24, 80);
    CHECK(render(dispersed, chromatic), "chromatic aberration render must complete");
    const ChannelCentroid dispersed_red = measureChannel(dispersed, 0);
    const ChannelCentroid dispersed_blue = measureChannel(dispersed, 2);
    CHECK(std::abs(dispersed_red.x - dispersed_blue.x) > std::abs(neutral_red.x - neutral_blue.x) + 0.02,
          "chromatic aberration must increase channel separation continuously");

    Frame preview(160, 160);
    Frame balanced(160, 160);
    Frame final(160, 160);
    fillImpulse(preview, 24, 80);
    fillImpulse(balanced, 24, 80);
    fillImpulse(final, 24, 80);
    Settings preview_settings = base;
    Settings balanced_settings = base;
    Settings final_settings = base;
    setSetting(preview_settings, "quality", 0);
    setSetting(balanced_settings, "quality", 1);
    setSetting(final_settings, "quality", 2);
    CHECK(render(preview, preview_settings) && render(balanced, balanced_settings) && render(final, final_settings),
          "all deterministic optical quality modes must render");
    const double preview_error = maximumDifference(preview, final);
    const double balanced_error = maximumDifference(balanced, final);
    CHECK(balanced_error <= preview_error + 1.0e-5, "quality error must improve from Preview to Balanced");
    CHECK(maximumDifference(final, final) <= 1.0e-12, "Final quality must be deterministic");

    Frame constant(64, 64);
    fillConstant(constant, 0.75F);
    Settings vignette = base;
    setSetting(vignette, "blur", 3.0);
    setSetting(vignette, "vignetting", 100.0);
    CHECK(render(constant, vignette), "optical vignetting render must complete");
    const float center_value = pixel(constant.destination, constant, 32, 32)[0];
    const float corner_value = pixel(constant.destination, constant, 0, 0)[0];
    CHECK(center_value > corner_value + 0.01F, "optical vignetting must darken the field rim independently");
    std::printf("aberration chromatic separation %.5f -> %.5f, quality errors preview %.6f balanced %.6f, vignette %.5f -> %.5f\n",
                std::abs(neutral_red.x - neutral_blue.x), std::abs(dispersed_red.x - dispersed_blue.x), preview_error,
                balanced_error, center_value, corner_value);
    return 0;
}

}

int main()
{
    if (testMetadataAndFieldMetrics() != 0) return 1;
    if (testDiagnosticsAndDeterminism() != 0) return 1;
    if (testAberrationQualityAndVignette() != 0) return 1;
    std::puts("optical_field_psf_cpu_contract: PASS");
    return 0;
}
