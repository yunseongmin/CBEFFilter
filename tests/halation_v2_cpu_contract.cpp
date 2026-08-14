#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string_view>
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
using cbef::ParameterGroup;
using cbef::PixelFormat;
using cbef::RectI;
using cbef::RenderRequest;
using cbef::RenderScale;
using cbef::SubmissionKind;

constexpr std::size_t kRgbaBytes = sizeof(float) * 4U;
constexpr std::uint8_t kSentinel = 0xA5U;

int fail(const char* message)
{
    std::fprintf(stderr, "halation_v2_cpu_contract: %s\n", message);
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

FrameSurface surface(void* data, const CpuFrame& frame)
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
                         surface(frame.source.data(), frame),
                         surface(frame.destination.data(), frame),
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height},
                         12.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         cbef::defaultSettings(EffectId::Halation)};
}

void fill(CpuFrame& frame, float r, float g, float b, float alpha = 1.0F)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* value = pixel(frame.source, frame, x, y);
            value[0] = r;
            value[1] = g;
            value[2] = b;
            value[3] = alpha;
        }
    }
}

bool configureLocal(RenderRequest& request, int output_view, float threshold = 2.0F)
{
    return cbef::setSetting(request.settings, "working_mode", 1) &&
           cbef::setSetting(request.settings, "amount", 100.0) &&
           cbef::setSetting(request.settings, "radius", 1.0) &&
           cbef::setSetting(request.settings, "global_diffusion", 25.0) &&
           cbef::setSetting(request.settings, "threshold", static_cast<double>(threshold)) &&
           cbef::setSetting(request.settings, "source_smoothness", 60.0) &&
           cbef::setSetting(request.settings, "core_protection", 100.0) &&
           cbef::setSetting(request.settings, "background_adaptation", 70.0) &&
           cbef::setSetting(request.settings, "warmth", 65.0) &&
           cbef::setSetting(request.settings, "saturation", 55.0) &&
           cbef::setSetting(request.settings, "red_bias", 78.0) &&
           cbef::setSetting(request.settings, "blue_compensation", 18.0) &&
           cbef::setSetting(request.settings, "output_view", output_view);
}

float rgbEnergy(const float* value)
{
    return std::abs(value[0]) + std::abs(value[1]) + std::abs(value[2]);
}

double annulusEnergy(const CpuFrame& frame, int center_x, int center_y, float inner, float outer)
{
    double total = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float dx = static_cast<float>(x - center_x);
            const float dy = static_cast<float>(y - center_y);
            const float radius = std::sqrt(dx * dx + dy * dy);
            if (radius >= inner && radius <= outer) {
                total += rgbEnergy(pixel(frame.destination, frame, x, y));
            }
        }
    }
    return total;
}

double halationLuminance(const float* value)
{
    return std::max(0.0, 0.27411851 * std::max(0.0F, value[0]) +
                             0.87363190 * std::max(0.0F, value[1]) -
                             0.14775041 * std::max(0.0F, value[2]));
}

double annulusLuminance(const CpuFrame& frame, int center_x, int center_y, float inner, float outer)
{
    double total = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float dx = static_cast<float>(x - center_x);
            const float dy = static_cast<float>(y - center_y);
            const float radius = std::sqrt(dx * dx + dy * dy);
            if (radius >= inner && radius <= outer) {
                total += halationLuminance(pixel(frame.destination, frame, x, y));
            }
        }
    }
    return total;
}

std::array<double, 3> annulusChannels(const CpuFrame& frame, int center_x, int center_y, float inner, float outer)
{
    std::array<double, 3> total{};
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float dx = static_cast<float>(x - center_x);
            const float dy = static_cast<float>(y - center_y);
            const float radius = std::sqrt(dx * dx + dy * dy);
            if (radius >= inner && radius <= outer) {
                const float* value = pixel(frame.destination, frame, x, y);
                for (std::size_t channel = 0; channel < total.size(); ++channel) {
                    total[channel] += std::max(0.0F, value[channel]);
                }
            }
        }
    }
    const double sum = total[0] + total[1] + total[2];
    if (sum > 0.0) {
        for (double& channel : total) channel /= sum;
    }
    return total;
}

double chromaDistance(const std::array<double, 3>& left, const std::array<double, 3>& right)
{
    return std::abs(left[0] - right[0]) + std::abs(left[1] - right[1]) + std::abs(left[2] - right[2]);
}

struct ColorFixture {
    std::array<float, 3> color;
    int color_mode;
    int output_view = 3;
    double color_strength = 100.0;
};

