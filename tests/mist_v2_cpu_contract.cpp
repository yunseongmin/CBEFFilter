#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <limits>
#include <string_view>
#include <utility>
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
using cbef::PixelFormat;
using cbef::RectI;
using cbef::RenderRequest;
using cbef::RenderScale;
using cbef::Settings;
using cbef::SubmissionKind;

constexpr std::size_t kPixelBytes = sizeof(float) * 4U;
constexpr std::uint8_t kSentinel = 0xA5U;

int fail(const char* message)
{
    std::fprintf(stderr, "mist_v2_cpu_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) { \
            return fail(message); \
        } \
    } while (false)

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    Frame(int width, int height, int origin_x = 0, int origin_y = 0, std::size_t padding = 0U)
        : bounds{origin_x, origin_y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + padding)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), kSentinel)
    {
    }
};

float* pixel(std::vector<std::uint8_t>& storage, const Frame& frame, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - frame.bounds.y);
    const std::size_t column = static_cast<std::size_t>(x - frame.bounds.x);
    return reinterpret_cast<float*>(storage.data() + row * frame.row_bytes + column * kPixelBytes);
}

const float* pixel(const std::vector<std::uint8_t>& storage, const Frame& frame, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - frame.bounds.y);
    const std::size_t column = static_cast<std::size_t>(x - frame.bounds.x);
    return reinterpret_cast<const float*>(storage.data() + row * frame.row_bytes + column * kPixelBytes);
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
                         cbef::defaultSettings(EffectId::MistDiffusion)};
}

bool render(Frame& frame, Settings settings, RectI window = RectI{0, 0, 0, 0},
            AlphaAssociation association = AlphaAssociation::Straight)
{
    RenderRequest request = requestFor(frame);
    request.settings = std::move(settings);
    request.alpha_association = association;
    if (window.x1 != window.x2 || window.y1 != window.y2) {
        request.render_window = window;
    }
    CpuRenderBackend backend;
    return cbef::render(request, backend).kind == SubmissionKind::Completed;
}

bool setChoice(Settings& settings, const char* id, int value)
{
    return cbef::setSetting(settings, id, value);
}

bool setDouble(Settings& settings, const char* id, double value)
{
    return cbef::setSetting(settings, id, value);
}

bool linear(Settings& settings)
{
    return setChoice(settings, "working_mode", 1);
}

void fill(Frame& frame, float value)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* value_ptr = pixel(frame.source, frame, x, y);
            value_ptr[0] = value;
            value_ptr[1] = value;
            value_ptr[2] = value;
            value_ptr[3] = 1.0F;
        }
    }
}

void fillImpulse(Frame& frame, float background = 0.0F, float peak = 8.0F)
{
    fill(frame, background);
    const int x = frame.bounds.x + frame.bounds.width / 2;
    const int y = frame.bounds.y + frame.bounds.height / 2;
    float* value = pixel(frame.source, frame, x, y);
    value[0] = peak;
    value[1] = peak;
    value[2] = peak;
}

double luminanceAt(const Frame& frame, int x, int y)
{
    const float* value = pixel(frame.destination, frame, x, y);
    return 0.2126 * value[0] + 0.7152 * value[1] + 0.0722 * value[2];
}

double energy(const Frame& frame)
{
    double sum = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            sum += std::max(0.0, luminanceAt(frame, x, y));
        }
    }
    return sum;
}

float minimumRgb(const Frame& frame)
{
    float minimum = std::numeric_limits<float>::max();
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float* value = pixel(frame.destination, frame, x, y);
            minimum = std::min({minimum, value[0], value[1], value[2]});
        }
    }
    return minimum;
}

double outsideEnergy(const Frame& frame)
{
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    double sum = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            if (std::abs(x - center_x) <= 1 && std::abs(y - center_y) <= 1) continue;
            sum += std::max(0.0, luminanceAt(frame, x, y));
        }
    }
    return sum;
}

double spreadRadius(const Frame& frame)
{
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    double weighted_radius_squared = 0.0;
    double total = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const double contribution = std::max(0.0, luminanceAt(frame, x, y));
            const double dx = static_cast<double>(x - center_x);
            const double dy = static_cast<double>(y - center_y);
            weighted_radius_squared += contribution * (dx * dx + dy * dy);
            total += contribution;
        }
    }
    return std::sqrt(weighted_radius_squared / std::max(total, 1.0e-12));
}

