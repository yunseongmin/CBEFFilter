#include <algorithm>
#include <array>
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

    Frame(int origin_x, int origin_y, int width, int height, std::size_t padding = 0U)
        : bounds{origin_x, origin_y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + padding)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), 0U)
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

int fail(const char* message)
{
    std::fprintf(stderr, "optical_aberration_cpu_contract: %s\n", message);
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

bool render(Frame& frame, Settings settings, RectI window = RectI{}, RenderScale scale = RenderScale{1.0, 1.0},
            AlphaAssociation alpha_association = AlphaAssociation::Straight)
{
    if (window.x1 == 0 && window.y1 == 0 && window.x2 == 0 && window.y2 == 0) {
        window = RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                       frame.bounds.y + frame.bounds.height};
    }
    RenderRequest request{EffectId::OpticalBlur,
                          surface(frame.source.data(), frame),
                          surface(frame.destination.data(), frame),
                          window,
                          0.0,
                          scale,
                          alpha_association,
                          std::move(settings)};
    CpuRenderBackend backend;
    return cbef::render(request, backend).kind == SubmissionKind::Completed;
}

void prepare(Settings& settings)
{
    setSetting(settings, "working_mode", 1);
    setSetting(settings, "output_view", 0);
    setSetting(settings, "blur", 2.5);
    setSetting(settings, "highlight_response", 0.0);
    setSetting(settings, "cat_eye", 0.0);
    setSetting(settings, "quality", 1);
    setSetting(settings, "vignetting", 0.0);
    setSetting(settings, "coma", 0.0);
    setSetting(settings, "astigmatism", 0.0);
    setSetting(settings, "field_curvature", 0.0);
    setSetting(settings, "chromatic_aberration", 0.0);
}

void fillImpulse(Frame& frame, int x, int y, float r = 1.0F, float g = 1.0F, float b = 1.0F)
{
    std::fill(frame.source.begin(), frame.source.end(), 0U);
    for (int row = frame.bounds.y; row < frame.bounds.y + frame.bounds.height; ++row) {
        for (int column = frame.bounds.x; column < frame.bounds.x + frame.bounds.width; ++column) {
            pixel(frame.source, frame, column, row)[3] = 1.0F;
        }
    }
    float* impulse = pixel(frame.source, frame, x, y);
    impulse[0] = r;
    impulse[1] = g;
    impulse[2] = b;
}

struct Moments {
    double energy = 0.0;
    double x = 0.0;
    double y = 0.0;
    double xx = 0.0;
    double yy = 0.0;
};

Moments measure(const Frame& frame, int channel = 0)
{
    Moments result;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const double weight = std::max(0.0, static_cast<double>(pixel(frame.destination, frame, x, y)[channel]));
            result.energy += weight;
            result.x += weight * x;
            result.y += weight * y;
        }
    }
    if (result.energy > 1.0e-12) {
        result.x /= result.energy;
        result.y /= result.energy;
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                const double weight = std::max(0.0, static_cast<double>(pixel(frame.destination, frame, x, y)[channel]));
                result.xx += weight * (x - result.x) * (x - result.x);
                result.yy += weight * (y - result.y) * (y - result.y);
            }
        }
        result.xx /= result.energy;
        result.yy /= result.energy;
    }
    return result;
}

double maxDifference(const Frame& lhs, const Frame& rhs)
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

int testMetadata()
{
    const EffectDefinition& definition = effectDefinition(EffectId::OpticalBlur);
    CHECK(definition.parameters.size() == 19U, "optical aberration controls must append to ticket15");
    CHECK(std::string_view{definition.parameters[9].label} == "Highlight Gain" &&
              std::string_view{definition.parameters[10].choices[0]} == "Generic Clean" &&
              std::string_view{definition.parameters[13].label} == "Optical Vignetting" &&
              std::string_view{definition.parameters[18].label} == "Quality",
          "optical metadata labels must remain stable");
    CHECK(settingChoice(defaultSettings(EffectId::OpticalBlur), "quality") == 1,
          "Balanced must be the default quality");
    return 0;
}