int renderColorFixture(CpuFrame& frame, const ColorFixture& fixture)
{
    fill(frame, 0.01F, 0.01F, 0.01F);
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    for (int y = center_y - 1; y <= center_y + 1; ++y) {
        for (int x = center_x - 1; x <= center_x + 1; ++x) {
            float* source = pixel(frame.source, frame, x, y);
            source[0] = fixture.color[0] * 4.0F;
            source[1] = fixture.color[1] * 4.0F;
            source[2] = fixture.color[2] * 4.0F;
        }
    }
    RenderRequest request = requestFor(frame);
    if (!configureLocal(request, fixture.output_view) ||
        !cbef::setSetting(request.settings, "color_emphasis", fixture.color_mode) ||
        !cbef::setSetting(request.settings, "color_strength", fixture.color_strength)) {
        return fail("Auto color fixture settings must be accepted");
    }
    CpuRenderBackend backend;
    return cbef::render(request, backend).kind == SubmissionKind::Completed
               ? 0
               : fail("Auto color fixture must render through the public CPU contract");
}

const cbef::ParameterDefinition* parameter(const EffectDefinition& definition, std::string_view id)
{
    for (const cbef::ParameterDefinition& candidate : definition.parameters) {
        if (id == candidate.id) {
            return &candidate;
        }
    }
    return nullptr;
}

int testMetadata()
{
    const EffectDefinition& definition = cbef::effectDefinition(EffectId::Halation);
    const cbef::ParameterDefinition* source_limit = parameter(definition, "threshold");
    const cbef::ParameterDefinition* smoothness = parameter(definition, "source_smoothness");
    const cbef::ParameterDefinition* radius = parameter(definition, "radius");
    const cbef::ParameterDefinition* strength = parameter(definition, "amount");
    const cbef::ParameterDefinition* core_protection = parameter(definition, "core_protection");
    const cbef::ParameterDefinition* adaptation = parameter(definition, "background_adaptation");
    const cbef::ParameterDefinition* global_diffusion = parameter(definition, "global_diffusion");
    const cbef::ParameterDefinition* red_bias = parameter(definition, "red_bias");
    const cbef::ParameterDefinition* blue_compensation = parameter(definition, "blue_compensation");
    const cbef::ParameterDefinition* color_emphasis = parameter(definition, "color_emphasis");
    const cbef::ParameterDefinition* color_strength = parameter(definition, "color_strength");
    CHECK(source_limit != nullptr && smoothness != nullptr && radius != nullptr && strength != nullptr &&
              core_protection != nullptr && adaptation != nullptr && global_diffusion != nullptr &&
              red_bias != nullptr && blue_compensation != nullptr && color_emphasis != nullptr &&
              color_strength != nullptr,
          "Halation v2 must expose source, local/global shape, strength, core, background, and profile controls");
    CHECK(source_limit->group == ParameterGroup::Basic && smoothness->group == ParameterGroup::Basic &&
              radius->group == ParameterGroup::Basic && strength->group == ParameterGroup::Basic,
          "Halation Basic must contain the natural local-halo controls");
    CHECK(core_protection->group == ParameterGroup::Advanced && adaptation->group == ParameterGroup::Advanced,
          "Halation core and background controls must remain available in Advanced");
    CHECK(global_diffusion->group == ParameterGroup::Basic && red_bias->group == ParameterGroup::Advanced &&
              blue_compensation->group == ParameterGroup::Advanced,
          "Global Diffusion is a Basic shape control and profile-relative channel controls are Advanced");
    CHECK(std::string_view(red_bias->hint).find("Profile-relative") != std::string_view::npos &&
              std::string_view(blue_compensation->hint).find("Profile-relative") != std::string_view::npos,
          "channel controls must disclose profile-relative rather than measured stock semantics");
    CHECK(color_emphasis->group == ParameterGroup::Basic && color_strength->group == ParameterGroup::Basic &&
              std::get<int>(color_emphasis->default_value) == 0 &&
              color_emphasis->choices.size() == 5U &&
              std::string_view(color_emphasis->choices[0]) == "Profile Relative" &&
              std::string_view(color_emphasis->choices[1]) == "Film Red" &&
              std::string_view(color_emphasis->choices[2]) == "Warm Amber" &&
              std::string_view(color_emphasis->choices[3]) == "Neutral White (Artistic)" &&
              std::string_view(color_emphasis->choices[4]) == "Auto (Scene Adaptive)",
          "Color Emphasis must be append-safe, default to Profile Relative, and disclose the artistic white mode");
    CHECK(definition.parameters.size() >= 2U &&
              std::string_view(definition.parameters[definition.parameters.size() - 2U].id) == "color_emphasis" &&
              std::string_view(definition.parameters.back().id) == "color_strength",
          "new Halation controls must append after every existing parameter ordinal");
    CHECK(std::string_view(color_emphasis->hint).find("scene-adaptive") != std::string_view::npos &&
              std::string_view(color_emphasis->hint).find("optical bloom/glare hybrid") != std::string_view::npos,
          "help must explain Auto scene adaptation and the artistic Neutral White mode");
    CHECK(definition.presets.size() == 5U &&
              std::string_view(definition.presets[0].label) == "Generic Subtle" &&
              std::string_view(definition.presets[1].label) == "Generic Warm" &&
              std::string_view(definition.presets[2].label) == "Strong Halo (Uncalibrated)" &&
              std::string_view(definition.presets[3].label) == "Film Red Emphasis (Uncalibrated)" &&
              std::string_view(definition.presets[4].label) == "Neutral White Hybrid (Artistic)",
          "the three existing preset ordinals must remain stable before the appended emphasis presets");
    const cbef::Settings red_preset = cbef::settingsForPreset(EffectId::Halation, 3U);
    const cbef::Settings white_preset = cbef::settingsForPreset(EffectId::Halation, 4U);
    CHECK(cbef::settingChoice(red_preset, "preset") == 3 &&
              cbef::settingChoice(red_preset, "color_emphasis") == 1 &&
              std::get<double>(cbef::settingValue(red_preset, "color_strength")) >= 90.0 &&
              cbef::settingsUsePreset(red_preset),
          "Film Red emphasis preset must remain selectable with an uncalibrated strong target");
    CHECK(cbef::settingChoice(white_preset, "preset") == 4 &&
              cbef::settingChoice(white_preset, "color_emphasis") == 3 &&
              std::get<double>(cbef::settingValue(white_preset, "color_strength")) == 100.0 &&
              cbef::settingsUsePreset(white_preset),
          "Neutral White artistic hybrid preset must remain selectable at full neutral chroma");
    CHECK(definition.parameters[1].choices.size() == 5U &&
              std::string_view(definition.parameters[1].choices[2]) == "Source Mask" &&
              std::string_view(definition.parameters[1].choices[3]) == "Local Only",
          "Halation diagnostics must expose Source Mask and Local Only");
    return 0;
}