const cbef::ParameterDefinition* parameter(const EffectDefinition& definition, std::string_view id)
{
    for (const cbef::ParameterDefinition& candidate : definition.parameters) {
        if (id == candidate.id) return &candidate;
    }
    return nullptr;
}

int testInspectorVocabulary()
{
    const EffectDefinition& definition = cbef::effectDefinition(EffectId::MistDiffusion);
    const cbef::ParameterDefinition* family = parameter(definition, "mode");
    const cbef::ParameterDefinition* grade = parameter(definition, "density");
    const cbef::ParameterDefinition* veil = parameter(definition, "diffusion");
    const cbef::ParameterDefinition* glow = parameter(definition, "bloom");
    const cbef::ParameterDefinition* output = parameter(definition, "output_view");
    CHECK(family != nullptr && grade != nullptr && veil != nullptr && glow != nullptr && output != nullptr,
          "Mist must expose Filter Family, Grade, Veil, Glow, and diagnostics from one definition");
    CHECK(std::strcmp(family->label, "Filter Family") == 0 && family->choices.size() == 2U &&
              std::strcmp(family->choices[0], "Generic Black") == 0 &&
              std::strcmp(family->choices[1], "Generic White") == 0,
          "Mist Filter Family must use Generic Black and Generic White");
    CHECK(std::strcmp(grade->label, "Grade") == 0 && std::strcmp(veil->label, "Veil") == 0 &&
              std::strcmp(glow->label, "Glow") == 0,
          "Mist controls must present Grade, Veil, and Glow rather than legacy display names");
    CHECK(output->choices.size() >= 7U && std::strcmp(output->choices[3], "Glow Only") == 0 &&
              std::strcmp(output->choices[4], "Veil Only") == 0 &&
              std::strcmp(output->choices[5], "Source Mask") == 0 &&
              std::strcmp(output->choices[6], "Detail Difference") == 0,
          "Mist diagnostics must expose Glow Only, Veil Only, Source Mask, and Detail Difference");
    for (const cbef::PresetDefinition& preset : definition.presets) {
        CHECK(std::strstr(preset.label, "Pro-Mist") == nullptr && std::strstr(preset.label, "Tiffen") == nullptr &&
                  std::strstr(preset.label, "Hoya") == nullptr && std::strstr(preset.label, "Schneider") == nullptr,
              "Mist presets must not claim a manufacturer profile");
    }
    return 0;
}

int testGlowVeilDiagnosticsAndReconstruction()
{
    Frame source(129, 129);
    fillImpulse(source, 0.02F);
    Settings settings = cbef::defaultSettings(EffectId::MistDiffusion);
    CHECK(linear(settings) && setDouble(settings, "diffusion", 60.0) && setDouble(settings, "bloom", 60.0) &&
              setDouble(settings, "contrast", 0.0) && setDouble(settings, "texture", 100.0),
          "diagnostic fixture settings must be accepted");

    Frame glow = source;
    CHECK(setChoice(settings, "output_view", 3) && render(glow, settings), "Glow Only must render through public CPU contract");
    Frame veil = source;
    CHECK(setChoice(settings, "output_view", 4) && render(veil, settings), "Veil Only must render through public CPU contract");
    Frame mask = source;
    CHECK(setChoice(settings, "output_view", 5) && render(mask, settings), "Source Mask must render through public CPU contract");
    Frame final = source;
    CHECK(setChoice(settings, "output_view", 0) && render(final, settings), "Final Mist must render through public CPU contract");

    const int center_x = source.bounds.x + source.bounds.width / 2;
    const int center_y = source.bounds.y + source.bounds.height / 2;
    CHECK(outsideEnergy(glow) > 0.0 && outsideEnergy(veil) > 0.0,
          "Glow and Veil diagnostics must each produce an exterior contribution");
    CHECK(luminanceAt(mask, center_x, center_y) > 0.95 && luminanceAt(mask, source.bounds.x, source.bounds.y) < 1.0e-5,
          "Source Mask must isolate the highlight without filling the dark field");
    for (int y = source.bounds.y; y < source.bounds.y + source.bounds.height; ++y) {
        for (int x = source.bounds.x; x < source.bounds.x + source.bounds.width; ++x) {
            const float* original = pixel(source.source, source, x, y);
            const float* final_pixel = pixel(final.destination, final, x, y);
            const float* glow_pixel = pixel(glow.destination, glow, x, y);
            const float* veil_pixel = pixel(veil.destination, veil, x, y);
            for (int channel = 0; channel < 3; ++channel) {
                CHECK(std::abs((final_pixel[channel] - original[channel]) - (glow_pixel[channel] + veil_pixel[channel])) <=
                          2.0e-4F,
                      "Glow Only plus Veil Only must reconstruct Final contribution with Detail neutralized");
            }
        }
    }

    Frame glow_zero = source;
    Settings glow_zero_settings = settings;
    CHECK(setDouble(glow_zero_settings, "bloom", 0.0) && setChoice(glow_zero_settings, "output_view", 3) &&
              render(glow_zero, glow_zero_settings),
          "zero Glow must render");
    Frame veil_zero = source;
    Settings veil_zero_settings = settings;
    CHECK(setDouble(veil_zero_settings, "diffusion", 0.0) && setChoice(veil_zero_settings, "output_view", 4) &&
              render(veil_zero, veil_zero_settings),
          "zero Veil must render");
    CHECK(energy(glow_zero) <= 1.0e-5 && energy(veil_zero) <= 1.0e-5,
          "Glow and Veil must be independently controllable");
    return 0;
}