int testAberrationDirections()
{
    Settings base = defaultSettings(EffectId::OpticalBlur);
    prepare(base);
    Frame chroma0(0, 0, 96, 96);
    fillImpulse(chroma0, 12, 48);
    CHECK(render(chroma0, base), "chromatic zero render must complete");
    const Moments red0 = measure(chroma0, 0);
    const Moments blue0 = measure(chroma0, 2);
    CHECK(std::abs(red0.x - blue0.x) < 0.05, "zero chromatic aberration must align channels");
    double previous_separation = 0.0;
    for (double amount : {25.0, 50.0, 100.0}) {
        Settings chromatic = base;
        setSetting(chromatic, "chromatic_aberration", amount);
        Frame frame(0, 0, 96, 96);
        fillImpulse(frame, 12, 48);
        CHECK(render(frame, chromatic), "chromatic sweep render must complete");
        const double separation = std::abs(measure(frame, 0).x - measure(frame, 2).x);
        CHECK(separation > previous_separation + 0.005, "chromatic separation must increase monotonically");
        previous_separation = separation;
    }

    Settings coma = base;
    setSetting(coma, "coma", 100.0);
    Frame no_coma(0, 0, 96, 96);
    Frame with_coma(0, 0, 96, 96);
    fillImpulse(no_coma, 12, 48);
    fillImpulse(with_coma, 12, 48);
    CHECK(render(no_coma, base) && render(with_coma, coma), "coma renders must complete");
    CHECK(measure(with_coma).x > measure(no_coma).x + 0.03, "coma must bias the radial centroid");

    Settings astig = base;
    setSetting(astig, "astigmatism", 100.0);
    Frame no_astig(0, 0, 96, 96);
    Frame with_astig(0, 0, 96, 96);
    fillImpulse(no_astig, 12, 48);
    fillImpulse(with_astig, 12, 48);
    CHECK(render(no_astig, base) && render(with_astig, astig), "astigmatism renders must complete");
    CHECK(std::abs(measure(with_astig).xx - measure(no_astig).xx) > 0.02,
          "astigmatism must change radial/tangential second moments");

    Settings focus = base;
    setSetting(focus, "field_curvature", 100.0);
    Frame center0(0, 0, 96, 96);
    Frame center1(0, 0, 96, 96);
    Frame corner0(0, 0, 96, 96);
    Frame corner1(0, 0, 96, 96);
    fillImpulse(center0, 48, 48);
    fillImpulse(center1, 48, 48);
    fillImpulse(corner0, 12, 12);
    fillImpulse(corner1, 12, 12);
    CHECK(render(center0, base) && render(center1, focus) && render(corner0, base) && render(corner1, focus),
          "field focus bias renders must complete");
    CHECK(std::abs(measure(center0).xx - measure(center1).xx) < 0.10 && measure(corner1).xx > measure(corner0).xx + 0.10,
          "field focus bias must preserve center and change the corner monotonically");
    std::printf("aberration ca0=%.5f ca100=%.5f coma_shift=%.5f astig_delta=%.5f focus_corner_delta=%.5f\n",
                std::abs(red0.x - blue0.x), previous_separation, measure(with_coma).x - measure(no_coma).x,
                measure(with_astig).xx - measure(no_astig).xx, measure(corner1).xx - measure(corner0).xx);
    return 0;
}