int testColorEmphasis()
{
    constexpr int center_x = 64;
    constexpr int center_y = 32;
    std::array<CpuFrame, 4> frames = {CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65)};
    CpuRenderBackend backend;
    for (std::size_t mode = 0; mode < frames.size(); ++mode) {
        CpuFrame& frame = frames[mode];
        fill(frame, 0.01F, 0.01F, 0.01F);
        for (int y = center_y - 1; y <= center_y + 1; ++y) {
            for (int x = center_x - 1; x <= center_x + 1; ++x) {
                float* source = pixel(frame.source, frame, x, y);
                source[0] = 4.0F;
                source[1] = 4.0F;
                source[2] = 4.0F;
            }
        }
        RenderRequest request = requestFor(frame);
        CHECK(configureLocal(request, 3) &&
                  cbef::setSetting(request.settings, "color_emphasis", static_cast<int>(mode)) &&
                  cbef::setSetting(request.settings, "color_strength", 100.0),
              "each Color Emphasis mode must be accepted through typed settings");
        CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
              "each Color Emphasis mode must render through the CPU reference");
    }

    const float* profile = pixel(frames[0].destination, frames[0], center_x + 2, center_y);
    CHECK(profile[0] == 0x1.8e659cp-2F && profile[1] == 0x1.1e1ccap-2F &&
              profile[2] == 0x1.c5641ap-3F,
          "Profile Relative must remain bit-equivalent to the pre-emphasis CPU fixture");
    const float* red = pixel(frames[1].destination, frames[1], center_x + 2, center_y);
    const float* amber = pixel(frames[2].destination, frames[2], center_x + 2, center_y);
    const float* white = pixel(frames[3].destination, frames[3], center_x + 2, center_y);
    CHECK(red[0] == 0x1.8f1dc6p-1F && red[1] == 0x1.fede6cp-4F && red[2] == 0x1.fede6cp-6F,
          "Film Red must remain bit-equivalent to its pre-Auto CPU fixture");
    CHECK(amber[0] == 0x1.b9f48ap-2F && amber[1] == 0x1.e62696p-3F && amber[2] == 0x1.a846e8p-5F,
          "Warm Amber must remain bit-equivalent to its pre-Auto CPU fixture");
    CHECK(white[0] == 0x1.45abacp-2F && white[1] == 0x1.45abacp-2F && white[2] == 0x1.45abacp-2F,
          "Neutral White must remain bit-equivalent to its pre-Auto CPU fixture");
    CHECK(red[0] > red[1] && red[1] > red[2] && amber[0] > amber[1] && amber[1] > amber[2],
          "Film Red and Warm Amber must have ordered warm chroma");
    CHECK(red[1] / red[0] < amber[1] / amber[0] && amber[2] / amber[0] > red[2] / red[0],
          "Film Red must be redder while Warm Amber retains more green and blue energy");
    const float white_max = std::max({white[0], white[1], white[2]});
    const float white_min = std::min({white[0], white[1], white[2]});
    CHECK(white_max - white_min <= std::max(1.0e-6F, white_max * 2.0e-5F),
          "Neutral White artistic mode must converge to neutral chroma at full color strength");

    const double profile_luminance = annulusLuminance(frames[0], center_x, center_y, 2.0F, 24.0F);
    CHECK(profile_luminance > 0.0, "Profile Relative fixture must contain halo luminance");
    for (std::size_t mode = 1; mode < frames.size(); ++mode) {
        const double emphasized_luminance = annulusLuminance(frames[mode], center_x, center_y, 2.0F, 24.0F);
        CHECK(std::abs(emphasized_luminance - profile_luminance) / profile_luminance <= 2.0e-5,
              "Color Emphasis must preserve scene-linear halo luminance energy");
    }
    return 0;
}