int testProfilesAndGradeDirection()
{
    std::array<double, 5> glow_energy{};
    std::array<double, 5> veil_energy{};
    std::array<double, 5> veil_radius{};
    for (int grade = 0; grade < 5; ++grade) {
        Frame glow(257, 257);
        fillImpulse(glow);
        Settings glow_settings = cbef::defaultSettings(EffectId::MistDiffusion);
        CHECK(linear(glow_settings) && setChoice(glow_settings, "density", grade) &&
                  setDouble(glow_settings, "diffusion", 0.0) && setDouble(glow_settings, "bloom", 55.0) &&
                  setDouble(glow_settings, "contrast", 0.0) && setDouble(glow_settings, "texture", 100.0) &&
                  setChoice(glow_settings, "output_view", 3) && render(glow, glow_settings),
              "grade Glow fixture must render");
        glow_energy[static_cast<std::size_t>(grade)] = outsideEnergy(glow);

        Frame veil(257, 257);
        fillImpulse(veil);
        Settings veil_settings = glow_settings;
        CHECK(setDouble(veil_settings, "diffusion", 55.0) && setDouble(veil_settings, "bloom", 0.0) &&
                  setChoice(veil_settings, "output_view", 4) && render(veil, veil_settings),
              "grade Veil fixture must render");
        veil_energy[static_cast<std::size_t>(grade)] = outsideEnergy(veil);
        veil_radius[static_cast<std::size_t>(grade)] = spreadRadius(veil);
    }
    for (std::size_t index = 1; index < glow_energy.size(); ++index) {
        CHECK(glow_energy[index] > glow_energy[index - 1] && veil_energy[index] > veil_energy[index - 1] &&
                  veil_radius[index] > veil_radius[index - 1],
              "generic internal Grade steps must increase Glow and Veil energy and Veil radius monotonically");
    }

    Frame black_veil(513, 513);
    Frame white_veil(513, 513);
    fillImpulse(black_veil);
    fillImpulse(white_veil);
    Settings black = cbef::defaultSettings(EffectId::MistDiffusion);
    Settings white = black;
    CHECK(linear(black) && linear(white) && setChoice(black, "density", 2) && setChoice(white, "density", 2) &&
              setDouble(black, "diffusion", 60.0) && setDouble(white, "diffusion", 60.0) &&
              setDouble(black, "bloom", 0.0) && setDouble(white, "bloom", 0.0) &&
              setDouble(black, "contrast", 0.0) && setDouble(white, "contrast", 0.0) &&
              setDouble(black, "texture", 100.0) && setDouble(white, "texture", 100.0) &&
              setChoice(black, "output_view", 4) && setChoice(white, "output_view", 4) && setChoice(white, "mode", 1) &&
              render(black_veil, black) && render(white_veil, white),
          "same-Grade Generic Black and Generic White Veil fixtures must render");
    CHECK(outsideEnergy(white_veil) > outsideEnergy(black_veil) &&
              spreadRadius(white_veil) > spreadRadius(black_veil),
          "Generic White must have broader, higher-energy Veil at the same internal Grade");

    Frame black_patch(129, 65);
    Frame white_patch(129, 65);
    fill(black_patch, 0.05F);
    fill(white_patch, 0.05F);
    Settings black_patch_settings = cbef::defaultSettings(EffectId::MistDiffusion);
    Settings white_patch_settings = black_patch_settings;
    CHECK(linear(black_patch_settings) && linear(white_patch_settings) && setChoice(black_patch_settings, "density", 2) &&
              setChoice(white_patch_settings, "density", 2) && setDouble(black_patch_settings, "diffusion", 0.0) &&
              setDouble(white_patch_settings, "diffusion", 0.0) && setDouble(black_patch_settings, "bloom", 0.0) &&
              setDouble(white_patch_settings, "bloom", 0.0) && setDouble(black_patch_settings, "contrast", 35.0) &&
              setDouble(white_patch_settings, "contrast", 35.0) && setDouble(black_patch_settings, "texture", 0.0) &&
              setDouble(white_patch_settings, "texture", 0.0) && setChoice(white_patch_settings, "mode", 1) &&
              render(black_patch, black_patch_settings) && render(white_patch, white_patch_settings),
          "dark patch retention fixtures must render");
    const double black_lift = luminanceAt(black_patch, 64, 32) - 0.05;
    const double white_lift = luminanceAt(white_patch, 64, 32) - 0.05;
    CHECK(std::abs(black_lift) < std::abs(white_lift),
          "Generic Black must retain the low-frequency dark patch more strongly than Generic White");
    return 0;
}