int testQualityVignetteAndTransition()
{
    Settings base = defaultSettings(EffectId::OpticalBlur);
    prepare(base);
    Frame final_frame(0, 0, 128, 128);
    fillImpulse(final_frame, 64, 64);
    Settings final_settings = base;
    setSetting(final_settings, "quality", 2);
    CHECK(render(final_frame, final_settings), "Final render must complete");
    std::array<double, 3> errors{};
    for (int quality = 0; quality < 3; ++quality) {
        Frame repeated(0, 0, 128, 128);
        Frame repeated_again(0, 0, 128, 128);
        fillImpulse(repeated, 64, 64);
        fillImpulse(repeated_again, 64, 64);
        Settings settings = base;
        setSetting(settings, "quality", quality);
        CHECK(render(repeated, settings) && render(repeated_again, settings), "quality render must complete");
        CHECK(repeated.destination == repeated_again.destination, "quality output must be byte deterministic");
        errors[static_cast<std::size_t>(quality)] = maxDifference(repeated, final_frame);
    }
    CHECK(errors[2] <= errors[1] + 1.0e-6 && errors[1] <= errors[0] + 1.0e-6,
          "quality error must improve monotonically");

    Frame constant(64, 64, 64, 64);
    std::fill(constant.source.begin(), constant.source.end(), 0U);
    for (int y = 64; y < 128; ++y) for (int x = 64; x < 128; ++x) {
        float* value = pixel(constant.source, constant, x, y);
        value[0] = value[1] = value[2] = 0.75F;
        value[3] = 1.0F;
    }
    double prior_rim = 1.0e9;
    for (double amount : {0.0, 25.0, 50.0, 100.0}) {
        Frame vignette(64, 64, 64, 64);
        vignette.source = constant.source;
        Settings settings = base;
        setSetting(settings, "vignetting", amount);
        CHECK(render(vignette, settings), "vignetting sweep render must complete");
        const double rim = pixel(vignette.destination, vignette, 127, 127)[0];
        CHECK(rim <= prior_rim + 1.0e-5, "vignetting must be monotonic");
        prior_rim = rim;
    }

    for (double blur : {1.56, 3.12}) {
        Frame frame(0, 0, 128, 128);
        fillImpulse(frame, 64, 64);
        Settings settings = base;
        setSetting(settings, "blur", blur);
        CHECK(render(frame, settings), "radius transition render must complete");
        const Moments moments = measure(frame);
        CHECK(std::abs(moments.energy - 1.0) < 0.01 && std::abs(moments.x - 64.0) < 0.25,
              "4-8px transition must preserve energy and centroid");
    }
    std::array<Moments, 5> transition{};
    for (std::size_t index = 0; index < transition.size(); ++index) {
        Frame frame(0, 0, 256, 256);
        fillImpulse(frame, 128, 128);
        Settings settings = base;
        setSetting(settings, "blur", (static_cast<double>(index) + 4.0) * 100.0 / 256.0);
        CHECK(render(frame, settings), "adjacent radius transition render must complete");
        transition[index] = measure(frame);
        CHECK(std::isfinite(transition[index].energy) && std::isfinite(transition[index].x) &&
                  std::isfinite(transition[index].xx),
              "adjacent radius metrics must remain finite");
    }
    for (std::size_t index = 1; index < transition.size(); ++index) {
        const Moments& previous = transition[index - 1];
        const Moments& current = transition[index];
        const double energy_jump = std::abs(current.energy - previous.energy) / std::max(previous.energy, 1.0e-12);
        const double previous_radius = static_cast<double>(index + 3);
        const double current_radius = static_cast<double>(index + 4);
        const double previous_normalized_moment = previous.xx / (previous_radius * previous_radius);
        const double current_normalized_moment = current.xx / (current_radius * current_radius);
        const double normalized_moment_jump =
            std::abs(current_normalized_moment - previous_normalized_moment) /
            std::max(std::abs(previous_normalized_moment), 1.0e-12);
        CHECK(energy_jump <= 0.005 && std::abs(current.x - previous.x) <= 0.25 &&
                  normalized_moment_jump <= 0.03,
              "adjacent 4-8px transitions must stay within energy, centroid, and normalized-moment bounds");
    }
    std::printf("quality errors preview=%.6f balanced=%.6f final=%.6f\n", errors[0], errors[1], errors[2]);
    return 0;
}