int testAutoColorSceneResponse()
{
    constexpr int center_x = 64;
    constexpr int center_y = 32;
    constexpr std::array<std::array<float, 3>, 4> colors = {{{1.0F, 1.0F, 1.0F},
                                                               {1.0F, 0.58F, 0.22F},
                                                               {0.08F, 0.18F, 1.0F},
                                                               {0.08F, 1.0F, 0.14F}}};
    std::array<std::array<CpuFrame, 4>, 4> frames = {{
        {CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65)},
        {CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65)},
        {CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65)},
        {CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65), CpuFrame(129, 65)},
    }};
    for (std::size_t fixture = 0; fixture < colors.size(); ++fixture) {
        for (std::size_t mode = 0; mode < frames[fixture].size(); ++mode) {
            const int color_mode = mode == 0U ? 1 : mode == 1U ? 2 : mode == 2U ? 3 : 4;
            if (const int result = renderColorFixture(frames[fixture][mode], {colors[fixture], color_mode}); result != 0) {
                return result;
            }
        }
    }

    for (std::size_t fixture = 0; fixture < colors.size(); ++fixture) {
        const std::array<double, 3> red = annulusChannels(frames[fixture][0], center_x, center_y, 2.0F, 24.0F);
        const std::array<double, 3> amber = annulusChannels(frames[fixture][1], center_x, center_y, 2.0F, 24.0F);
        const std::array<double, 3> white = annulusChannels(frames[fixture][2], center_x, center_y, 2.0F, 24.0F);
        const std::array<double, 3> automatic = annulusChannels(frames[fixture][3], center_x, center_y, 2.0F, 24.0F);
        if (fixture == 0U) {
            CHECK(chromaDistance(automatic, red) < chromaDistance(automatic, amber),
                  "neutral low-chroma Auto halo must favor Film Red");
        } else if (fixture == 1U) {
            CHECK(chromaDistance(automatic, amber) < chromaDistance(automatic, red),
                  "warm tungsten Auto halo must favor Warm Amber");
        } else {
            CHECK(chromaDistance(automatic, white) < chromaDistance(automatic, amber) &&
                      chromaDistance(automatic, white) < chromaDistance(automatic, red),
                  "strong blue and green Auto halos must move toward Neutral White");
        }
    }

    for (const std::array<float, 3>& color : colors) {
        CpuFrame profile(129, 65);
        CpuFrame automatic(129, 65);
        if (const int result = renderColorFixture(profile, {color, 0}); result != 0) return result;
        if (const int result = renderColorFixture(automatic, {color, 4}); result != 0) return result;
        const double profile_luminance = annulusLuminance(profile, center_x, center_y, 2.0F, 24.0F);
        const double auto_luminance = annulusLuminance(automatic, center_x, center_y, 2.0F, 24.0F);
        CHECK(profile_luminance > 0.0 &&
                  std::abs(auto_luminance - profile_luminance) / profile_luminance <= 3.0e-5,
              "Auto must preserve scene-linear annulus luminance");
    }

    CpuFrame boundary_low(129, 65);
    CpuFrame boundary_high(129, 65);
    CHECK(renderColorFixture(boundary_low, {{1.0F, 0.90F, 0.81F}, 4}) == 0 &&
              renderColorFixture(boundary_high, {{1.0F, 0.90F, 0.809F}, 4}) == 0,
          "near-boundary Auto fixtures must render");
    const std::array<double, 3> low = annulusChannels(boundary_low, center_x, center_y, 2.0F, 24.0F);
    const std::array<double, 3> high = annulusChannels(boundary_high, center_x, center_y, 2.0F, 24.0F);
    CHECK(chromaDistance(low, high) <= 0.015,
          "small hue/chroma perturbations must produce a bounded continuous Auto change");

    CpuFrame strength_zero(129, 65);
    CpuFrame strength_half(129, 65);
    CpuFrame strength_full(129, 65);
    CHECK(renderColorFixture(strength_zero, {colors[1], 4, 3, 0.0}) == 0 &&
              renderColorFixture(strength_half, {colors[1], 4, 3, 50.0}) == 0 &&
              renderColorFixture(strength_full, {colors[1], 4, 3, 100.0}) == 0,
          "Auto Color Strength fixtures must render");
    const float* zero = pixel(strength_zero.destination, strength_zero, center_x + 2, center_y);
    const float* half = pixel(strength_half.destination, strength_half, center_x + 2, center_y);
    const float* full = pixel(strength_full.destination, strength_full, center_x + 2, center_y);
    for (int channel = 0; channel < 3; ++channel) {
        CHECK(std::abs(half[channel] - (zero[channel] + full[channel]) * 0.5F) <= 1.0e-6F,
              "Color Strength must blend linearly from Profile Relative into the Auto target");
    }

    CpuFrame mask_profile(65, 33);
    CpuFrame mask_auto(65, 33);
    CHECK(renderColorFixture(mask_profile, {colors[2], 0, 2}) == 0 &&
              renderColorFixture(mask_auto, {colors[2], 4, 2}) == 0,
          "Source Mask comparison fixtures must render");
    CHECK(mask_profile.destination == mask_auto.destination,
          "Source Mask must be independent of Auto color analysis");
    return 0;
}