int testNeutralSafetyAndEdges()
{
    Frame frame(9, 5, 4, -2, 32U);
    fill(frame, -0.25F);
    float* highlight = pixel(frame.source, frame, 4, -1);
    highlight[0] = 4.0F;
    highlight[1] = 4.0F;
    highlight[2] = 4.0F;
    highlight[3] = 1.0F;
    float* transparent = pixel(frame.source, frame, 10, 0);
    transparent[0] = 100.0F;
    transparent[1] = 50.0F;
    transparent[2] = 25.0F;
    transparent[3] = 0.0F;
    const std::array<std::uint32_t, 4> alpha_bits = {0x3F800000U, 0x3F800000U, 0x3F800000U, 0x3F000000U};
    std::memcpy(pixel(frame.source, frame, 7, 0), alpha_bits.data(), kPixelBytes);

    Settings settings = cbef::defaultSettings(EffectId::MistDiffusion);
    CHECK(linear(settings) && setChoice(settings, "mode", 1) && setChoice(settings, "density", 3) &&
              setDouble(settings, "diffusion", 100.0) && setDouble(settings, "bloom", 100.0) &&
              setDouble(settings, "contrast", 55.0) && setDouble(settings, "texture", 100.0),
          "strong Generic White safety settings must be accepted");
    const RectI crop{5, -1, 12, 1};
    CHECK(render(frame, settings, crop), "signed HDR crop must render through CPU contract");
    CHECK(frame.destination.front() == kSentinel, "crop must preserve destination bytes outside the render window");
    CHECK(std::abs(pixel(frame.destination, frame, 10, 0)[0]) <= 1.0e-6F &&
              std::abs(pixel(frame.destination, frame, 10, 0)[1]) <= 1.0e-6F &&
              std::abs(pixel(frame.destination, frame, 10, 0)[2]) <= 1.0e-6F,
          "transparent hidden RGB must not leak through Mist");
    CHECK(pixel(frame.destination, frame, 8, -1)[2] < -0.20F,
          "signed negative RGB residual must survive the Mist reference path");
    for (int y = crop.y1; y < crop.y2; ++y) {
        for (int x = crop.x1; x < crop.x2; ++x) {
            const float* value = pixel(frame.destination, frame, x, y);
            CHECK(std::isfinite(value[0]) && std::isfinite(value[1]) && std::isfinite(value[2]),
                  "signed HDR Mist output must remain finite");
            std::uint32_t source_alpha = 0U;
            std::uint32_t destination_alpha = 0U;
            std::memcpy(&source_alpha, &pixel(frame.source, frame, x, y)[3], sizeof(source_alpha));
            std::memcpy(&destination_alpha, &value[3], sizeof(destination_alpha));
            CHECK(source_alpha == destination_alpha, "Mist must preserve alpha bits in crop rendering");
        }
    }

    Frame neutral(129, 129);
    fillImpulse(neutral, 0.02F, 8.0F);
    Settings neutral_settings = settings;
    CHECK(setChoice(neutral_settings, "output_view", 3) && render(neutral, neutral_settings),
          "neutral Glow Only fixture must render");
    const float* neutral_pixel = pixel(neutral.destination, neutral, 66, 64);
    CHECK(std::abs(neutral_pixel[0] - neutral_pixel[1]) <= 2.0e-5F &&
              std::abs(neutral_pixel[1] - neutral_pixel[2]) <= 2.0e-5F,
          "neutral source Glow must remain neutral rather than introducing a color shift");
    CHECK(luminanceAt(neutral, 64, 64) <= 1.0e-5 && outsideEnergy(neutral) > 0.0,
          "strong Glow must stay outside the protected highlight core instead of becoming focus blur");
    return 0;
}