int testWindowsAlphaHdrAndDiagnostics()
{
    Settings base = defaultSettings(EffectId::OpticalBlur);
    prepare(base);
    Frame odd(7, -3, 65, 63, 32U);
    std::fill(odd.destination.begin(), odd.destination.end(), 0xA5U);
    fillImpulse(odd, 7 + 1, -3 + 1, -2.0F, 4.0F, 1.0F);
    const RectI crop{odd.bounds.x + 8, odd.bounds.y + 8, odd.bounds.x + 56, odd.bounds.y + 55};
    CHECK(render(odd, base, crop), "odd padded cropped render must complete");
    CHECK(std::abs(pixel(odd.destination, odd, crop.x1, crop.y1)[3] - 1.0F) < 1.0e-6F,
          "crop interior must be rendered");
    CHECK(odd.destination[0] == 0xA5U, "crop outside bytes must retain sentinel");

    Settings resolution_settings = base;
    setSetting(resolution_settings, "blur", 0.5);
    double normalized_reference = 0.0;
    bool normalized_reference_set = false;
    for (const auto& size : std::array<std::pair<int, int>, 2>{{{1920, 1080}, {3840, 2160}}}) {
        for (double render_scale : {0.5, 1.0, 2.0}) {
            Frame resolution(0, 0, size.first, size.second);
            const int center_x = size.first / 2;
            const int center_y = size.second / 2;
            fillImpulse(resolution, center_x, center_y);
            const RectI window{center_x - 32, center_y - 32, center_x + 32, center_y + 32};
            CHECK(render(resolution, resolution_settings, window, RenderScale{render_scale, render_scale}),
                  "1080/UHD cropped render-scale fixture must complete");
            const Moments moments = measure(resolution);
            CHECK(std::abs(moments.energy - 1.0) < 0.01 && std::abs(moments.x - center_x) < 0.25 &&
                      std::abs(moments.y - center_y) < 0.25,
                  "resolution and render-scale fixture must preserve normalized PSF metrics");
            const double normalized_moment = moments.xx / (static_cast<double>(size.second) * size.second);
            if (!normalized_reference_set) {
                normalized_reference = normalized_moment;
                normalized_reference_set = true;
            }
            CHECK(std::abs(normalized_moment - normalized_reference) / std::max(normalized_reference, 1.0e-12) <= 0.03,
                  "1080/UHD and render-scale normalized moments must agree within three percent");
        }
    }

    Frame edge(0, 0, 65, 63);
    fillImpulse(edge, 0, 31);
    CHECK(render(edge, base), "edge no-wrap render must complete");
    CHECK(pixel(edge.destination, edge, 64, 31)[0] < 1.0e-5F, "optical gather must not wrap across the edge");

    Frame signed_hdr(0, 0, 65, 63);
    fillImpulse(signed_hdr, 32, 31, -2.0F, 4.0F, 1.0F);
    CHECK(render(signed_hdr, base), "signed HDR optical render must complete");
    CHECK(pixel(signed_hdr.destination, signed_hdr, 32, 31)[0] < -0.01F,
          "signed HDR residual must not be clamped positive");

    Settings identity = base;
    setSetting(identity, "blur", 0.0);
    for (int quality = 0; quality < 3; ++quality) {
        setSetting(identity, "quality", quality);
        Frame frame(11, 5, 33, 31, 16U);
        std::fill(frame.source.begin(), frame.source.end(), 0U);
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* value = pixel(frame.source, frame, x, y);
            value[0] = -1.25F;
            value[1] = 2.5F;
            value[2] = 0.125F;
            value[3] = 0.5F;
        }
        CHECK(render(frame, identity, RectI{}, RenderScale{1.0, 1.0}, AlphaAssociation::Premultiplied),
              "signed HDR identity must complete");
        CHECK(frame.source == frame.destination, "identity must preserve signed HDR, alpha, and padded bytes");
    }
    Frame strong_hdr(0, 0, 65, 63);
    for (int y = 0; y < strong_hdr.bounds.height; ++y) {
        for (int x = 0; x < strong_hdr.bounds.width; ++x) {
            float* value = pixel(strong_hdr.source, strong_hdr, x, y);
            value[0] = -4.0F;
            value[1] = 12.0F;
            value[2] = 3.0F;
            value[3] = 0.5F;
        }
    }
    Settings strong_settings = base;
    setSetting(strong_settings, "working_mode", 1);
    setSetting(strong_settings, "blur", 4.0);
    setSetting(strong_settings, "highlight_response", 100.0);
    setSetting(strong_settings, "coma", 100.0);
    setSetting(strong_settings, "astigmatism", 100.0);
    setSetting(strong_settings, "chromatic_aberration", 100.0);
    setSetting(strong_settings, "vignetting", 100.0);
    CHECK(render(strong_hdr, strong_settings), "active signed HDR optical render must complete");
    for (int y = 0; y < strong_hdr.bounds.height; ++y) {
        for (int x = 0; x < strong_hdr.bounds.width; ++x) {
            const float* value = pixel(strong_hdr.destination, strong_hdr, x, y);
            CHECK(std::isfinite(value[0]) && std::isfinite(value[1]) && std::isfinite(value[2]) &&
                      value[0] < -0.01F && value[1] > 1.0F,
                  "active signed HDR optical output must stay finite, signed, and above display range");
            CHECK(std::memcmp(&value[3], &pixel(strong_hdr.source, strong_hdr, x, y)[3], sizeof(float)) == 0,
                  "active optical processing must preserve alpha bits");
        }
    }
    for (AlphaAssociation association : {AlphaAssociation::Straight, AlphaAssociation::Premultiplied}) {
        Frame alpha_frame(5, -2, 33, 31, 16U);
        Frame alpha_control(5, -2, 33, 31, 16U);
        std::fill(alpha_frame.source.begin(), alpha_frame.source.end(), 0U);
        alpha_control.source = alpha_frame.source;
        for (int y = alpha_frame.bounds.y; y < alpha_frame.bounds.y + alpha_frame.bounds.height; ++y) {
            for (int x = alpha_frame.bounds.x; x < alpha_frame.bounds.x + alpha_frame.bounds.width; ++x) {
                float* value = pixel(alpha_frame.source, alpha_frame, x, y);
                value[0] = 0.8F;
                value[1] = 1.6F;
                value[2] = -0.4F;
                value[3] = 0.5F;
                if (association == AlphaAssociation::Premultiplied) {
                    value[0] *= value[3];
                    value[1] *= value[3];
                    value[2] *= value[3];
                }
            }
        }
        alpha_control.source = alpha_frame.source;
        float* transparent = pixel(alpha_frame.source, alpha_frame, alpha_frame.bounds.x + 1, alpha_frame.bounds.y + 1);
        transparent[0] = 99.0F;
        transparent[1] = -77.0F;
        transparent[2] = 42.0F;
        transparent[3] = 0.0F;
        float* transparent_control = pixel(alpha_control.source, alpha_control, alpha_control.bounds.x + 1,
                                            alpha_control.bounds.y + 1);
        transparent_control[0] = transparent_control[1] = transparent_control[2] = 0.0F;
        transparent_control[3] = 0.0F;
        CHECK(render(alpha_frame, strong_settings, RectI{}, RenderScale{1.0, 1.0}, association) &&
                  render(alpha_control, strong_settings, RectI{}, RenderScale{1.0, 1.0}, association),
              "straight and premultiplied alpha optical render must complete");
        const float* transparent_output = pixel(alpha_frame.destination, alpha_frame, alpha_frame.bounds.x + 1,
                                                 alpha_frame.bounds.y + 1);
        CHECK(transparent_output[0] == 0.0F && transparent_output[1] == 0.0F && transparent_output[2] == 0.0F &&
                  std::memcmp(&transparent_output[3], &transparent[3], sizeof(float)) == 0,
              "transparent RGB must be zeroed without changing its alpha bits");
        for (int y = alpha_frame.bounds.y; y < alpha_frame.bounds.y + alpha_frame.bounds.height; ++y) {
            for (int x = alpha_frame.bounds.x; x < alpha_frame.bounds.x + alpha_frame.bounds.width; ++x) {
                const float* output = pixel(alpha_frame.destination, alpha_frame, x, y);
                const float* control = pixel(alpha_control.destination, alpha_control, x, y);
                CHECK(std::isfinite(output[0]) && std::isfinite(output[1]) && std::isfinite(output[2]) &&
                          std::memcmp(&output[3], &pixel(alpha_frame.source, alpha_frame, x, y)[3], sizeof(float)) == 0 &&
                          std::abs(output[0] - control[0]) <= 1.0e-5F &&
                          std::abs(output[1] - control[1]) <= 1.0e-5F &&
                          std::abs(output[2] - control[2]) <= 1.0e-5F,
                      "transparent arbitrary RGB must not leak into straight or premultiplied output");
            }
        }
    }
    for (int view = 0; view < 5; ++view) {
        Settings diagnostics = base;
        setSetting(diagnostics, "output_view", view);
        Frame first(0, 0, 48, 48);
        Frame second(0, 0, 48, 48);
        fillImpulse(first, 24, 24, 3.0F, 1.0F, 2.0F);
        fillImpulse(second, 24, 24, 3.0F, 1.0F, 2.0F);
        CHECK(render(first, diagnostics) && render(second, diagnostics), "diagnostic output must complete");
        CHECK(first.destination == second.destination, "diagnostics must be deterministic");
    }
    return 0;
}
}

int main()
{
    if (testMetadata() != 0) return 1;
    if (testAberrationDirections() != 0) return 1;
    if (testQualityVignetteAndTransition() != 0) return 1;
    if (testWindowsAlphaHdrAndDiagnostics() != 0) return 1;
    std::puts("optical_aberration_cpu_contract: PASS");
    return 0;
}