int testSourceResponseContinuity()
{
    constexpr std::array<std::array<float, 3>, 4> colors = {{{1.0F, 1.0F, 1.0F},
                                                               {1.0F, 0.58F, 0.22F},
                                                               {0.08F, 0.18F, 1.0F},
                                                               {1.0F, 0.03F, 0.02F}}};
    constexpr std::array<float, 7> exposures = {0.20F, 0.35F, 0.60F, 1.0F, 1.7F, 3.0F, 5.0F};
    CpuRenderBackend backend;
    for (const std::array<float, 3>& color : colors) {
        float previous = -1.0F;
        for (float exposure : exposures) {
            CpuFrame frame(33, 17);
            fill(frame, 0.01F, 0.01F, 0.01F);
            float* source = pixel(frame.source, frame, 16, 8);
            source[0] = color[0] * exposure;
            source[1] = color[1] * exposure;
            source[2] = color[2] * exposure;
            RenderRequest request = requestFor(frame);
            CHECK(configureLocal(request, 2, 1.0F), "source-continuity settings must be accepted");
            CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
                  "Source Mask must render through the public CPU contract");
            const float current = pixel(frame.destination, frame, 16, 8)[0];
            CHECK(current >= previous - 1.0e-6F, "source mask must be monotonic across an exposure sweep");
            CHECK(previous < 0.0F || current - previous <= 0.52F,
                  "source mask must not pop abruptly at the source limit");
            previous = current;
        }
        CHECK(previous >= 0.75F, "neutral, tungsten, blue LED, and saturated red sources must all reach the mask");
    }
    return 0;
}

int testAutoSignedPremultipliedSafety()
{
    CpuFrame hidden(33, 17, -3, 4, 16U);
    CpuFrame clear(33, 17, -3, 4, 16U);
    for (CpuFrame* frame : {&hidden, &clear}) {
        fill(*frame, -0.20F, 0.05F, 0.10F, 0.50F);
        float* source = pixel(frame->source, *frame, 13, 12);
        source[0] = 2.0F;
        source[1] = 0.60F;
        source[2] = 0.15F;
        source[3] = 0.50F;
        float* transparent = pixel(frame->source, *frame, 14, 12);
        transparent[0] = 0.0F;
        transparent[1] = 0.0F;
        transparent[2] = 0.0F;
        transparent[3] = 0.0F;
    }
    float* hidden_source = pixel(hidden.source, hidden, 14, 12);
    hidden_source[0] = 100.0F;
    hidden_source[1] = 50.0F;
    hidden_source[2] = 25.0F;

    CpuRenderBackend backend;
    for (CpuFrame* frame : {&hidden, &clear}) {
        RenderRequest request = requestFor(*frame);
        CHECK(configureLocal(request, 0, -2.0F) &&
                  cbef::setSetting(request.settings, "color_emphasis", 4) &&
                  cbef::setSetting(request.settings, "color_strength", 100.0),
              "signed premultiplied Auto settings must be accepted");
        request.alpha_association = AlphaAssociation::Premultiplied;
        CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
              "signed premultiplied Auto fixture must render");
    }
    for (int y = hidden.bounds.y; y < hidden.bounds.y + hidden.bounds.height; ++y) {
        for (int x = hidden.bounds.x; x < hidden.bounds.x + hidden.bounds.width; ++x) {
            const float* hidden_output = pixel(hidden.destination, hidden, x, y);
            const float* clear_output = pixel(clear.destination, clear, x, y);
            for (int channel = 0; channel < 3; ++channel) {
                CHECK(hidden_output[channel] == clear_output[channel],
                      "zero-alpha hidden RGB must not influence Auto analysis or halo output");
                CHECK(std::isfinite(hidden_output[channel]), "premultiplied Auto output must stay finite");
            }
            std::uint32_t source_alpha = 0U;
            std::uint32_t output_alpha = 0U;
            std::memcpy(&source_alpha, &pixel(hidden.source, hidden, x, y)[3], sizeof(source_alpha));
            std::memcpy(&output_alpha, &hidden_output[3], sizeof(output_alpha));
            CHECK(source_alpha == output_alpha, "premultiplied Auto must preserve alpha bits");
        }
    }
    const float* signed_corner = pixel(hidden.destination, hidden, hidden.bounds.x, hidden.bounds.y);
    CHECK(signed_corner[0] < 0.0F,
          "Auto must preserve a negative signed residual where no positive halo reaches the background");
    const float* transparent_output = pixel(hidden.destination, hidden, 14, 12);
    CHECK(transparent_output[0] == 0.0F && transparent_output[1] == 0.0F && transparent_output[2] == 0.0F,
          "zero-alpha hidden RGB must not leak into its own premultiplied output");
    return 0;
}