int testStrongWhiteEdgePolarity()
{
    Frame frame(257, 129);
    fill(frame, 0.08F);
    for (int y = 16; y < 113; ++y) {
        for (int x = 96; x < 161; ++x) {
            float* value = pixel(frame.source, frame, x, y);
            value[0] = 0.78F;
            value[1] = 0.78F;
            value[2] = 0.78F;
        }
    }

    Settings settings = cbef::settingsForPreset(EffectId::MistDiffusion, 9U);
    CHECK(setChoice(settings, "working_mode", 0) && setChoice(settings, "output_view", 0) &&
              setDouble(settings, "mix", 100.0) && render(frame, settings),
          "Generic White 2 DWG Intermediate edge fixture must render");

    Frame detail_retained = frame;
    Settings detail_retained_settings = settings;
    CHECK(setDouble(detail_retained_settings, "texture", 100.0) && render(detail_retained, detail_retained_settings),
          "full-detail Generic White edge control must render");
    const float detail_retained_minimum = minimumRgb(detail_retained);

    float minimum_output = std::numeric_limits<float>::max();
    float maximum_output = std::numeric_limits<float>::lowest();
    int minimum_x = 0;
    int minimum_y = 0;
    int minimum_channel = 0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float* value = pixel(frame.destination, frame, x, y);
            for (int channel = 0; channel < 3; ++channel) {
                CHECK(std::isfinite(value[channel]), "Generic White 2 edge fixture must remain finite");
                if (value[channel] < minimum_output) {
                    minimum_output = value[channel];
                    minimum_x = x;
                    minimum_y = y;
                    minimum_channel = channel;
                }
                maximum_output = std::max(maximum_output, value[channel]);
            }
        }
    }
    if (minimum_output < -1.0e-5F) {
        const float* input = pixel(frame.source, frame, minimum_x, minimum_y);
        std::fprintf(stderr,
                     "mist_v2_cpu_contract: Generic White 2 minimum output = %.9g at (%d,%d) channel %d, source = %.9g; detail100 = %.9g\n",
                     minimum_output, minimum_x, minimum_y, minimum_channel, input[minimum_channel],
                     detail_retained_minimum);
    }
    CHECK(minimum_output >= -1.0e-5F,
          "Generic White 2 must not create negative-polarity outlines from non-negative DWG Intermediate input");
    CHECK(maximum_output <= 0.78001F,
          "Generic White 2 must not overshoot the brightest non-negative source across a hard edge");
    const double far_background = luminanceAt(frame, 32, 64);
    const double near_background = luminanceAt(frame, 88, 64);
    const double edge_outside = luminanceAt(frame, 95, 64);
    const double edge_inside = luminanceAt(frame, 96, 64);
    CHECK(far_background > 0.08 && far_background < near_background && near_background < edge_outside,
          "Generic White 2 must retain a broad, smoothly rising white veil outside a bright subject");
    CHECK(edge_outside <= edge_inside + 1.0e-5,
          "Generic White 2 must not reverse edge polarity into a bright exterior outline");

    Frame signed_veil(257, 257);
    fill(signed_veil, 0.0F);
    for (int y = signed_veil.bounds.y; y < signed_veil.bounds.y + signed_veil.bounds.height; ++y) {
        float* value = pixel(signed_veil.source, signed_veil, 128, y);
        value[0] = value[1] = value[2] = 1.0F;
    }
    Settings signed_veil_settings = cbef::defaultSettings(EffectId::MistDiffusion);
    CHECK(linear(signed_veil_settings) && setChoice(signed_veil_settings, "mode", 1) &&
              setChoice(signed_veil_settings, "density", 4) &&
              setDouble(signed_veil_settings, "diffusion", 88.0) &&
              setDouble(signed_veil_settings, "bloom", 0.0) &&
              setDouble(signed_veil_settings, "contrast", 0.0) &&
              setDouble(signed_veil_settings, "texture", 100.0) && render(signed_veil, signed_veil_settings),
          "isolated Generic White 2 signed-veil fixture must render");
    CHECK(luminanceAt(signed_veil, 128, 128) >= -1.0e-6,
          "Generic White 2 signed veil must not extrapolate a non-negative line below zero");
    Frame signed_veil_only = signed_veil;
    Settings signed_veil_only_settings = signed_veil_settings;
    CHECK(setChoice(signed_veil_only_settings, "output_view", 4) &&
              render(signed_veil_only, signed_veil_only_settings),
          "isolated Generic White 2 Veil Only fixture must render");
    CHECK(luminanceAt(signed_veil_only, 128, 128) >= -1.000001,
          "Generic White 2 signed veil contribution must not subtract more than its non-negative source");
    return 0;
}