int testLocalDiagnosticsAndCore()
{
    CpuFrame source_mask(129, 65);
    fill(source_mask, 0.01F, 0.01F, 0.01F);
    constexpr int center_x = 64;
    constexpr int center_y = 32;
    for (int y = center_y - 1; y <= center_y + 1; ++y) {
        for (int x = center_x - 1; x <= center_x + 1; ++x) {
            float* value = pixel(source_mask.source, source_mask, x, y);
            value[0] = 4.0F;
            value[1] = 4.0F;
            value[2] = 4.0F;
        }
    }
    CpuRenderBackend backend;
    RenderRequest mask_request = requestFor(source_mask);
    CHECK(configureLocal(mask_request, 2), "Source Mask settings must be accepted");
    CHECK(cbef::setSetting(mask_request.settings, "mix", 0.0), "diagnostic mix mutation must be accepted");
    CHECK(cbef::render(mask_request, backend).kind == SubmissionKind::Completed,
          "Source Mask must ignore Final mix and complete");
    CHECK(pixel(source_mask.destination, source_mask, center_x, center_y)[0] >= 0.95F,
          "Source Mask must reveal the selected source with Final mix at zero");

    CpuFrame local_only = source_mask;
    std::fill(local_only.destination.begin(), local_only.destination.end(), kSentinel);
    RenderRequest local_request = requestFor(local_only);
    CHECK(configureLocal(local_request, 3), "Local Only settings must be accepted");
    CHECK(cbef::setSetting(local_request.settings, "mix", 0.0), "Local Only diagnostic mix mutation must be accepted");
    CHECK(cbef::render(local_request, backend).kind == SubmissionKind::Completed,
          "Local Only must ignore Final mix and complete");
    const float exterior_energy = rgbEnergy(pixel(local_only.destination, local_only, center_x + 2, center_y));
    const float core_energy = rgbEnergy(pixel(local_only.destination, local_only, center_x, center_y));
    CHECK(exterior_energy > 1.0e-5F, "Local Only must place visible energy outside the source core");
    CHECK(core_energy <= exterior_energy * 0.10F,
          "Core Protection must keep the local component out of the neutral highlight center");
    const float* exterior = pixel(local_only.destination, local_only, center_x + 2, center_y);
    CHECK(exterior[0] > exterior[1] && exterior[1] > exterior[2] && exterior[1] > exterior[0] * 0.15F,
          "the generic warm local halo must not collapse to a hard red outline or white bloom");

    CpuFrame halation_only = source_mask;
    std::fill(halation_only.destination.begin(), halation_only.destination.end(), kSentinel);
    RenderRequest halation_request = requestFor(halation_only);
    CHECK(configureLocal(halation_request, 1), "Halation Only settings must be accepted");
    CHECK(cbef::render(halation_request, backend).kind == SubmissionKind::Completed,
          "Halation Only must render through the CPU reference");
    CpuFrame global_only = source_mask;
    std::fill(global_only.destination.begin(), global_only.destination.end(), kSentinel);
    RenderRequest global_request = requestFor(global_only);
    CHECK(configureLocal(global_request, 4), "Global Only settings must be accepted");
    CHECK(cbef::setSetting(global_request.settings, "radius", 0.0),
          "Global Only reconstruction must allow Local Radius zero");
    CHECK(cbef::render(global_request, backend).kind == SubmissionKind::Completed,
          "Global Only must render through the CPU reference");
    CHECK(annulusEnergy(global_only, center_x, center_y, 8.0F, 24.0F) > 0.0,
          "Global Only must place weak energy beyond the local halo radius");

    for (int y = halation_only.bounds.y; y < halation_only.bounds.y + halation_only.bounds.height; ++y) {
        for (int x = halation_only.bounds.x; x < halation_only.bounds.x + halation_only.bounds.width; ++x) {
            const float* combined = pixel(halation_only.destination, halation_only, x, y);
            const float* local = pixel(local_only.destination, local_only, x, y);
            const float* global = pixel(global_only.destination, global_only, x, y);
            for (int channel = 0; channel < 3; ++channel) {
                CHECK(std::abs(combined[channel] - local[channel] - global[channel]) <= 1.0e-5F,
                      "Halation Only must reconstruct as Local Only plus Global Only");
            }
        }
    }
    const float* global_edge = pixel(global_only.destination, global_only, center_x + 8, center_y);
    CHECK(global_edge[0] > global_edge[1] && global_edge[1] > global_edge[2] * 0.45F,
          "generic profile must retain a red-dominant but non-white global response");

    CpuFrame strong = source_mask;
    std::fill(strong.destination.begin(), strong.destination.end(), kSentinel);
    RenderRequest strong_request = requestFor(strong);
    CHECK(configureLocal(strong_request, 0, 0.5F) &&
              cbef::setSetting(strong_request.settings, "amount", 200.0) &&
              cbef::setSetting(strong_request.settings, "radius", 2.0) &&
              cbef::setSetting(strong_request.settings, "global_diffusion", 60.0) &&
              cbef::setSetting(strong_request.settings, "core_protection", 100.0) &&
              cbef::setSetting(strong_request.settings, "red_bias", 100.0) &&
              cbef::setSetting(strong_request.settings, "blue_compensation", 0.0) &&
              cbef::setSetting(strong_request.settings, "warmth", 100.0) &&
              cbef::setSetting(strong_request.settings, "saturation", 100.0),
          "strong profile settings must be accepted");
    CHECK(cbef::render(strong_request, backend).kind == SubmissionKind::Completed,
          "strong profile must render through the CPU reference");
    const float* strong_core = pixel(strong.destination, strong, center_x, center_y);
    CHECK(strong_core[0] < 5.0F && strong_core[1] < 5.0F && strong_core[2] < 5.0F,
          "core protection must prevent strong settings from forming a white center veil");
    const float* strong_far = pixel(strong.destination, strong, center_x + 8, center_y);
    CHECK(strong_far[0] > strong_far[1] && strong_far[2] < strong_far[0] * 0.95F,
          "strong settings must retain profile color separation instead of a white bloom");
    return 0;
}

int renderBackgroundFixture(CpuFrame& frame, float background)
{
    fill(frame, background, background, background);
    const int center_x = frame.bounds.x + frame.bounds.width / 2;
    const int center_y = frame.bounds.y + frame.bounds.height / 2;
    for (int y = center_y - 1; y <= center_y + 1; ++y) {
        for (int x = center_x - 1; x <= center_x + 1; ++x) {
            float* value = pixel(frame.source, frame, x, y);
            value[0] = 4.0F;
            value[1] = 4.0F;
            value[2] = 4.0F;
        }
    }
    CpuRenderBackend backend;
    RenderRequest request = requestFor(frame);
    if (!configureLocal(request, 3, 4.0F) ||
        !cbef::setSetting(request.settings, "source_smoothness", 10.0) ||
        !cbef::setSetting(request.settings, "background_adaptation", 100.0)) {
        return fail("background fixture settings must be accepted");
    }
    return cbef::render(request, backend).kind == SubmissionKind::Completed ? 0
                                                                              : fail("background fixture must render");
}

int testBackgroundAdaptation()
{
    CpuFrame dark(129, 65);
    CpuFrame bright(129, 65);
    if (const int result = renderBackgroundFixture(dark, 0.01F); result != 0) {
        return result;
    }
    if (const int result = renderBackgroundFixture(bright, 1.0F); result != 0) {
        return result;
    }
    const int center_x = dark.bounds.width / 2;
    const int center_y = dark.bounds.height / 2;
    const double dark_energy = annulusEnergy(dark, center_x, center_y, 3.0F, 16.0F);
    const double bright_energy = annulusEnergy(bright, center_x, center_y, 3.0F, 16.0F);
    CHECK(dark_energy > 0.0 && bright_energy < dark_energy,
          "the same source must have less visible local impact on a bright background");
    return 0;
}