int testDetailDifferenceAndReconstruction()
{
    Frame source(129, 65);
    fill(source, 0.18F);
    for (int y = 12; y < 30; ++y) {
        for (int x = 8; x < 48; ++x) {
            const float value = ((x + y) % 2 == 0) ? 0.30F : 0.08F;
            float* pixel_value = pixel(source.source, source, x, y);
            pixel_value[0] = value;
            pixel_value[1] = value * 0.92F;
            pixel_value[2] = value * 0.85F;
        }
    }
    for (int y = 8; y < 58; ++y) {
        float* pixel_value = pixel(source.source, source, 84, y);
        pixel_value[0] = pixel_value[1] = pixel_value[2] = (y < 33) ? 1.0F : 0.02F;
    }
    Settings settings = cbef::defaultSettings(EffectId::MistDiffusion);
    CHECK(linear(settings) && setDouble(settings, "diffusion", 0.0) && setDouble(settings, "bloom", 0.0) &&
              setDouble(settings, "contrast", 0.0) && setDouble(settings, "texture", 0.0),
          "detail fixture settings must be accepted");
    Frame detail = source;
    CHECK(setChoice(settings, "output_view", 6) && render(detail, settings),
          "Detail Difference must render through public CPU contract");
    CHECK(energy(detail) > 1.0e-5, "Detail Difference must expose a non-zero contribution at zero retention");
    Settings retained = settings;
    CHECK(setDouble(retained, "texture", 100.0), "full detail retention must be accepted");
    Frame detail_zero = source;
    CHECK(render(detail_zero, retained) && energy(detail_zero) <= 1.0e-5,
          "Detail Difference must be zero at full retention");

    Settings final_settings = settings;
    Frame final = source;
    CHECK(setChoice(final_settings, "output_view", 0) && render(final, final_settings),
          "detail Final must render through public CPU contract");
    Frame glow = source;
    Frame veil = source;
    CHECK(setChoice(final_settings, "output_view", 3) && render(glow, final_settings),
          "detail Glow diagnostic must render");
    CHECK(setChoice(final_settings, "output_view", 4) && render(veil, final_settings),
          "detail Veil diagnostic must render");
    for (int y = source.bounds.y; y < source.bounds.y + source.bounds.height; ++y) {
        for (int x = source.bounds.x; x < source.bounds.x + source.bounds.width; ++x) {
            const float* input = pixel(source.source, source, x, y);
            const float* output = pixel(final.destination, final, x, y);
            const float* glow_value = pixel(glow.destination, glow, x, y);
            const float* veil_value = pixel(veil.destination, veil, x, y);
            const float* detail_value = pixel(detail.destination, detail, x, y);
            for (int channel = 0; channel < 3; ++channel) {
                CHECK(std::abs((output[channel] - input[channel]) -
                               (glow_value[channel] + veil_value[channel] + detail_value[channel])) <= 2.0e-4F,
                      "Glow plus Veil plus Detail must reconstruct Final contribution");
            }
        }
    }
    return 0;
}

}

int main()
{
    if (testInspectorVocabulary() != 0) return 1;
    if (testGlowVeilDiagnosticsAndReconstruction() != 0) return 1;
    if (testProfilesAndGradeDirection() != 0) return 1;
    if (testNeutralSafetyAndEdges() != 0) return 1;
    if (testStrongWhiteEdgePolarity() != 0) return 1;
    if (testDetailDifferenceAndReconstruction() != 0) return 1;
    std::puts("mist_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 11)");
    return 0;
}