int testCpuSafetyAndResolution()
{
    CpuFrame straight(11, 7);
    fill(straight, 0.05F, 0.08F, 0.12F, 0.40F);
    float* straight_source = pixel(straight.source, straight, 5, 3);
    straight_source[0] = 3.0F;
    straight_source[1] = 2.0F;
    straight_source[2] = 1.0F;
    RenderRequest straight_request = requestFor(straight);
    CHECK(configureLocal(straight_request, 3, -2.0F), "straight-alpha settings must be accepted");
    CpuRenderBackend backend;
    CHECK(cbef::render(straight_request, backend).kind == SubmissionKind::Completed,
          "straight-alpha local CPU render must complete");
    for (int y = straight.bounds.y; y < straight.bounds.y + straight.bounds.height; ++y) {
        for (int x = straight.bounds.x; x < straight.bounds.x + straight.bounds.width; ++x) {
            std::uint32_t source_alpha = 0U;
            std::uint32_t output_alpha = 0U;
            std::memcpy(&source_alpha, &pixel(straight.source, straight, x, y)[3], sizeof(source_alpha));
            std::memcpy(&output_alpha, &pixel(straight.destination, straight, x, y)[3], sizeof(output_alpha));
            CHECK(source_alpha == output_alpha, "straight-alpha CPU local halo must preserve alpha bits");
        }
    }

    CpuFrame frame(19, 13, -7, 5, 20U);
    fill(frame, -0.25F, 0.05F, 2.5F, 0.75F);
    float* hidden = pixel(frame.source, frame, 2, 8);
    hidden[0] = 10.0F;
    hidden[1] = 5.0F;
    hidden[2] = 2.0F;
    hidden[3] = 0.0F;
    float* strong_hdr = pixel(frame.source, frame, 0, 10);
    strong_hdr[0] = 24.0F;
    strong_hdr[1] = 8.0F;
    strong_hdr[2] = 2.0F;
    RenderRequest request = requestFor(frame);
    CHECK(configureLocal(request, 0, -2.0F), "CPU safety settings must be accepted");
    CHECK(cbef::setSetting(request.settings, "amount", 200.0) &&
              cbef::setSetting(request.settings, "color_emphasis", 4) &&
              cbef::setSetting(request.settings, "color_strength", 100.0),
          "strong Auto safety settings must be accepted");
    request.alpha_association = AlphaAssociation::Premultiplied;
    request.render_window = RectI{-6, 6, 10, 16};
    CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
          "signed HDR, alpha, non-zero-origin crop must complete on the CPU reference");
    bool saw_unclamped_hdr = false;
    for (int y = request.render_window.y1; y < request.render_window.y2; ++y) {
        for (int x = request.render_window.x1; x < request.render_window.x2; ++x) {
            const float* output = pixel(frame.destination, frame, x, y);
            saw_unclamped_hdr = saw_unclamped_hdr || output[0] > 1.0F || output[1] > 1.0F || output[2] > 1.0F;
            CHECK(std::isfinite(output[0]) && std::isfinite(output[1]) && std::isfinite(output[2]),
                  "CPU local halo output must remain finite for signed HDR input");
            std::uint32_t source_alpha = 0U;
            std::uint32_t output_alpha = 0U;
            std::memcpy(&source_alpha, &pixel(frame.source, frame, x, y)[3], sizeof(source_alpha));
            std::memcpy(&output_alpha, &output[3], sizeof(output_alpha));
            CHECK(source_alpha == output_alpha, "CPU local halo must preserve alpha bit patterns");
        }
    }
    CHECK(saw_unclamped_hdr, "strong Auto output must preserve unclamped HDR halo energy");
    for (int channel = 0; channel < 3; ++channel) {
        CHECK(std::abs(pixel(frame.destination, frame, 2, 8)[channel]) <= 1.0e-6F,
              "transparent pixels must not emit local halo RGB");
    }
    CHECK(frame.destination.front() == kSentinel, "cropped CPU render must preserve bytes outside the render window");

    CpuFrame edge(33, 17);
    fill(edge, 0.01F, 0.01F, 0.01F);
    float* edge_source = pixel(edge.source, edge, edge.bounds.x, edge.bounds.y + edge.bounds.height / 2);
    edge_source[0] = 4.0F;
    edge_source[1] = 4.0F;
    edge_source[2] = 4.0F;
    RenderRequest edge_request = requestFor(edge);
    CHECK(configureLocal(edge_request, 3, -2.0F), "edge settings must be accepted");
    CHECK(cbef::render(edge_request, backend).kind == SubmissionKind::Completed,
          "edge-local CPU render must complete");
    CHECK(rgbEnergy(pixel(edge.destination, edge, edge.bounds.x + edge.bounds.width - 1,
                          edge.bounds.y + edge.bounds.height / 2)) <= 1.0e-7F,
          "local scatter must not wrap an edge source to the opposite frame edge");

    CpuFrame low(128, 72);
    CpuFrame high(256, 144);
    for (CpuFrame* candidate : {&low, &high}) {
        fill(*candidate, 0.01F, 0.01F, 0.01F);
        const int center_x = candidate->bounds.width / 2;
        const int center_y = candidate->bounds.height / 2;
        const int source_radius = std::max(1, candidate->bounds.height / 36);
        for (int y = center_y - source_radius; y <= center_y + source_radius; ++y) {
            for (int x = center_x - source_radius; x <= center_x + source_radius; ++x) {
                float* value = pixel(candidate->source, *candidate, x, y);
                value[0] = 4.0F;
                value[1] = 4.0F;
                value[2] = 4.0F;
            }
        }
        RenderRequest scaled_request = requestFor(*candidate);
        CHECK(configureLocal(scaled_request, 3), "resolution settings must be accepted");
        CHECK(cbef::render(scaled_request, backend).kind == SubmissionKind::Completed,
              "each resolution must render via the CPU reference");
    }
    const double low_energy = annulusEnergy(low, 64, 36, 4.0F, 14.0F) / static_cast<double>(low.bounds.height);
    const double high_energy = annulusEnergy(high, 128, 72, 8.0F, 28.0F) / static_cast<double>(high.bounds.height);
    CHECK(low_energy > 0.0 && high_energy > 0.0 &&
              std::abs(low_energy - high_energy) / std::max(low_energy, high_energy) < 0.35,
          "Local Radius must remain materially stable across CPU reference resolutions");
    return 0;
}

} 

int main()
{
    if (const int result = testMetadata(); result != 0) return result;
    if (const int result = testColorEmphasis(); result != 0) return result;
    if (const int result = testAutoColorSceneResponse(); result != 0) return result;
    if (const int result = testSourceResponseContinuity(); result != 0) return result;
    if (const int result = testAutoSignedPremultipliedSafety(); result != 0) return result;
    if (const int result = testLocalDiagnosticsAndCore(); result != 0) return result;
    if (const int result = testBackgroundAdaptation(); result != 0) return result;
    if (const int result = testCpuSafetyAndResolution(); result != 0) return result;
    std::puts("halation_v2_cpu_contract: PASS (CPU reference only; Metal parity is ticket 08)");
    return 0;
}
