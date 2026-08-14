#include "cbef/RenderCore.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <utility>

#include "RenderPlan.h"
#include "OpticalSampling.h"

namespace cbef {
namespace {

constexpr float kTransparentAlpha = 1.0e-6F;
constexpr std::array<float, 3> kHalationSigmaFactors = {0.35F, 0.75F, 1.5F};
constexpr std::array<float, 3> kHalationWeights = {0.50F, 0.35F, 0.15F};

struct Rgb {
    double r;
    double g;
    double b;
};

struct HalationSample {
    float r;
    float g;
    float b;
    float alpha_weight;
    float source_matte;
};

struct HalationRgb {
    float r;
    float g;
    float b;
};

constexpr std::array<float, 5> kGrainCaptureDiameters = {1.80F, 1.10F, 1.35F, 0.80F, 2.45F};
constexpr std::array<float, 3> kGrainStockRms = {1.05F, 1.12F, 1.24F};
constexpr std::array<std::array<float, 3>, 3> kGrainStockRecordDiameter = {
    {{1.00F, 1.00F, 1.00F}, {1.00F, 1.00F, 1.00F}, {1.08F, 1.00F, 0.94F}}};
constexpr std::array<std::array<float, 3>, 3> kGrainStockRecordMtf = {
    {{0.85F, 1.00F, 1.15F}, {0.97F, 1.00F, 1.03F}, {1.08F, 1.00F, 0.94F}}};
constexpr std::array<std::array<float, 3>, 3> kGrainStockRecordRho = {
    {{0.982F, 0.990F, 0.970F}, {0.995F, 0.992F, 0.990F}, {0.965F, 0.975F, 0.990F}}};
constexpr std::array<std::array<float, 3>, 3> kGrainPopulationWeights = {
    {{0.56F, 0.30F, 0.14F}, {0.66F, 0.25F, 0.09F}, {0.42F, 0.32F, 0.26F}}};
constexpr std::array<float, 3> kGrainOctaveWeights = {0.65F, 0.25F, 0.10F};
constexpr float kGrainOctaveRms = 0.703562363974F;
constexpr std::uint32_t kPhiloxM0 = 0xD2511F53U;
constexpr std::uint32_t kPhiloxM1 = 0xCD9E8D57U;
constexpr std::uint32_t kPhiloxW0 = 0x9E3779B9U;
constexpr std::uint32_t kPhiloxW1 = 0xBB67AE85U;
constexpr std::array<float, 5> kMistRadiusFactors = {0.80F, 0.95F, 1.10F, 1.25F, 1.40F};
constexpr std::array<float, 5> kMistEnergyFactors = {0.25F, 0.50F, 0.75F, 1.00F, 1.20F};

struct MistSample {
    Rgb positive;
    float alpha;
};

struct OpticalSample {
    Rgb value;
    float alpha;
};

struct LensSource {
    Rgb value;
    float matte;
};

struct LensDetectedSource {
    double x;
    double y;
    float radius;
    float energy;
    Rgb color;
};

struct OpticalTap {
    int dx;
    int dy;
    float weight;
};

struct OpticalPyramid {
    std::array<std::vector<OpticalSample>, 4> levels;
    std::array<int, 4> widths{};
    std::array<int, 4> heights{};
};

struct GrainFieldArguments {
    std::int64_t frame;
    std::uint32_t seed;
    int layer;
    int octave;
    int channel;
};

struct GrainPopulationProfile {
    float fine;
    float medium;
    float coarse;
    float diameter_scale;
    float asymmetry;
};

ParameterDefinition doubleParameter(const char* id, const char* label, const char* unit, double minimum,
                                    double maximum, double default_value, double increment, bool animatable)
{
    return ParameterDefinition{id, label, label, ParameterType::Double, unit, minimum, maximum, increment,
                               animatable, default_value, {}};
}

ParameterDefinition integerParameter(const char* id, const char* label, const char* unit, std::int64_t minimum,
                                     std::int64_t maximum, std::int64_t default_value, double increment,
                                     bool animatable)
{
    return ParameterDefinition{id, label, label, ParameterType::Integer, unit, static_cast<double>(minimum),
                               static_cast<double>(maximum), increment, animatable, default_value, {}};
}

ParameterDefinition booleanParameter(const char* id, const char* label, bool default_value)
{
    return ParameterDefinition{id, label, label, ParameterType::Boolean, "on/off", 0.0, 1.0, 1.0, false,
                               default_value, {}};
}

ParameterDefinition choiceParameter(const char* id, const char* label, std::vector<const char*> choices,
                                    int default_value)
{
    return ParameterDefinition{id, label, label, ParameterType::Choice, "choice", 0.0,
                               static_cast<double>(choices.size() - 1U), 1.0, false, default_value,
                               std::move(choices)};
}

std::vector<ParameterDefinition> commonParameters(std::vector<const char*> output_views,
                                                   std::vector<const char*> presets)
{
    presets.push_back("Custom");
    return {
        choiceParameter("working_mode", "Working Mode",
                        {"DWG Intermediate", "DWG Linear", "Rec.709 Gamma 2.4"}, 0),
        choiceParameter("output_view", "Output View", std::move(output_views), 0),
        doubleParameter("mix", "Mix", "percent", 0.0, 100.0, 100.0, 1.0, true),
        choiceParameter("preset", "Preset", std::move(presets), 0),
    };
}

void append(std::vector<ParameterDefinition>& parameters, std::initializer_list<ParameterDefinition> additions)
{
    parameters.insert(parameters.end(), additions.begin(), additions.end());
}

PresetDefinition preset(const char* id, const char* label, std::initializer_list<ParameterAssignment> assignments)
{
    return PresetDefinition{id, label, assignments};
}

ParameterAssignment value(const char* id, SettingValue setting)
{
    return ParameterAssignment{id, std::move(setting)};
}

void presentParameters(EffectId effect, std::vector<ParameterDefinition>& parameters)
{
    for (std::size_t index = 0; index < parameters.size(); ++index) {
        ParameterDefinition& parameter = parameters[index];
        parameter.group = ParameterGroup::Advanced;
        parameter.role = ParameterRole::EffectControl;
        parameter.display_order = static_cast<int>(index) * 10;
        parameter.enabled_when_parameter = nullptr;
        parameter.enabled_when_choice = 0;
        parameter.secret = false;

        if (std::strcmp(parameter.id, "preset") == 0) {
            parameter.group = ParameterGroup::Basic;
            parameter.role = ParameterRole::Preset;
            parameter.display_order = 10;
        } else if (std::strcmp(parameter.id, "mix") == 0) {
            parameter.group = ParameterGroup::Basic;
            parameter.role = ParameterRole::Mix;
            parameter.display_order = 90;
        } else if (std::strcmp(parameter.id, "working_mode") == 0) {
            parameter.role = ParameterRole::WorkingMode;
            parameter.display_order = 10;
        } else if (std::strcmp(parameter.id, "output_view") == 0) {
            parameter.group = ParameterGroup::Diagnostics;
            parameter.role = ParameterRole::OutputView;
            parameter.display_order = 10;
        }
    }

    const auto markBasic = [&parameters](const char* id, int order,
                                         ParameterRole role = ParameterRole::EffectControl) {
        for (ParameterDefinition& parameter : parameters) {
            if (std::strcmp(parameter.id, id) == 0) {
                parameter.group = ParameterGroup::Basic;
                parameter.role = role;
                parameter.display_order = order;
                return;
            }
        }
    };
    const auto markAdvanced = [&parameters](const char* id, int order, ParameterRole role = ParameterRole::EffectControl,
                                            const char* enabled_when = nullptr, int enabled_choice = 0) {
        for (ParameterDefinition& parameter : parameters) {
            if (std::strcmp(parameter.id, id) == 0) {
                parameter.group = ParameterGroup::Advanced;
                parameter.role = role;
                parameter.display_order = order;
                parameter.enabled_when_parameter = enabled_when;
                parameter.enabled_when_choice = enabled_choice;
                return;
            }
        }
    };

    switch (effect) {
    case EffectId::Halation:
        markBasic("amount", 20);
        markBasic("radius", 30);
        markBasic("threshold", 40);
        markBasic("source_smoothness", 50);
        markBasic("global_diffusion", 55);
        markBasic("color_emphasis", 60, ParameterRole::Quality);
        markBasic("color_strength", 70);
        markAdvanced("core_protection", 20);
        markAdvanced("background_adaptation", 30);
        markAdvanced("warmth", 40);
        markAdvanced("saturation", 50);
        markAdvanced("highlights_only", 60);
        markAdvanced("red_bias", 70);
        markAdvanced("blue_compensation", 80);
        break;
    case EffectId::FilmGrain:
        markBasic("amount", 20);
        markBasic("size", 30);
        markBasic("softness", 40);
        markAdvanced("format", 20, ParameterRole::Quality);
        markAdvanced("chroma", 30);
        markAdvanced("shadow", 40);
        markAdvanced("midtone", 50);
        markAdvanced("highlight", 60);
        markAdvanced("seed", 70, ParameterRole::Quality);
        markAdvanced("stock_response", 80, ParameterRole::Quality);
        markAdvanced("scan_sampling", 90, ParameterRole::Quality);
        markAdvanced("processing_modifier", 100, ParameterRole::Quality);
        break;
    case EffectId::OpticalBlur:
        markBasic("blur", 20);
        markBasic("anamorphism", 30);
        markBasic("highlight_response", 40);
        markBasic("lens_profile", 50);
        markAdvanced("blades", 20, ParameterRole::Quality);
        markAdvanced("curvature", 30);
        markAdvanced("rotation", 40);
        markAdvanced("bokeh_bias", 50);
        markAdvanced("cat_eye", 60);
        markAdvanced("vignetting", 70);
        markAdvanced("coma", 80);
        markAdvanced("astigmatism", 90);
        markAdvanced("field_curvature", 100);
        markAdvanced("chromatic_aberration", 110);
        markAdvanced("quality", 120, ParameterRole::Quality);
        break;
    case EffectId::LensReflections:
        markBasic("amount", 20);
        markBasic("spread", 30);
        markBasic("chroma", 40);
        markAdvanced("threshold", 20);
        markAdvanced("lens_model", 30, ParameterRole::Quality);
        markAdvanced("blur", 40);
        markAdvanced("anamorphism", 50, ParameterRole::EffectControl, "lens_model", 2);
        markAdvanced("source_mode", 60, ParameterRole::Quality);
        markAdvanced("source_metric", 70, ParameterRole::Quality);
        markAdvanced("source_gamma", 80);
        markAdvanced("source_smoothness", 90);
        markAdvanced("source_morphology", 100);
        markAdvanced("manual_x", 110);
        markAdvanced("manual_y", 120);
        markAdvanced("manual_size", 130);
        markAdvanced("manual_intensity", 140);
        markAdvanced("manual_color", 150);
        markAdvanced("center_x", 160);
        markAdvanced("center_y", 170);
        markAdvanced("background_adaptation", 180);
        markAdvanced("veil", 190);
        markAdvanced("element_solo", 200, ParameterRole::Quality);
        break;
    case EffectId::MistDiffusion:
        markBasic("mode", 20, ParameterRole::Quality);
        markBasic("density", 30, ParameterRole::Quality);
        markBasic("bloom", 40);
        markBasic("diffusion", 50);
        markAdvanced("contrast", 20);
        markAdvanced("texture", 30);
        break;
    }
}

EffectDefinition halationDefinition()
{
    std::vector<ParameterDefinition> parameters = commonParameters(
        {"Final", "Halation Only", "Source Mask", "Local Only", "Global Only"},
        {"Generic Subtle", "Generic Warm", "Strong Halo (Uncalibrated)",
         "Film Red Emphasis (Uncalibrated)", "Neutral White Hybrid (Artistic)"});
    append(parameters, {
                           doubleParameter("amount", "Strength", "percent", 0.0, 200.0, 22.0, 1.0, true),
                           doubleParameter("radius", "Local Radius", "frame-height percent", 0.0, 5.0, 0.65,
                                           0.05, true),
                           doubleParameter("global_diffusion", "Global Diffusion", "percent", 0.0, 100.0,
                                           25.0, 1.0, true),
                           doubleParameter("threshold", "Source Limit", "stops over 18%", -2.0, 8.0, 2.0,
                                           0.1, true),
                           doubleParameter("source_smoothness", "Source Smoothness", "percent", 0.0, 100.0,
                                           55.0, 1.0, true),
                           doubleParameter("core_protection", "Core Protection", "percent", 0.0, 100.0, 85.0,
                                           1.0, true),
                           doubleParameter("background_adaptation", "Background Adaptation", "percent", 0.0,
                                           100.0, 70.0, 1.0, true),
                           booleanParameter("highlights_only", "Highlights Only", true),
                           doubleParameter("warmth", "Warmth", "percent", 0.0, 100.0, 65.0, 1.0, true),
                           doubleParameter("saturation", "Saturation", "percent", 0.0, 100.0, 30.0, 1.0, true),
                           doubleParameter("red_bias", "Red Bias", "profile-relative percent", 0.0, 100.0,
                                           78.0, 1.0, true),
                           doubleParameter("blue_compensation", "Blue Compensation", "profile-relative percent",
                                           0.0, 100.0, 18.0, 1.0, true),
                           choiceParameter("color_emphasis", "Color Emphasis",
                                           {"Profile Relative", "Film Red", "Warm Amber",
                                            "Neutral White (Artistic)", "Auto (Scene Adaptive)"},
                                           0),
                           doubleParameter("color_strength", "Color Strength", "percent", 0.0, 100.0, 100.0,
                                           1.0, true),
                       });
    EffectDefinition definition{EffectId::Halation,
                            "com.cbef.filmeffects.halation",
                            "CBEF Halation",
                            "Generic scene-reactive local halo and broad glare; no measured stock calibration is claimed.",
                            std::move(parameters),
                            {preset("generic_subtle", "Generic Subtle",
                                    {value("amount", 22.0), value("radius", 0.65), value("global_diffusion", 18.0),
                                     value("threshold", 2.0),
                                     value("source_smoothness", 55.0), value("core_protection", 85.0),
                                     value("background_adaptation", 70.0), value("highlights_only", true),
                                     value("warmth", 65.0), value("saturation", 30.0), value("red_bias", 70.0),
                                     value("blue_compensation", 20.0)}),
                            preset("generic_warm", "Generic Warm",
                                    {value("amount", 38.0), value("radius", 0.90), value("global_diffusion", 25.0),
                                     value("threshold", 1.5),
                                     value("source_smoothness", 65.0), value("core_protection", 82.0),
                                     value("background_adaptation", 72.0), value("highlights_only", true),
                                     value("warmth", 80.0), value("saturation", 45.0), value("red_bias", 78.0),
                                     value("blue_compensation", 18.0)}),
                            preset("strong_halo_uncalibrated", "Strong Halo (Uncalibrated)",
                                    {value("amount", 70.0), value("radius", 1.25), value("global_diffusion", 38.0),
                                     value("threshold", 1.0),
                                     value("source_smoothness", 75.0), value("core_protection", 76.0),
                                     value("background_adaptation", 65.0), value("highlights_only", true),
                                     value("warmth", 70.0), value("saturation", 55.0), value("red_bias", 84.0),
                                     value("blue_compensation", 28.0)}),
                            preset("film_red_emphasis_uncalibrated", "Film Red Emphasis (Uncalibrated)",
                                   {value("amount", 90.0), value("radius", 1.35), value("global_diffusion", 40.0),
                                    value("threshold", 0.8), value("source_smoothness", 75.0),
                                    value("core_protection", 78.0), value("background_adaptation", 62.0),
                                    value("highlights_only", true), value("warmth", 72.0),
                                    value("saturation", 65.0), value("red_bias", 88.0),
                                    value("blue_compensation", 18.0), value("color_emphasis", 1),
                                    value("color_strength", 92.0)}),
                            preset("neutral_white_hybrid_artistic", "Neutral White Hybrid (Artistic)",
                                   {value("amount", 68.0), value("radius", 1.10), value("global_diffusion", 45.0),
                                    value("threshold", 1.0), value("source_smoothness", 70.0),
                                    value("core_protection", 80.0), value("background_adaptation", 58.0),
                                    value("highlights_only", true), value("warmth", 55.0),
                                    value("saturation", 35.0), value("red_bias", 78.0),
                                    value("blue_compensation", 18.0), value("color_emphasis", 3),
                                    value("color_strength", 100.0)})},
                            0U};
    presentParameters(definition.effect, definition.parameters);
    const auto setHint = [&definition](const char* id, const char* hint) {
        for (ParameterDefinition& parameter : definition.parameters) {
            if (std::strcmp(parameter.id, id) == 0) {
                parameter.hint = hint;
                return;
            }
        }
    };
    setHint("threshold", "Sets the scene-linear source limit; the transition is softened by Source Smoothness.");
    setHint("source_smoothness", "Widens the source-limit knee so practical lights do not pop at the threshold.");
    setHint("core_protection", "Suppresses the selected highlight core so the local halo stays outside the source.");
    setHint("background_adaptation", "Reduces visible local halo energy over bright surrounding image content.");
    setHint("global_diffusion", "Adds a broad, weak glare branch independently from the local halo radius.");
    setHint("warmth", "Profile-relative artistic warmth; it is not a measured film-stock channel ratio.");
    setHint("red_bias", "Profile-relative red-sensitive response; it is not a measured film-stock channel ratio.");
    setHint("blue_compensation", "Profile-relative blue/cyan source compensation; it is not a measured film-stock channel ratio.");
    setHint("color_emphasis",
            "Retargets the profile-relative halo chroma while preserving luminance. Auto is scene-adaptive: neutral highlights favor Film Red, warm highlights favor Warm Amber, and strong cool or green highlights move toward Neutral White. Neutral White is an artistic optical bloom/glare hybrid, not measured film halation.");
    setHint("color_strength",
            "Blends from the profile-relative result to the selected fixed or scene-adaptive chroma target; Profile Relative ignores this control.");
    return definition;
}

EffectDefinition grainDefinition()
{
    std::vector<ParameterDefinition> parameters = commonParameters(
        {"Final", "Grain Component", "Grain Luminance Response"},
        {"16mm", "35mm Fine", "35mm Fast", "65mm Fine", "8mm Coarse", "16mm Fast"});
    append(parameters, {
                           choiceParameter("format", "Capture Format",
                                           {"16mm", "35mm", "35mm Compact Gate (Generic)", "65mm", "Super 8"},
                                           1),
                           doubleParameter("amount", "Amount", "percent", 0.0, 200.0, 28.0, 1.0, true),
                           doubleParameter("size", "Display Scale", "percent", 25.0, 400.0, 100.0, 5.0, true),
                           doubleParameter("softness", "Softness", "percent", 0.0, 100.0, 28.0, 1.0, true),
                           doubleParameter("chroma", "Chroma", "percent", 0.0, 100.0, 12.0, 1.0, true),
                           doubleParameter("shadow", "Shadow", "percent", 0.0, 200.0, 40.0, 1.0, true),
                           doubleParameter("midtone", "Midtone", "percent", 0.0, 200.0, 100.0, 1.0, true),
                           doubleParameter("highlight", "Highlight", "percent", 0.0, 200.0, 25.0, 1.0, true),
                           integerParameter("seed", "Seed", "integer", 0, 2147483647, 1337, 1.0, true),
                           choiceParameter("stock_response", "Stock Response",
                                           {"Generic Fine", "Generic Balanced", "Generic Fast"}, 0),
                           choiceParameter("scan_sampling", "Scan Sampling",
                                           {"2K Equivalent", "4K Equivalent", "8K Equivalent"}, 1),
                           choiceParameter("processing_modifier", "Processing Modifier",
                                           {"Generic Normal", "Generic Gentle", "Generic Enhanced (Uncalibrated)"}, 0),
                           doubleParameter("film_resolution", "Film Resolution", "percent", 0.0, 100.0, 72.0, 1.0,
                                           true),
                           doubleParameter("clump", "Clumping", "percent", 0.0, 100.0, 22.0, 1.0, true),
                           doubleParameter("exposure_bias", "Exposure Bias", "stops", -4.0, 4.0, 0.0, 0.01,
                                           true),
                       });
    EffectDefinition definition{EffectId::FilmGrain,
                            "com.cbef.filmeffects.filmgrain",
                            "CBEF Film Grain",
                            "Generic procedural film grain with independent stock, capture, scan, processing, and display controls.",
                            std::move(parameters),
                            {preset("16mm", "16mm",
                                    {value("format", 0), value("amount", 55.0), value("size", 115.0),
                                     value("softness", 20.0), value("chroma", 25.0), value("shadow", 55.0),
                                     value("midtone", 110.0), value("highlight", 35.0),
                                     value("seed", std::int64_t{1337}), value("stock_response", 2),
                                     value("scan_sampling", 1), value("processing_modifier", 0),
                                     value("film_resolution", 62.0), value("clump", 38.0), value("exposure_bias", 0.0)}),
                            preset("35mm_fine", "35mm Fine",
                                    {value("format", 1), value("amount", 28.0), value("size", 100.0),
                                     value("softness", 28.0), value("chroma", 12.0), value("shadow", 40.0),
                                     value("midtone", 100.0), value("highlight", 25.0),
                                     value("seed", std::int64_t{1337}), value("stock_response", 0),
                                     value("scan_sampling", 1), value("processing_modifier", 0),
                                     value("film_resolution", 72.0), value("clump", 22.0), value("exposure_bias", 0.0)}),
                            preset("35mm_fast", "35mm Fast",
                                    {value("format", 2), value("amount", 42.0), value("size", 110.0),
                                     value("softness", 20.0), value("chroma", 18.0), value("shadow", 50.0),
                                     value("midtone", 110.0), value("highlight", 30.0),
                                     value("seed", std::int64_t{1337}), value("stock_response", 2),
                                     value("scan_sampling", 1), value("processing_modifier", 0),
                                     value("film_resolution", 64.0), value("clump", 32.0), value("exposure_bias", 0.0)}),
                            preset("65mm_fine", "65mm Fine",
                                    {value("format", 3), value("amount", 18.0), value("size", 90.0),
                                     value("softness", 35.0), value("chroma", 8.0), value("shadow", 30.0),
                                     value("midtone", 90.0), value("highlight", 20.0),
                                     value("seed", std::int64_t{1337}), value("stock_response", 0),
                                     value("scan_sampling", 1), value("processing_modifier", 0),
                                     value("film_resolution", 80.0), value("clump", 18.0), value("exposure_bias", 0.0)}),
                             preset("8mm_coarse", "8mm Coarse",
                                    {value("format", 4), value("amount", 72.0), value("size", 120.0),
                                     value("softness", 18.0), value("chroma", 25.0), value("shadow", 60.0),
                                     value("midtone", 115.0), value("highlight", 28.0),
                                     value("seed", std::int64_t{1337}), value("stock_response", 2),
                                     value("scan_sampling", 1), value("processing_modifier", 0),
                                     value("film_resolution", 54.0), value("clump", 48.0), value("exposure_bias", 0.0)}),
                             preset("16mm_fast", "16mm Fast",
                                    {value("format", 0), value("amount", 60.0), value("size", 110.0),
                                     value("softness", 22.0), value("chroma", 20.0), value("shadow", 55.0),
                                     value("midtone", 112.0), value("highlight", 32.0),
                                     value("seed", std::int64_t{1337}), value("stock_response", 2),
                                     value("scan_sampling", 1), value("processing_modifier", 0),
                                     value("film_resolution", 60.0), value("clump", 40.0), value("exposure_bias", 0.0)})},
                            1U};
    presentParameters(definition.effect, definition.parameters);
    for (ParameterDefinition& parameter : definition.parameters) {
        if (std::strcmp(parameter.id, "format") == 0) {
            parameter.hint = "Capture gate controls canonical film-area sampling; it does not change stock response.";
        } else if (std::strcmp(parameter.id, "size") == 0) {
            parameter.hint = "Display magnification controls apparent grain diameter independently of stock response.";
        } else if (std::strcmp(parameter.id, "stock_response") == 0) {
            parameter.hint = "Generic placeholder exposure and record response; no measured stock calibration is claimed.";
        } else if (std::strcmp(parameter.id, "scan_sampling") == 0) {
            parameter.hint = "Scan sampling selects a display-equivalent sampling density; it does not replace stock response.";
        } else if (std::strcmp(parameter.id, "processing_modifier") == 0) {
            parameter.hint = "Generic processing modifier; push/pull behavior is an uncalibrated artistic control.";
        } else if (std::strcmp(parameter.id, "film_resolution") == 0) {
            parameter.hint = "Film Resolution changes the record MTF branch independently from Grain Softness.";
        } else if (std::strcmp(parameter.id, "clump") == 0) {
            parameter.hint = "Clumping mixes fine, medium, and coarse populations with bounded density variation.";
        } else if (std::strcmp(parameter.id, "exposure_bias") == 0) {
            parameter.hint = "Shifts the generic exposure response curve without claiming a measured stock calibration.";
        }
    }
    return definition;
}

EffectDefinition opticalBlurDefinition()
{
    std::vector<ParameterDefinition> parameters = commonParameters(
        {"Final", "Optical Blurred Image", "Optical Highlight Component", "PSF Preview", "Highlight Source Map"},
        {"Clean Soft", "Round Bokeh", "Anamorphic"});
    append(parameters, {
                           doubleParameter("blur", "Blur", "frame-height percent", 0.0, 4.0, 0.15, 0.01, true),
                           integerParameter("blades", "Blades", "blade count", 3, 16, 9, 1.0, true),
                           doubleParameter("curvature", "Roundness", "percent", 0.0, 100.0, 90.0, 1.0, true),
                           doubleParameter("rotation", "Rotation", "degrees", -180.0, 180.0, 0.0, 1.0, true),
                           doubleParameter("anamorphism", "Anamorphism", "horizontal/vertical ratio", 0.5, 3.0,
                                           1.0, 0.01, true),
                           doubleParameter("highlight_response", "Highlight Gain", "percent", 0.0, 200.0,
                                           15.0, 1.0, true),
                           choiceParameter("lens_profile", "Lens Profile",
                                           {"Generic Clean", "Generic Portrait", "Generic Vintage", "Generic Anamorphic"}, 0),
                           doubleParameter("bokeh_bias", "Center / Rim", "percent", -100.0, 100.0, 0.0, 1.0,
                                           true),
                           doubleParameter("cat_eye", "Cat-eye", "percent", 0.0, 100.0, 0.0, 1.0, true),
                           doubleParameter("vignetting", "Optical Vignetting", "percent", 0.0, 100.0, 0.0,
                                           1.0, true),
                           doubleParameter("coma", "Coma", "percent", 0.0, 100.0, 0.0, 1.0, true),
                           doubleParameter("astigmatism", "Astigmatism", "percent", 0.0, 100.0, 0.0, 1.0,
                                           true),
                           doubleParameter("field_curvature", "Field Focus Bias", "percent", -100.0, 100.0,
                                           0.0, 1.0, true),
                           doubleParameter("chromatic_aberration", "Chromatic Aberration", "percent", 0.0,
                                           100.0, 0.0, 1.0, true),
                           choiceParameter("quality", "Quality", {"Preview", "Balanced", "Final"}, 1),
                       });
    EffectDefinition definition{EffectId::OpticalBlur,
                            "com.cbef.filmeffects.opticalblur",
                            "CBEF Optical Blur",
                            "Aperture-shaped optical blur.",
                            std::move(parameters),
                            {preset("clean_soft", "Clean Soft",
                                    {value("blur", 0.15), value("blades", std::int64_t{9}),
                                     value("curvature", 90.0), value("rotation", 0.0),
                                     value("anamorphism", 1.0), value("highlight_response", 15.0),
                                     value("lens_profile", 0), value("bokeh_bias", 0.0), value("cat_eye", 25.0),
                                     value("vignetting", 0.0), value("coma", 0.0), value("astigmatism", 0.0),
                                     value("field_curvature", 0.0), value("chromatic_aberration", 0.0),
                                     value("quality", 1)}),
                             preset("round_bokeh", "Round Bokeh",
                                    {value("blur", 0.30), value("blades", std::int64_t{12}),
                                     value("curvature", 100.0), value("rotation", 0.0),
                                     value("anamorphism", 1.0), value("highlight_response", 25.0),
                                     value("lens_profile", 1), value("bokeh_bias", -15.0), value("cat_eye", 35.0),
                                     value("vignetting", 12.0), value("coma", 8.0), value("astigmatism", 7.0),
                                     value("field_curvature", 8.0), value("chromatic_aberration", 5.0),
                                     value("quality", 1)}),
                             preset("anamorphic", "Anamorphic",
                                    {value("blur", 0.25), value("blades", std::int64_t{8}),
                                     value("curvature", 70.0), value("rotation", 0.0),
                                     value("anamorphism", 2.0), value("highlight_response", 35.0),
                                     value("lens_profile", 3), value("bokeh_bias", 10.0), value("cat_eye", 45.0),
                                     value("vignetting", 16.0), value("coma", 12.0), value("astigmatism", 10.0),
                                     value("field_curvature", 12.0), value("chromatic_aberration", 8.0),
                                     value("quality", 1)})},
                            0U};
    presentParameters(definition.effect, definition.parameters);
    const auto setHint = [&definition](const char* id, const char* hint) {
        for (ParameterDefinition& parameter : definition.parameters) {
            if (std::strcmp(parameter.id, id) == 0) {
                parameter.hint = hint;
                return;
            }
        }
    };
    setHint("lens_profile", "Generic PSF coefficient family; no measured lens or manufacturer calibration is claimed.");
    setHint("bokeh_bias", "Shifts center versus rim energy as a generic artistic control.");
    setHint("cat_eye", "Controls effective-pupil clipping toward the screen rim; this is not depth of field.");
    setHint("vignetting", "Generic field brightness falloff independent from highlight gain; no measured lens claim.");
    setHint("coma", "Generic radial asymmetry that increases toward the screen field; not a calibrated lens profile.");
    setHint("astigmatism", "Generic radial/tangential separation; kept bounded for continuous artistic shaping.");
    setHint("field_curvature", "Offsets field focus smoothly to shape edge character; not focus distance or depth of field.");
    setHint("chromatic_aberration", "Generic per-channel lateral dispersion; zero keeps RGB PSF centroids aligned.");
    setHint("quality", "Deterministic sample budget: Preview 24, Balanced 64, Final 128-equivalent coverage.");
    return definition;
}

EffectDefinition reflectionsDefinition()
{
    std::vector<ParameterDefinition> parameters = commonParameters(
        {"Final", "Lens Reflection Component", "Lens Source Matte", "Source Map", "Ghost Paths", "Elements Only",
         "Element Solo", "Matte Limited"},
        {"Clean Prime", "Vintage Prime", "Anamorphic"});
    append(parameters, {
                           doubleParameter("amount", "Amount", "percent", 0.0, 200.0, 18.0, 1.0, true),
                           doubleParameter("threshold", "Threshold", "stops over 18%", -2.0, 8.0, 2.5, 0.1,
                                           true),
                           choiceParameter("lens_model", "Lens Model", {"Clean Prime", "Vintage Prime", "Anamorphic"},
                                           0),
                           doubleParameter("spread", "Spread", "percent", 0.0, 200.0, 65.0, 1.0, true),
                           doubleParameter("blur", "Blur", "frame-height percent", 0.0, 3.0, 0.30, 0.05, true),
                           doubleParameter("chroma", "Chroma", "percent", 0.0, 100.0, 8.0, 1.0, true),
                           doubleParameter("anamorphism", "Anamorphism", "horizontal/vertical ratio", 0.5, 3.0,
                                           1.0, 0.01, true),
                           choiceParameter("source_mode", "Source Mode", {"Auto", "Manual"}, 0),
                           choiceParameter("source_metric", "Source Metric", {"Luminance", "Max RGB", "Per-channel"},
                                           0),
                           doubleParameter("source_gamma", "Source Gamma", "power", 0.25, 4.0, 1.0, 0.01, true),
                           doubleParameter("source_smoothness", "Source Smoothness", "percent", 0.0, 100.0, 0.0,
                                           1.0, true),
                           doubleParameter("source_morphology", "Source Morphology", "percent", -100.0, 100.0,
                                           0.0, 1.0, true),
                           doubleParameter("manual_x", "Manual Source X", "frame percent", -400.0, 400.0, 0.0, 0.1,
                                           true),
                           doubleParameter("manual_y", "Manual Source Y", "frame percent", -400.0, 400.0, 0.0, 0.1,
                                           true),
                           doubleParameter("manual_size", "Manual Source Size", "frame-height percent", 0.1, 100.0,
                                           4.0, 0.1, true),
                           doubleParameter("manual_intensity", "Manual Source Intensity", "percent", 0.0, 200.0,
                                           100.0, 1.0, true),
                           choiceParameter("manual_color", "Manual Source Color", {"Preserve", "Neutral", "Warm"}, 0),
                           doubleParameter("center_x", "Optical Center X", "frame percent", -100.0, 100.0, 0.0, 0.1,
                                           true),
                           doubleParameter("center_y", "Optical Center Y", "frame percent", -100.0, 100.0, 0.0, 0.1,
                                           true),
                           doubleParameter("background_adaptation", "Background Adaptation", "percent", 0.0, 100.0,
                                           0.0, 1.0, true),
                           doubleParameter("veil", "Veiling Glare", "percent", 0.0, 100.0, 0.0, 1.0, true),
                           choiceParameter("element_solo", "Element Solo", {"All", "Element 1", "Element 2",
                                                                              "Element 3", "Element 4", "Element 5"},
                                           0),
                       });
    EffectDefinition definition{EffectId::LensReflections,
                            "com.cbef.filmeffects.lensreflections",
                            "CBEF Lens Reflections",
                            "Lens-axis reflections.",
                            std::move(parameters),
                            {preset("clean_prime", "Clean Prime",
                                    {value("amount", 18.0), value("threshold", 2.5), value("lens_model", 0),
                                     value("spread", 65.0), value("blur", 0.30), value("chroma", 8.0),
                                     value("anamorphism", 1.0)}),
                             preset("vintage_prime", "Vintage Prime",
                                    {value("amount", 35.0), value("threshold", 1.5), value("lens_model", 1),
                                     value("spread", 90.0), value("blur", 0.55), value("chroma", 22.0),
                                     value("anamorphism", 1.0)}),
                             preset("anamorphic", "Anamorphic",
                                    {value("amount", 30.0), value("threshold", 2.0), value("lens_model", 2),
                                     value("spread", 110.0), value("blur", 0.40), value("chroma", 28.0),
                                     value("anamorphism", 2.0)})},
                            0U};
    presentParameters(definition.effect, definition.parameters);
    const auto setHint = [&definition](const char* id, const char* hint) {
        for (ParameterDefinition& parameter : definition.parameters) {
            if (std::strcmp(parameter.id, id) == 0) {
                parameter.hint = hint;
                return;
            }
        }
    };
    setHint("source_mode", "Auto uses a deterministic frame-local source map; Manual replaces it with one analytic ellipse.");
    setHint("source_metric", "Selects the scene-linear source metric used by the spatial detector.");
    setHint("source_gamma", "Compresses source energy after the soft threshold knee; it is not a camera gamma.");
    setHint("source_smoothness", "Widens the threshold knee to keep moving practical lights continuous.");
    setHint("source_morphology", "Erodes or dilates the source matte with bounded edge-aware morphology.");
    setHint("manual_x", "Manual source X is normalized to the data window and may be off-screen.");
    setHint("manual_y", "Manual source Y is normalized to the data window and may be off-screen.");
    setHint("manual_size", "Manual source diameter is normalized to frame height and is analytic, not a sampled bitmap.");
    setHint("manual_intensity", "Manual source energy replaces auto source energy when Manual mode is selected.");
    setHint("manual_color", "Manual color can preserve source RGB or use neutral/warm generic tint.");
    setHint("center_x", "Shifts the normalized optical-axis pivot without changing data-window origin.");
    setHint("center_y", "Shifts the normalized optical-axis pivot without changing data-window origin.");
    setHint("background_adaptation", "Suppresses ghost visibility over bright scene-linear background content.");
    setHint("veil", "Adds a broad source-weighted veiling branch independently from focused ghost elements.");
    setHint("lens_model", "Generic Clean, Vintage, and Anamorphic element families; no real lens, focal-length, or T-stop calibration is claimed.");
    setHint("element_solo", "Isolates one compiled signed-axis element for geometry and energy diagnosis.");
    return definition;
}

EffectDefinition mistDefinition()
{
    std::vector<ParameterDefinition> parameters = commonParameters(
        {"Final", "Mist Diffusion Component", "Mist Highlight Matte", "Glow Only", "Veil Only", "Source Mask",
         "Detail Difference"},
        {"Generic Black 1/8", "Generic Black 1/4", "Generic Black 1/2", "Generic Black 1", "Generic Black 2",
         "Generic White 1/8", "Generic White 1/4", "Generic White 1/2", "Generic White 1", "Generic White 2"});
    append(parameters, {
                           choiceParameter("mode", "Filter Family", {"Generic Black", "Generic White"}, 0),
                           choiceParameter("density", "Grade", {"1/8", "1/4", "1/2", "1", "2"}, 0),
                           doubleParameter("diffusion", "Veil", "profile-relative percent", 0.0, 100.0, 18.0, 1.0,
                                           true),
                           doubleParameter("bloom", "Glow", "profile-relative percent", 0.0, 100.0, 12.0, 1.0,
                                           true),
                           doubleParameter("contrast", "Veil Contrast", "profile-relative percent", 0.0, 100.0,
                                           8.0, 1.0, true),
                           doubleParameter("texture", "Detail Retention", "percent", 0.0, 100.0, 90.0, 1.0, true),
                       });
    const auto black = [](const char* id, const char* label, int grade, double veil, double glow,
                          double contrast, double texture) {
        return preset(id, label, {value("mode", 0), value("density", grade), value("diffusion", veil),
                                  value("bloom", glow), value("contrast", contrast), value("texture", texture)});
    };
    const auto white = [](const char* id, const char* label, int grade, double veil, double glow,
                          double contrast, double texture) {
        return preset(id, label, {value("mode", 1), value("density", grade), value("diffusion", veil),
                                  value("bloom", glow), value("contrast", contrast), value("texture", texture)});
    };
    EffectDefinition definition{EffectId::MistDiffusion,
                            "com.cbef.filmeffects.mistdiffusion",
                            "CBEF Mist Diffusion",
                            "Trademark-free Generic Black and Generic White glow and veil profiles; no measured filter calibration is claimed.",
                            std::move(parameters),
                            {black("black_1_8", "Generic Black 1/8", 0, 18.0, 12.0, 8.0, 90.0),
                             black("black_1_4", "Generic Black 1/4", 1, 28.0, 18.0, 12.0, 85.0),
                             black("black_1_2", "Generic Black 1/2", 2, 42.0, 28.0, 18.0, 78.0),
                             black("black_1", "Generic Black 1", 3, 60.0, 42.0, 26.0, 68.0),
                             black("black_2", "Generic Black 2", 4, 78.0, 58.0, 34.0, 56.0),
                             white("white_1_8", "Generic White 1/8", 0, 22.0, 20.0, 18.0, 82.0),
                             white("white_1_4", "Generic White 1/4", 1, 35.0, 32.0, 28.0, 75.0),
                             white("white_1_2", "Generic White 1/2", 2, 50.0, 48.0, 40.0, 65.0),
                             white("white_1", "Generic White 1", 3, 70.0, 65.0, 55.0, 55.0),
                             white("white_2", "Generic White 2", 4, 88.0, 82.0, 68.0, 44.0)},
                            0U};
    presentParameters(definition.effect, definition.parameters);
    const auto setHint = [&definition](const char* id, const char* hint) {
        for (ParameterDefinition& parameter : definition.parameters) {
            if (std::strcmp(parameter.id, id) == 0) {
                parameter.hint = hint;
                return;
            }
        }
    };
    setHint("mode", "Chooses a generic family direction; it does not claim a measured manufacturer filter profile.");
    setHint("density", "Selects a profile strength step, not a physical density or a linear optical multiplier.");
    setHint("diffusion", "Sets the broad low-frequency veil independently from localized highlight glow.");
    setHint("bloom", "Sets localized highlight glow independently from broad veil.");
    setHint("contrast", "Controls profile-relative veil contrast without claiming a measured transfer curve.");
    setHint("texture", "Controls an exposure-domain detail split; 100 retains detail and 0 applies the strongest softness.");
    return definition;
}

const std::vector<EffectDefinition>& definitions()
{
    static const std::vector<EffectDefinition> values = {
        halationDefinition(), grainDefinition(), opticalBlurDefinition(), reflectionsDefinition(), mistDefinition()};
    return values;
}

const EffectDefinition* findDefinition(EffectId effect)
{
    const auto& values = definitions();
    const auto iterator = std::find_if(values.begin(), values.end(), [effect](const EffectDefinition& definition) {
        return definition.effect == effect;
    });
    return iterator == values.end() ? nullptr : &*iterator;
}

std::size_t parameterIndex(const EffectDefinition& definition, std::string_view id)
{
    for (std::size_t index = 0; index < definition.parameters.size(); ++index) {
        if (id == definition.parameters[index].id) {
            return index;
        }
    }
    return definition.parameters.size();
}

bool valuesEqual(const SettingValue& left, const SettingValue& right)
{
    return left.index() == right.index() && left == right;
}

bool isPresetControlled(const char* id)
{
    return std::strcmp(id, "working_mode") != 0 && std::strcmp(id, "output_view") != 0 &&
           std::strcmp(id, "mix") != 0 && std::strcmp(id, "preset") != 0;
}

double doubleSetting(const Settings& settings, const char* id)
{
    return std::get<double>(settingValue(settings, id));
}

int choiceSetting(const Settings& settings, const char* id)
{
    return std::get<int>(settingValue(settings, id));
}

bool isFinite(double value)
{
    return std::isfinite(value);
}

Error validateSettings(const RenderRequest& request, const EffectDefinition& definition)
{
    if (request.settings.effect != request.effect || request.settings.values.size() != definition.parameters.size()) {
        return Error::SettingsTypeMismatch;
    }
    for (std::size_t index = 0; index < definition.parameters.size(); ++index) {
        const ParameterDefinition& parameter = definition.parameters[index];
        const SettingValue& value = request.settings.values[index];
        if (value.index() != static_cast<std::size_t>(parameter.type)) {
            return Error::SettingsTypeMismatch;
        }
        if (parameter.type == ParameterType::Double) {
            const double number = std::get<double>(value);
            if (!isFinite(number)) {
                return Error::NonFiniteSetting;
            }
            if (number < parameter.minimum || number > parameter.maximum) {
                return Error::SettingOutOfRange;
            }
        } else if (parameter.type == ParameterType::Integer) {
            const double number = static_cast<double>(std::get<std::int64_t>(value));
            if (number < parameter.minimum || number > parameter.maximum) {
                return Error::SettingOutOfRange;
            }
        } else if (parameter.type == ParameterType::Choice) {
            const int choice = std::get<int>(value);
            if (std::strcmp(parameter.id, "working_mode") == 0 &&
                (choice < static_cast<int>(WorkingMode::DwgIntermediate) ||
                 choice > static_cast<int>(WorkingMode::Rec709Gamma24))) {
                return Error::UnsupportedWorkingMode;
            }
            if (choice < 0 || choice >= static_cast<int>(parameter.choices.size())) {
                return Error::SettingOutOfRange;
            }
        }
    }
    return Error::None;
}

bool validWindow(const DataWindow& bounds, const RectI& window)
{
    if (window.x1 >= window.x2 || window.y1 >= window.y2) {
        return false;
    }
    const std::int64_t right = static_cast<std::int64_t>(bounds.x) + bounds.width;
    const std::int64_t bottom = static_cast<std::int64_t>(bounds.y) + bounds.height;
    return window.x1 >= bounds.x && window.y1 >= bounds.y && window.x2 <= right && window.y2 <= bottom;
}

bool rangeOverlaps(const FrameSurface& source, const FrameSurface& destination)
{
    if (source.memory_kind == MemoryKind::Metal || destination.memory_kind == MemoryKind::Metal) {
        if (source.data != destination.data) {
            return false;
        }
        const std::size_t source_extent = static_cast<std::size_t>(source.data_window.height - 1) * source.row_bytes +
                                          static_cast<std::size_t>(source.data_window.width) * 16U;
        const std::size_t destination_extent =
            static_cast<std::size_t>(destination.data_window.height - 1) * destination.row_bytes +
            static_cast<std::size_t>(destination.data_window.width) * 16U;
        const std::size_t source_start = source.byte_offset;
        const std::size_t destination_start = destination.byte_offset;
        const std::size_t source_end = source_start + source_extent;
        const std::size_t destination_end = destination_start + destination_extent;
        return source_start < destination_end && destination_start < source_end;
    }
    const std::size_t source_extent = static_cast<std::size_t>(source.data_window.height - 1) * source.row_bytes +
                                      static_cast<std::size_t>(source.data_window.width) * 16U;
    const std::size_t destination_extent =
        static_cast<std::size_t>(destination.data_window.height - 1) * destination.row_bytes +
        static_cast<std::size_t>(destination.data_window.width) * 16U;
    const std::uintptr_t source_start = reinterpret_cast<std::uintptr_t>(source.data) + source.byte_offset;
    const std::uintptr_t destination_start = reinterpret_cast<std::uintptr_t>(destination.data) + destination.byte_offset;
    const std::uintptr_t source_end = source_start + source_extent;
    const std::uintptr_t destination_end = destination_start + destination_extent;
    return source_start < destination_end && destination_start < source_end;
}

std::size_t surfacePixelBytes(const FrameSurface& surface)
{
    switch (surface.pixel_format) {
    case PixelFormat::AlphaFloat32:
        return sizeof(float);
    case PixelFormat::RgbaFloat32:
        return sizeof(float) * 4U;
    case PixelFormat::Unsupported:
        return 0U;
    }
    return 0U;
}

bool surfacesOverlap(const FrameSurface& left, const FrameSurface& right)
{
    const std::size_t left_pixel_bytes = surfacePixelBytes(left);
    const std::size_t right_pixel_bytes = surfacePixelBytes(right);
    if (left_pixel_bytes == 0U || right_pixel_bytes == 0U || left.data == nullptr || right.data == nullptr) {
        return false;
    }
    const std::size_t left_extent = static_cast<std::size_t>(left.data_window.height - 1) * left.row_bytes +
                                    static_cast<std::size_t>(left.data_window.width) * left_pixel_bytes;
    const std::size_t right_extent = static_cast<std::size_t>(right.data_window.height - 1) * right.row_bytes +
                                     static_cast<std::size_t>(right.data_window.width) * right_pixel_bytes;
    if (left.memory_kind == MemoryKind::Metal || right.memory_kind == MemoryKind::Metal) {
        if (left.data != right.data) {
            return false;
        }
        const std::size_t left_start = left.byte_offset;
        const std::size_t right_start = right.byte_offset;
        return left_start < right_start + right_extent && right_start < left_start + left_extent;
    }
    const std::uintptr_t left_start = reinterpret_cast<std::uintptr_t>(left.data) + left.byte_offset;
    const std::uintptr_t right_start = reinterpret_cast<std::uintptr_t>(right.data) + right.byte_offset;
    return left_start < right_start + right_extent && right_start < left_start + left_extent;
}

Error validateExternalMatte(const RenderRequest& request, BackendKind backend_kind)
{
    if (request.external_matte == nullptr) {
        return Error::None;
    }
    if (request.effect != EffectId::LensReflections) {
        return Error::UnsupportedPixelFormat;
    }
    const FrameSurface& matte = request.external_matte->surface;
    const MemoryKind expected_memory = backend_kind == BackendKind::Cpu ? MemoryKind::Cpu : MemoryKind::Metal;
    if (matte.memory_kind != expected_memory) {
        return Error::BackendUnavailable;
    }
    const std::size_t pixel_bytes = surfacePixelBytes(matte);
    if (pixel_bytes == 0U || (matte.pixel_format != PixelFormat::AlphaFloat32 &&
                             matte.pixel_format != PixelFormat::RgbaFloat32)) {
        return Error::UnsupportedPixelFormat;
    }
    if (matte.data == nullptr || matte.data_window.width <= 0 || matte.data_window.height <= 0) {
        return Error::InvalidDimensions;
    }
    const std::size_t minimum_stride = static_cast<std::size_t>(matte.data_window.width) * pixel_bytes;
    if (matte.row_bytes < minimum_stride || matte.row_bytes % 4U != 0U) {
        return Error::InvalidStride;
    }
    if (surfacesOverlap(request.source, matte) || surfacesOverlap(request.destination, matte)) {
        return Error::AliasedSurfaces;
    }
    return Error::None;
}

float decodeDwg(float value)
{
    if (value > 0.02740668F) {
        return std::exp2(value / 0.07329248F - 7.0F) - 0.0075F;
    }
    return value / 10.44426855F;
}

float encodeDwg(float value)
{
    if (value > 0.00262409F) {
        return (std::log2(value + 0.0075F) + 7.0F) * 0.07329248F;
    }
    return value * 10.44426855F;
}

float signedPower(float value, float exponent)
{
    return std::copysign(std::pow(std::abs(value), exponent), value);
}

Rgb toDwg(Rgb value, WorkingMode mode)
{
    if (mode == WorkingMode::DwgIntermediate) {
        return {decodeDwg(static_cast<float>(value.r)), decodeDwg(static_cast<float>(value.g)),
                decodeDwg(static_cast<float>(value.b))};
    }
    if (mode == WorkingMode::DwgLinear) {
        return value;
    }
    const double red = signedPower(static_cast<float>(value.r), 2.4F);
    const double green = signedPower(static_cast<float>(value.g), 2.4F);
    const double blue = signedPower(static_cast<float>(value.b), 2.4F);
    const double x = 0.41239080 * red + 0.35758434 * green + 0.18048079 * blue;
    const double y = 0.21263901 * red + 0.71516868 * green + 0.07219232 * blue;
    const double z = 0.01933082 * red + 0.11919478 * green + 0.95053215 * blue;
    return {1.51667204 * x - 0.28147805 * y - 0.14696363 * z,
            -0.46491710 * x + 1.25142378 * y + 0.17488461 * z,
            0.06484905 * x + 0.10913934 * y + 0.76141462 * z};
}

Rgb fromDwg(Rgb value, WorkingMode mode)
{
    if (mode == WorkingMode::DwgIntermediate) {
        return {encodeDwg(static_cast<float>(value.r)), encodeDwg(static_cast<float>(value.g)),
                encodeDwg(static_cast<float>(value.b))};
    }
    if (mode == WorkingMode::DwgLinear) {
        return value;
    }
    const double x = 0.70062239 * value.r + 0.14877482 * value.g + 0.10105872 * value.b;
    const double y = 0.27411851 * value.r + 0.87363190 * value.g - 0.14775041 * value.b;
    const double z = -0.09896291 * value.r - 0.13789533 * value.g + 1.32591599 * value.b;
    const double red = 3.24096994 * x - 1.53738318 * y - 0.49861076 * z;
    const double green = -0.96924364 * x + 1.87596750 * y + 0.04155506 * z;
    const double blue = 0.05563008 * x - 0.20397696 * y + 1.05697151 * z;
    return {signedPower(static_cast<float>(red), 1.0F / 2.4F),
            signedPower(static_cast<float>(green), 1.0F / 2.4F),
            signedPower(static_cast<float>(blue), 1.0F / 2.4F)};
}

float luminance(Rgb value)
{
    return std::max(0.0F, static_cast<float>(0.27411851 * std::max(0.0, value.r) +
                                             0.87363190 * std::max(0.0, value.g) -
                                             0.14775041 * std::max(0.0, value.b)));
}

float smoothstep(float lower, float upper, float value)
{
    if (value <= lower) {
        return 0.0F;
    }
    if (value >= upper) {
        return 1.0F;
    }
    const float t = (value - lower) / (upper - lower);
    return t * t * (3.0F - 2.0F * t);
}

std::uint32_t philoxWord(std::int32_t ix, std::int32_t iy, std::int64_t frame, std::uint32_t seed,
                         int layer, int octave, int channel, int block, int lane)
{
    const std::uint64_t frame_bits = static_cast<std::uint64_t>(frame);
    std::uint32_t c0 = static_cast<std::uint32_t>(ix);
    std::uint32_t c1 = static_cast<std::uint32_t>(iy);
    std::uint32_t c2 = static_cast<std::uint32_t>(frame_bits);
    std::uint32_t c3 = (static_cast<std::uint32_t>(layer) << 24U) |
                       (static_cast<std::uint32_t>(octave) << 16U) |
                       (static_cast<std::uint32_t>(channel) << 8U) |
                       static_cast<std::uint32_t>(block);
    std::uint32_t k0 = seed;
    std::uint32_t k1 = 0xCBEF2026U ^ static_cast<std::uint32_t>(frame_bits >> 32U);
    for (int round = 0; round < 10; ++round) {
        const std::uint64_t product0 = static_cast<std::uint64_t>(kPhiloxM0) * c0;
        const std::uint64_t product1 = static_cast<std::uint64_t>(kPhiloxM1) * c2;
        const std::uint32_t next_c0 = static_cast<std::uint32_t>(product1 >> 32U) ^ c1 ^ k0;
        const std::uint32_t next_c1 = static_cast<std::uint32_t>(product1);
        const std::uint32_t next_c2 = static_cast<std::uint32_t>(product0 >> 32U) ^ c3 ^ k1;
        const std::uint32_t next_c3 = static_cast<std::uint32_t>(product0);
        c0 = next_c0;
        c1 = next_c1;
        c2 = next_c2;
        c3 = next_c3;
        if (round != 9) {
            k0 += kPhiloxW0;
            k1 += kPhiloxW1;
        }
    }
    const std::array<std::uint32_t, 4> words = {c0, c1, c2, c3};
    return words[static_cast<std::size_t>(lane)];
}

float latticeGaussian(std::int32_t ix, std::int32_t iy, const GrainFieldArguments& arguments)
{
    double sum = 0.0;
    for (int block = 0; block < 3; ++block) {
        for (int lane = 0; lane < 4; ++lane) {
            const std::uint32_t word = philoxWord(ix, iy, arguments.frame, arguments.seed, arguments.layer,
                                                  arguments.octave, arguments.channel, block, lane);
            sum += (static_cast<double>(word) + 0.5) / 4294967296.0;
        }
    }
    return static_cast<float>(sum - 6.0);
}

float softenedLatticeGaussian(std::int32_t ix, std::int32_t iy, const GrainFieldArguments& arguments)
{
    const float basis_sigma = 1.0F;
    const int radius = 4;
    const double sigma_squared = static_cast<double>(basis_sigma) * basis_sigma;
    double weighted = 0.0;
    double coefficient_squared = 0.0;
    for (int dy = -radius; dy <= radius; ++dy) {
        for (int dx = -radius; dx <= radius; ++dx) {
            const double distance_squared = static_cast<double>(dx * dx + dy * dy);
            const double coefficient = std::exp(-0.5 * distance_squared / sigma_squared);
            weighted += coefficient * latticeGaussian(ix + dx, iy + dy, arguments);
            coefficient_squared += coefficient * coefficient;
        }
    }
    return static_cast<float>(weighted / std::sqrt(coefficient_squared));
}

float grainField(double u, double v, float diameter, const GrainFieldArguments& arguments)
{
    const double lattice_x = u / diameter;
    const double lattice_y = v / diameter;
    const std::int32_t ix = static_cast<std::int32_t>(std::floor(lattice_x));
    const std::int32_t iy = static_cast<std::int32_t>(std::floor(lattice_y));
    const float tx = static_cast<float>(lattice_x - ix);
    const float ty = static_cast<float>(lattice_y - iy);
    const float hx = tx * tx * (3.0F - 2.0F * tx);
    const float hy = ty * ty * (3.0F - 2.0F * ty);
    const float weights[4] = {(1.0F - hx) * (1.0F - hy), hx * (1.0F - hy),
                              (1.0F - hx) * hy, hx * hy};
    const float values[4] = {
        softenedLatticeGaussian(ix, iy, arguments),
        softenedLatticeGaussian(ix + 1, iy, arguments),
        softenedLatticeGaussian(ix, iy + 1, arguments),
        softenedLatticeGaussian(ix + 1, iy + 1, arguments),
    };
    float value = 0.0F;
    float coefficient_squared = 0.0F;
    for (int index = 0; index < 4; ++index) {
        value += weights[index] * values[index];
        coefficient_squared += weights[index] * weights[index];
    }
    return coefficient_squared > 1.0e-12F ? value / std::sqrt(coefficient_squared) : 0.0F;
}

float grainOctave(double x, double y, float diameter, const GrainFieldArguments& arguments)
{
    return grainField(x, y, diameter, arguments);
}

GrainPopulationProfile grainPopulationProfile(float exposure, float clump, int stock)
{
    const auto& base = kGrainPopulationWeights[static_cast<std::size_t>(std::clamp(stock, 0, 2))];
    const float normalized_clump = std::clamp(clump / 100.0F, 0.0F, 1.0F);
    const float shadow_bias = std::clamp(-exposure / 6.0F, -0.5F, 0.5F);
    float weights[3] = {base[0] - 0.10F * shadow_bias, base[1],
                        base[2] + 0.10F * shadow_bias + 0.34F * normalized_clump};
    weights[0] = std::max(0.04F, weights[0] - 0.14F * normalized_clump);
    weights[1] = std::max(0.04F, weights[1] - 0.20F * normalized_clump);
    const float total = weights[0] + weights[1] + weights[2];
    for (float& weight : weights) weight /= total;
    return GrainPopulationProfile{weights[0], weights[1], weights[2],
                                  1.0F + 0.045F * std::clamp(-exposure, -4.0F, 4.0F),
                                  0.015F + 0.040F * normalized_clump};
}

float grainPopulationField(double x, double y, float diameter, float softness, int population,
                           const GrainFieldArguments& arguments, const GrainPopulationProfile& profile,
                           float record_mtf)
{
    (void)population;
    const float population_diameter = diameter;
    constexpr double kCos22 = 0.9238795325;
    constexpr double kSin22 = 0.3826834324;
    const double rotated_x = kCos22 * x + kSin22 * y;
    const double rotated_y = -kSin22 * x + kCos22 * y;
    const float field = grainOctave(rotated_x, rotated_y, population_diameter, arguments);
    const float asymmetry = profile.asymmetry;
    const float mtf_gain = 0.70F + 0.30F * std::clamp(record_mtf, 0.0F, 1.3F);
    const float softness_gain = 0.70F + 0.20F * std::clamp(softness / 100.0F, 0.0F, 1.0F);
    return softness_gain * mtf_gain * (field + asymmetry * 0.60F * (field * field - 1.0F));
}

float grainChannelField(double x, double y, int format, float display_scale, float softness, int channel,
                        float exposure, const detail::GrainParameters& parameters)
{
    const int stock = std::clamp(parameters.stock_response, 0, 2);
    const float base_diameter = kGrainCaptureDiameters[static_cast<std::size_t>(std::clamp(format, 0, 4))];
    const float record_diameter = kGrainStockRecordDiameter[static_cast<std::size_t>(stock)]
                                                                  [static_cast<std::size_t>(channel)];
    const float resolution = std::clamp(parameters.film_resolution / 100.0F, 0.0F, 1.0F);
    const float record_mtf = kGrainStockRecordMtf[static_cast<std::size_t>(stock)]
                                                     [static_cast<std::size_t>(channel)] *
                             (0.72F + 0.28F * resolution);
    const float scaled_diameter = base_diameter * record_diameter * (display_scale / 100.0F);
    const GrainPopulationProfile profile = grainPopulationProfile(exposure, parameters.clump, stock);
    float value = 0.0F;
    for (int octave = 0; octave < 3; ++octave) {
        const float diameter = scaled_diameter * static_cast<float>(1 << octave);
        const GrainFieldArguments shared{parameters.frame, parameters.seed, 0, octave, 0};
        const GrainFieldArguments independent_g{parameters.frame, parameters.seed, 1, octave, 1};
        const GrainFieldArguments independent_b{parameters.frame, parameters.seed, 1, octave, 2};
        const float shared_value = grainPopulationField(x, y, diameter, softness, 1, shared, profile, record_mtf);
        const float independent_g_value = grainPopulationField(x, y, diameter, softness, 1, independent_g,
                                                                 profile, record_mtf);
        const float independent_b_value = grainPopulationField(x, y, diameter, softness, 1, independent_b,
                                                                 profile, record_mtf);
        const float q = std::clamp(parameters.chroma / 100.0F, 0.0F, 1.0F);
        const auto& base_rho = kGrainStockRecordRho[static_cast<std::size_t>(stock)];
        const float rho_rg = base_rho[0] * (1.0F - q);
        const float rho_rb = base_rho[1] * (1.0F - q);
        const float rho_gb = base_rho[2] * (1.0F - q);
        const float l11 = std::sqrt(std::max(1.0F - rho_rg * rho_rg, 1.0e-5F));
        const float l21 = (rho_gb - rho_rg * rho_rb) / l11;
        const float l22 = std::sqrt(std::max(1.0F - rho_rb * rho_rb - l21 * l21, 1.0e-5F));
        const float correlated = channel == 0 ? shared_value
                                 : channel == 1 ? rho_rg * shared_value + l11 * independent_g_value
                                                : rho_rb * shared_value + l21 * independent_g_value +
                                                      l22 * independent_b_value;
        value += kGrainOctaveWeights[static_cast<std::size_t>(octave)] * correlated;
    }
    return value / kGrainOctaveRms;
}

bool apertureContainsShape(float x, float y, int blades, float curvature, float rotation)
{
    const float radius = std::sqrt(x * x + y * y);
    if (radius > 1.0F) {
        return false;
    }
    blades = std::clamp(blades, 3, 16);
    const float sector = 2.0F * static_cast<float>(std::acos(-1.0)) / static_cast<float>(blades);
    float angle = std::atan2(y, x) - rotation * static_cast<float>(std::acos(-1.0)) / 180.0F;
    angle = std::fmod(angle, sector);
    if (angle < 0.0F) {
        angle += sector;
    }
    angle = std::abs(angle - 0.5F * sector);
    const float polygon_radius = std::cos(0.5F * sector) / std::max(std::cos(angle), 1.0e-6F);
    curvature = std::clamp(curvature, 0.0F, 1.0F);
    const float boundary = polygon_radius * (1.0F - curvature) + curvature;
    return radius <= boundary;
}

bool apertureContains(float x, float y, const detail::OpticalBlurParameters& parameters)
{
    return apertureContainsShape(x, y, parameters.blades, parameters.curvature / 100.0F, parameters.rotation);
}

std::vector<OpticalTap> opticalFieldKernel(float radius_y, const detail::OpticalBlurParameters& parameters,
                                           float field_x, float field_y)
{
    if (radius_y <= 1.0e-6F) {
        return {{0, 0, 1.0F}};
    }
    const float radius_x = radius_y * std::max(parameters.anamorphism, 0.01F);
    const int x_radius = static_cast<int>(std::ceil(radius_x)) + 1;
    const int y_radius = static_cast<int>(std::ceil(radius_y)) + 1;
    const float raw_field_radius = std::clamp(std::sqrt(field_x * field_x + field_y * field_y), 0.0F, 1.41421356F);
    const float curvature = std::clamp(parameters.field_curvature / 100.0F, -1.0F, 1.0F);
    const float field_radius = std::clamp(raw_field_radius * (1.0F + 0.28F * curvature * raw_field_radius),
                                          0.0F, 1.41421356F);
    const float inv_field_radius = field_radius > 1.0e-6F ? 1.0F / field_radius : 0.0F;
    const float radial_x = field_x * inv_field_radius;
    const float radial_y = field_y * inv_field_radius;
    constexpr std::array<float, 4> kProfileCatEye = {1.00F, 0.82F, 1.08F, 1.18F};
    const int profile = std::clamp(parameters.lens_profile, 0, 3);
    const float cat_eye = std::clamp(parameters.cat_eye / 100.0F, 0.0F, 1.0F) *
                          kProfileCatEye[static_cast<std::size_t>(profile)];
    const float bias = std::clamp(parameters.bokeh_bias / 100.0F, -1.0F, 1.0F);
    const float pupil_limit = 1.0F - 0.48F * cat_eye * std::min(field_radius, 1.0F);
    const float pupil_softness = 0.10F + 0.04F * (1.0F - std::min(field_radius, 1.0F));
    std::vector<OpticalTap> taps;
    taps.reserve(static_cast<std::size_t>((2 * x_radius + 1) * (2 * y_radius + 1)));
    const int quality = std::clamp(parameters.quality, 0, 2);
    const int kSubpixels = quality == 0 ? 2 : quality == 1 ? 4 : 8;
    const float kInvSubpixels = 1.0F / static_cast<float>(kSubpixels);
    float total = 0.0F;
    for (int dy = -y_radius; dy <= y_radius; ++dy) {
        for (int dx = -x_radius; dx <= x_radius; ++dx) {
            float weight = 0.0F;
            for (int sy = 0; sy < kSubpixels; ++sy) {
                for (int sx = 0; sx < kSubpixels; ++sx) {
                    const float px = (static_cast<float>(dx) - 0.5F +
                                      (static_cast<float>(sx) + 0.5F) * kInvSubpixels) /
                                     radius_x;
                    const float py = (static_cast<float>(dy) - 0.5F +
                                      (static_cast<float>(sy) + 0.5F) * kInvSubpixels) /
                                     radius_y;
                    if (!apertureContains(px, py, parameters)) {
                        continue;
                    }
                    const float radial_dot = px * radial_x + py * radial_y;
                    const float clip = cat_eye <= 1.0e-6F
                                           ? 0.0F
                                           : smoothstep(pupil_limit - pupil_softness, pupil_limit + pupil_softness,
                                                        radial_dot);
                    const float aperture_radius = std::clamp(px * px + py * py, 0.0F, 1.0F);
                    const float radial_weight = std::max(0.02F, 1.0F + bias * (2.0F * aperture_radius - 1.0F));
                    const float radial = px * radial_x + py * radial_y;
                    const float tangential = -px * radial_y + py * radial_x;
                    const float coma = std::clamp(parameters.coma / 100.0F, 0.0F, 1.0F);
                    const float astigmatism = std::clamp(parameters.astigmatism / 100.0F, 0.0F, 1.0F);
                    const float field_factor = std::min(field_radius, 1.0F);
                    const float coma_weight = 1.0F + 0.52F * coma * field_factor * radial *
                                                          (1.0F - 0.55F * aperture_radius);
                    const float astig_weight = 1.0F + 0.32F * astigmatism * field_factor *
                                                           (radial * radial - tangential * tangential);
                    weight += (1.0F - 0.92F * clip) * radial_weight * std::max(0.02F, coma_weight * astig_weight) *
                              kInvSubpixels * kInvSubpixels;
                }
            }
            if (weight > 0.0F) {
                taps.push_back({dx, dy, weight});
                total += weight;
            }
        }
    }
    if (total <= 1.0e-8F) {
        return {{0, 0, 1.0F}};
    }
    for (OpticalTap& tap : taps) {
        tap.weight /= total;
    }
    return taps;
}

double opticalSampleChannel(const std::vector<OpticalSample>& source, const DataWindow& bounds, int x, int y,
                            const OpticalTap& tap, int channel, float offset_x, float offset_y, double& alpha)
{
    const float sample_x = static_cast<float>(x + tap.dx) + offset_x;
    const float sample_y = static_cast<float>(y + tap.dy) + offset_y;
    const int x0 = std::clamp(static_cast<int>(std::floor(sample_x)), bounds.x, bounds.x + bounds.width - 1);
    const int y0 = std::clamp(static_cast<int>(std::floor(sample_y)), bounds.y, bounds.y + bounds.height - 1);
    const int x1 = std::clamp(x0 + 1, bounds.x, bounds.x + bounds.width - 1);
    const int y1 = std::clamp(y0 + 1, bounds.y, bounds.y + bounds.height - 1);
    const float tx = std::clamp(sample_x - static_cast<float>(x0), 0.0F, 1.0F);
    const float ty = std::clamp(sample_y - static_cast<float>(y0), 0.0F, 1.0F);
    const auto at = [&](int sx, int sy) -> const OpticalSample& {
        const std::size_t index = static_cast<std::size_t>(sy - bounds.y) * static_cast<std::size_t>(bounds.width) +
                                  static_cast<std::size_t>(sx - bounds.x);
        return source[index];
    };
    const OpticalSample& p00 = at(x0, y0);
    const OpticalSample& p10 = at(x1, y0);
    const OpticalSample& p01 = at(x0, y1);
    const OpticalSample& p11 = at(x1, y1);
    const auto interpolate = [&](double a, double b, double c, double d) {
        return (1.0 - ty) * ((1.0 - tx) * a + tx * b) + ty * ((1.0 - tx) * c + tx * d);
    };
    const double sampled_alpha = interpolate(p00.alpha, p10.alpha, p01.alpha, p11.alpha);
    alpha += sampled_alpha * tap.weight;
    if (channel == 0) {
        return interpolate(p00.value.r, p10.value.r, p01.value.r, p11.value.r) * sampled_alpha * tap.weight;
    }
    if (channel == 1) {
        return interpolate(p00.value.g, p10.value.g, p01.value.g, p11.value.g) * sampled_alpha * tap.weight;
    }
    return interpolate(p00.value.b, p10.value.b, p01.value.b, p11.value.b) * sampled_alpha * tap.weight;
}

OpticalSample opticalConvolve(const std::vector<OpticalSample>& source, const DataWindow& bounds, int x, int y,
                              const std::vector<OpticalTap>& kernel, const std::array<float, 6>& offsets)
{
    OpticalSample result{{0.0, 0.0, 0.0}, 0.0F};
    std::array<double, 3> values{};
    std::array<double, 3> alphas{};
    for (const OpticalTap& tap : kernel) {
        for (int channel = 0; channel < 3; ++channel) {
            values[static_cast<std::size_t>(channel)] +=
                opticalSampleChannel(source, bounds, x, y, tap, channel, offsets[static_cast<std::size_t>(channel * 2)],
                                     offsets[static_cast<std::size_t>(channel * 2 + 1)], alphas[static_cast<std::size_t>(channel)]);
        }
    }
    const double alpha = alphas[0];
    result.alpha = static_cast<float>(alpha);
    if (alpha > kTransparentAlpha) {
        result.value = {values[0] / alpha, values[1] / std::max(alphas[1], 1.0e-12),
                        values[2] / std::max(alphas[2], 1.0e-12)};
    }
    return result;
}

float opticalHighlightMatte(Rgb value, float alpha)
{
    if (alpha <= kTransparentAlpha) {
        return 0.0F;
    }
    return smoothstep(0.50911688F, 1.01823376F, luminance(value));
}

bool buildOpticalPyramid(std::vector<OpticalSample>&& full, int width, int height, OpticalPyramid& pyramid)
{
    pyramid.levels[0] = std::move(full);
    pyramid.widths[0] = width;
    pyramid.heights[0] = height;
    try {
        for (std::size_t level = 1; level < pyramid.levels.size(); ++level) {
            const int previous_width = pyramid.widths[level - 1U];
            const int previous_height = pyramid.heights[level - 1U];
            const int level_width = std::max(1, (previous_width + 1) / 2);
            const int level_height = std::max(1, (previous_height + 1) / 2);
            pyramid.widths[level] = level_width;
            pyramid.heights[level] = level_height;
            pyramid.levels[level].resize(static_cast<std::size_t>(level_width) * static_cast<std::size_t>(level_height));
            for (int y = 0; y < level_height; ++y) {
                for (int x = 0; x < level_width; ++x) {
                    double alpha_sum = 0.0;
                    Rgb weighted{};
                    constexpr std::array<double, 3> kWeights = {0.25, 0.50, 0.25};
                    for (int oy = -1; oy <= 1; ++oy) {
                        for (int ox = -1; ox <= 1; ++ox) {
                            const int source_x = std::clamp(2 * x + ox, 0, previous_width - 1);
                            const int source_y = std::clamp(2 * y + oy, 0, previous_height - 1);
                            const double filter_weight = kWeights[static_cast<std::size_t>(ox + 1)] *
                                                         kWeights[static_cast<std::size_t>(oy + 1)];
                            const OpticalSample& sample =
                                pyramid.levels[level - 1U][static_cast<std::size_t>(source_y) *
                                                              static_cast<std::size_t>(previous_width) +
                                                          static_cast<std::size_t>(source_x)];
                            alpha_sum += sample.alpha * filter_weight;
                            weighted.r += sample.value.r * sample.alpha * filter_weight;
                            weighted.g += sample.value.g * sample.alpha * filter_weight;
                            weighted.b += sample.value.b * sample.alpha * filter_weight;
                        }
                    }
                    OpticalSample& output = pyramid.levels[level][static_cast<std::size_t>(y) *
                                                                      static_cast<std::size_t>(level_width) +
                                                                  static_cast<std::size_t>(x)];
                    output.alpha = static_cast<float>(alpha_sum);
                    if (alpha_sum > 1.0e-12) {
                        output.value = {weighted.r / alpha_sum, weighted.g / alpha_sum, weighted.b / alpha_sum};
                    }
                }
            }
        }
    } catch (const std::bad_alloc&) {
        return false;
    }
    return true;
}

OpticalSample sampleOpticalLevel(const OpticalPyramid& pyramid, int level, float source_x, float source_y)
{
    const int clamped_level = std::clamp(level, 0, 3);
    const float scale = static_cast<float>(1 << clamped_level);
    const float level_x = source_x / scale;
    const float level_y = source_y / scale;
    const int width = pyramid.widths[static_cast<std::size_t>(clamped_level)];
    const int height = pyramid.heights[static_cast<std::size_t>(clamped_level)];
    const int x0 = std::clamp(static_cast<int>(std::floor(level_x)), 0, width - 1);
    const int y0 = std::clamp(static_cast<int>(std::floor(level_y)), 0, height - 1);
    const int x1 = std::min(x0 + 1, width - 1);
    const int y1 = std::min(y0 + 1, height - 1);
    const float tx = std::clamp(level_x - static_cast<float>(x0), 0.0F, 1.0F);
    const float ty = std::clamp(level_y - static_cast<float>(y0), 0.0F, 1.0F);
    const auto at = [&](int x, int y) -> const OpticalSample& {
        return pyramid.levels[static_cast<std::size_t>(clamped_level)][static_cast<std::size_t>(y) *
                                                                            static_cast<std::size_t>(width) +
                                                                        static_cast<std::size_t>(x)];
    };
    const OpticalSample& a = at(x0, y0);
    const OpticalSample& b = at(x1, y0);
    const OpticalSample& c = at(x0, y1);
    const OpticalSample& d = at(x1, y1);
    const auto mix4 = [&](double av, double bv, double cv, double dv) {
        return (1.0 - ty) * ((1.0 - tx) * av + tx * bv) + ty * ((1.0 - tx) * cv + tx * dv);
    };
    const double alpha = mix4(a.alpha, b.alpha, c.alpha, d.alpha);
    OpticalSample result{{0.0, 0.0, 0.0}, static_cast<float>(alpha)};
    if (alpha > 1.0e-12) {
        result.value = {mix4(a.value.r * a.alpha, b.value.r * b.alpha, c.value.r * c.alpha, d.value.r * d.alpha) / alpha,
                        mix4(a.value.g * a.alpha, b.value.g * b.alpha, c.value.g * c.alpha, d.value.g * d.alpha) / alpha,
                        mix4(a.value.b * a.alpha, b.value.b * b.alpha, c.value.b * c.alpha, d.value.b * d.alpha) / alpha};
    }
    return result;
}

OpticalSample opticalSequenceConvolve(const OpticalPyramid& pyramid,
                                      const std::array<detail::OpticalSequencePoint, 128>& sequence,
                                      int sample_count, int x, int y, float radius_y,
                                      const detail::OpticalBlurParameters& parameters, float field_x, float field_y,
                                      int channel, bool highlight_only)
{
    const float radius_x = radius_y * std::max(parameters.anamorphism, 0.01F);
    const float raw_field_radius = std::clamp(std::sqrt(field_x * field_x + field_y * field_y), 0.0F, 1.41421356F);
    const float curvature = std::clamp(parameters.field_curvature / 100.0F, -1.0F, 1.0F);
    const float field_radius = std::clamp(raw_field_radius * (1.0F + 0.28F * curvature * raw_field_radius),
                                          0.0F, 1.41421356F);
    const float inverse_field_radius = field_radius > 1.0e-6F ? 1.0F / field_radius : 0.0F;
    const float radial_x = field_x * inverse_field_radius;
    const float radial_y = field_y * inverse_field_radius;
    constexpr std::array<float, 4> kProfileCatEye = {1.00F, 0.82F, 1.08F, 1.18F};
    const float cat_eye = std::clamp(parameters.cat_eye / 100.0F, 0.0F, 1.0F) *
                          kProfileCatEye[static_cast<std::size_t>(std::clamp(parameters.lens_profile, 0, 3))];
    const float pupil_limit = 1.0F - 0.48F * cat_eye * std::min(field_radius, 1.0F);
    const float pupil_softness = 0.10F + 0.04F * (1.0F - std::min(field_radius, 1.0F));
    const float bokeh_bias = std::clamp(parameters.bokeh_bias / 100.0F, -1.0F, 1.0F);
    const float coma = std::clamp(parameters.coma / 100.0F, 0.0F, 1.0F);
    const float astigmatism = std::clamp(parameters.astigmatism / 100.0F, 0.0F, 1.0F);
    const float field_factor = std::min(field_radius, 1.0F);
    const float dispersion = 0.35F * std::clamp(parameters.chromatic_aberration / 100.0F, 0.0F, 1.0F) *
                             field_factor * radius_y;
    const float channel_sign = channel == 0 ? 1.0F : channel == 2 ? -1.0F : 0.0F;
    int lower_level = 0;
    int upper_level = 0;
    const float pyramid_blend = detail::opticalPyramidBlend(radius_y, &lower_level, &upper_level);
    double value_sum = 0.0;
    double alpha_sum = 0.0;
    for (int index = 0; index < sample_count; ++index) {
        const detail::OpticalSequencePoint& point = sequence[static_cast<std::size_t>(index)];
        const float aperture_radius = std::clamp(point.x * point.x + point.y * point.y, 0.0F, 1.0F);
        const float radial = point.x * radial_x + point.y * radial_y;
        const float tangential = -point.x * radial_y + point.y * radial_x;
        const float clip = cat_eye <= 1.0e-6F
                               ? 0.0F
                               : smoothstep(pupil_limit - pupil_softness, pupil_limit + pupil_softness, radial);
        const float radial_weight = std::max(0.02F, 1.0F + bokeh_bias * (2.0F * aperture_radius - 1.0F));
        const float coma_weight = 1.0F + 0.52F * coma * field_factor * radial * (1.0F - 0.55F * aperture_radius);
        const float astig_weight = 1.0F + 0.32F * astigmatism * field_factor *
                                                (radial * radial - tangential * tangential);
        const float weight = point.weight * (1.0F - 0.92F * clip) * radial_weight *
                             std::max(0.02F, coma_weight * astig_weight);
        const float sample_x = static_cast<float>(x) + point.x * radius_x + channel_sign * dispersion * radial_x;
        const float sample_y = static_cast<float>(y) + point.y * radius_y + channel_sign * dispersion * radial_y;
        OpticalSample sampled = sampleOpticalLevel(pyramid, lower_level, sample_x, sample_y);
        if (upper_level != lower_level) {
            const OpticalSample upper = sampleOpticalLevel(pyramid, upper_level, sample_x, sample_y);
            sampled.value = {sampled.value.r + (upper.value.r - sampled.value.r) * pyramid_blend,
                             sampled.value.g + (upper.value.g - sampled.value.g) * pyramid_blend,
                             sampled.value.b + (upper.value.b - sampled.value.b) * pyramid_blend};
            sampled.alpha += (upper.alpha - sampled.alpha) * pyramid_blend;
        }
        Rgb sampled_value = sampled.value;
        if (highlight_only) {
            const float matte = opticalHighlightMatte(sampled.value, sampled.alpha);
            sampled_value = {std::max(sampled.value.r, 0.0) * matte,
                             std::max(sampled.value.g, 0.0) * matte,
                             std::max(sampled.value.b, 0.0) * matte};
        }
        const double channel_value = channel == 0 ? sampled_value.r : channel == 1 ? sampled_value.g : sampled_value.b;
        value_sum += channel_value * sampled.alpha * weight;
        alpha_sum += sampled.alpha * weight;
    }
    OpticalSample result{{0.0, 0.0, 0.0}, static_cast<float>(alpha_sum)};
    if (alpha_sum > 1.0e-12) {
        const double value = value_sum / alpha_sum;
        if (channel == 0) result.value.r = value;
        if (channel == 1) result.value.g = value;
        if (channel == 2) result.value.b = value;
    }
    return result;
}

Rgb positive(Rgb value)
{
    return {std::max(0.0, value.r), std::max(0.0, value.g), std::max(0.0, value.b)};
}

float halationMatte(Rgb original, float alpha, const detail::HalationParameters& parameters)
{
    if (alpha <= kTransparentAlpha) {
        return 0.0F;
    }
    const Rgb positive_source = positive(original);
    const float max_rgb = static_cast<float>(std::max({positive_source.r, positive_source.g, positive_source.b}));
    const float analysis_luminance = std::max(luminance(positive_source), max_rgb * 0.42F);
    if (!parameters.highlights_only) {
        return max_rgb > 0.0F ? 1.0F : 0.0F;
    }
    const float stops = std::log2(std::max(analysis_luminance, 0x1p-16F) / 0.18F);
    const float knee = 0.08F + std::clamp(parameters.source_smoothness / 100.0F, 0.0F, 1.0F) * 1.92F;
    return smoothstep(parameters.threshold - knee, parameters.threshold + knee, stops);
}

std::size_t halationIndex(const DataWindow& bounds, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - bounds.y);
    const std::size_t column = static_cast<std::size_t>(x - bounds.x);
    return row * static_cast<std::size_t>(bounds.width) + column;
}

std::size_t halationWindowIndex(const RectI& window, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - window.y1);
    const std::size_t column = static_cast<std::size_t>(x - window.x1);
    return row * static_cast<std::size_t>(window.x2 - window.x1) + column;
}

std::vector<float> gaussianKernel(float sigma)
{
    if (sigma <= 1.0e-6F) {
        return {1.0F};
    }
    const int radius = static_cast<int>(std::ceil(3.0F * sigma));
    std::vector<float> weights(static_cast<std::size_t>(radius * 2 + 1));
    float total = 0.0F;
    for (int tap = -radius; tap <= radius; ++tap) {
        const float value = std::exp(-0.5F * static_cast<float>(tap * tap) / (sigma * sigma));
        weights[static_cast<std::size_t>(tap + radius)] = value;
        total += value;
    }
    for (float& value : weights) {
        value /= total;
    }
    return weights;
}

detail::DiagnosticView diagnosticView(const RenderRequest& request)
{
    const int view = choiceSetting(request.settings, "output_view");
    if (view == 0) {
        return detail::DiagnosticView::Final;
    }
    if (request.effect == EffectId::Halation) {
        if (view == 1) {
            return detail::DiagnosticView::Component;
        }
        if (view == 2) {
            return detail::DiagnosticView::Matte;
        }
        if (view == 3) {
            return detail::DiagnosticView::LocalOnly;
        }
        return detail::DiagnosticView::GlobalOnly;
    }
    if (request.effect == EffectId::OpticalBlur && view == 1) {
        return detail::DiagnosticView::FullImage;
    }
    if (request.effect == EffectId::OpticalBlur && view == 2) {
        return detail::DiagnosticView::Component;
    }
    if (request.effect == EffectId::OpticalBlur && view == 3) {
        return detail::DiagnosticView::GlowOnly;
    }
    if (request.effect == EffectId::OpticalBlur && view == 4) {
        return detail::DiagnosticView::Matte;
    }
    if (request.effect == EffectId::MistDiffusion) {
        if (view == 1) {
            return detail::DiagnosticView::Component;
        }
        if (view == 2 || view == 5) {
            return detail::DiagnosticView::Matte;
        }
        if (view == 3) {
            return detail::DiagnosticView::GlowOnly;
        }
        if (view == 4) {
            return detail::DiagnosticView::VeilOnly;
        }
        if (view == 6) {
            return detail::DiagnosticView::DetailDifference;
        }
    }
    if (request.effect == EffectId::LensReflections) {
        if (view == 1) {
            return detail::DiagnosticView::Component;
        }
        if (view == 2) {
            return detail::DiagnosticView::Matte;
        }
        if (view == 3) {
            return detail::DiagnosticView::SourceMap;
        }
        if (view == 4) {
            return detail::DiagnosticView::GhostPaths;
        }
        if (view == 5) {
            return detail::DiagnosticView::ElementsOnly;
        }
        if (view == 6) {
            return detail::DiagnosticView::ElementSolo;
        }
        if (view == 7) {
            return detail::DiagnosticView::MatteLimited;
        }
    }
    return view == 1 ? detail::DiagnosticView::Component : detail::DiagnosticView::Matte;
}

const unsigned char* sourcePixel(const FrameSurface& surface, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - surface.data_window.y);
    const std::size_t column = static_cast<std::size_t>(x - surface.data_window.x);
    return static_cast<const unsigned char*>(surface.data) + surface.byte_offset + row * surface.row_bytes + column * 16U;
}

unsigned char* destinationPixel(const FrameSurface& surface, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - surface.data_window.y);
    const std::size_t column = static_cast<std::size_t>(x - surface.data_window.x);
    return static_cast<unsigned char*>(surface.data) + surface.byte_offset + row * surface.row_bytes + column * 16U;
}

float externalMattePixel(const ExternalMatteInput& input, int x, int y)
{
    const FrameSurface& surface = input.surface;
    if (x < surface.data_window.x || x >= surface.data_window.x + surface.data_window.width ||
        y < surface.data_window.y || y >= surface.data_window.y + surface.data_window.height) {
        return 0.0F;
    }
    const std::size_t pixel_bytes = surfacePixelBytes(surface);
    const std::size_t row = static_cast<std::size_t>(y - surface.data_window.y);
    const std::size_t column = static_cast<std::size_t>(x - surface.data_window.x);
    const unsigned char* address = static_cast<const unsigned char*>(surface.data) + surface.byte_offset +
                                   row * surface.row_bytes + column * pixel_bytes;
    const float* value = reinterpret_cast<const float*>(address);
    auto finiteOrZero = [](float sample) {
        return std::isfinite(sample) ? sample : 0.0F;
    };
    if (surface.pixel_format == PixelFormat::AlphaFloat32) {
        return std::clamp(finiteOrZero(value[0]), 0.0F, 1.0F);
    }
    float alpha = std::clamp(finiteOrZero(value[3]), 0.0F, 1.0F);
    if (alpha <= kTransparentAlpha) {
        return 0.0F;
    }
    Rgb rgb{finiteOrZero(value[0]), finiteOrZero(value[1]), finiteOrZero(value[2])};
    if (input.alpha_association == AlphaAssociation::Premultiplied) {
        rgb.r /= alpha;
        rgb.g /= alpha;
        rgb.b /= alpha;
    }
    return std::clamp(std::max(0.0F, luminance(positive(rgb))) * alpha, 0.0F, 1.0F);
}

float sampleExternalMatte(const RenderRequest& request, int x, int y)
{
    if (request.external_matte == nullptr) {
        return 1.0F;
    }
    const FrameSurface& source = request.source;
    const FrameSurface& matte = request.external_matte->surface;
    const double canonical_width = static_cast<double>(source.data_window.width) * request.render_scale.x;
    const double canonical_height = static_cast<double>(source.data_window.height) * request.render_scale.y;
    if (canonical_width <= 0.0 || canonical_height <= 0.0) {
        return 0.0F;
    }
    const double canonical_x = (static_cast<double>(x - source.data_window.x) + 0.5) * request.render_scale.x;
    const double canonical_y = (static_cast<double>(y - source.data_window.y) + 0.5) * request.render_scale.y;
    const double u = canonical_x / canonical_width;
    const double v = canonical_y / canonical_height;
    if (u < 0.0 || u > 1.0 || v < 0.0 || v > 1.0) {
        return 0.0F;
    }
    const double matte_x = static_cast<double>(matte.data_window.x) + u * matte.data_window.width - 0.5;
    const double matte_y = static_cast<double>(matte.data_window.y) + v * matte.data_window.height - 0.5;
    if (matte_x < static_cast<double>(matte.data_window.x) - 0.5 ||
        matte_x > static_cast<double>(matte.data_window.x + matte.data_window.width) - 0.5 ||
        matte_y < static_cast<double>(matte.data_window.y) - 0.5 ||
        matte_y > static_cast<double>(matte.data_window.y + matte.data_window.height) - 0.5) {
        return 0.0F;
    }
    const int x0 = static_cast<int>(std::floor(matte_x));
    const int y0 = static_cast<int>(std::floor(matte_y));
    const float tx = static_cast<float>(std::clamp(matte_x - static_cast<double>(x0), 0.0, 1.0));
    const float ty = static_cast<float>(std::clamp(matte_y - static_cast<double>(y0), 0.0, 1.0));
    const int max_x = matte.data_window.x + matte.data_window.width - 1;
    const int max_y = matte.data_window.y + matte.data_window.height - 1;
    const float p00 = externalMattePixel(*request.external_matte, std::clamp(x0, matte.data_window.x, max_x),
                                         std::clamp(y0, matte.data_window.y, max_y));
    const float p10 = externalMattePixel(*request.external_matte, std::clamp(x0 + 1, matte.data_window.x, max_x),
                                         std::clamp(y0, matte.data_window.y, max_y));
    const float p01 = externalMattePixel(*request.external_matte, std::clamp(x0, matte.data_window.x, max_x),
                                         std::clamp(y0 + 1, matte.data_window.y, max_y));
    const float p11 = externalMattePixel(*request.external_matte, std::clamp(x0 + 1, matte.data_window.x, max_x),
                                         std::clamp(y0 + 1, matte.data_window.y, max_y));
    return std::clamp((1.0F - ty) * ((1.0F - tx) * p00 + tx * p10) +
                          ty * ((1.0F - tx) * p01 + tx * p11),
                      0.0F, 1.0F);
}

RenderSubmission failed(Error error)
{
    return RenderSubmission{SubmissionKind::Failed, error};
}

RenderSubmission renderHalationCpu(const RenderRequest& request, const detail::CompiledEffectPlan& plan)
{
    const DataWindow& bounds = request.source.data_window;
    const std::size_t pixel_count = static_cast<std::size_t>(bounds.width) * static_cast<std::size_t>(bounds.height);
    const std::size_t output_count = static_cast<std::size_t>(request.render_window.x2 - request.render_window.x1) *
                                     static_cast<std::size_t>(request.render_window.y2 - request.render_window.y1);
    std::vector<HalationSample> source;
    std::vector<HalationSample> horizontal;
    std::vector<HalationRgb> raw_halo;
    try {
        source.resize(pixel_count);
        horizontal.resize(pixel_count);
        raw_halo.assign(output_count, HalationRgb{0.0F, 0.0F, 0.0F});
    } catch (const std::bad_alloc&) {
        return failed(Error::TemporaryAllocationFailed);
    }

    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            const float* input = reinterpret_cast<const float*>(sourcePixel(request.source, x, y));
            const float alpha = input[3];
            HalationSample& sample = source[halationIndex(bounds, x, y)];
            if (alpha <= kTransparentAlpha) {
                sample = {0.0F, 0.0F, 0.0F, 0.0F, 0.0F};
                continue;
            }
            Rgb encoded{input[0], input[1], input[2]};
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded.r /= alpha;
                encoded.g /= alpha;
                encoded.b /= alpha;
            }
            const Rgb original = toDwg(encoded, plan.workingMode());
            const Rgb source_rgb = positive(original);
            const float matte = halationMatte(original, alpha, plan.halation());
            sample = {static_cast<float>(source_rgb.r) * matte, static_cast<float>(source_rgb.g) * matte,
                      static_cast<float>(source_rgb.b) * matte, std::max(0.0F, alpha), matte};
        }
    }

    std::vector<HalationRgb> raw_global;
    try {
        raw_global.assign(output_count, HalationRgb{0.0F, 0.0F, 0.0F});
    } catch (const std::bad_alloc&) {
        return failed(Error::TemporaryAllocationFailed);
    }

    const auto accumulateScatter = [&](float base_sigma, const std::array<float, 3>& scale_factors,
                                        const std::array<float, 3>& scale_weights,
                                        std::vector<HalationRgb>& destination) {
        constexpr std::array<float, 3> channel_sigma_factors = {1.20F, 1.00F, 0.82F};
        for (std::size_t scale = 0; scale < scale_factors.size(); ++scale) {
            for (int channel = 0; channel < 3; ++channel) {
                const float sigma_y = base_sigma * scale_factors[scale] * channel_sigma_factors[channel];
                const float sigma_x = sigma_y * static_cast<float>(request.render_scale.y / request.render_scale.x);
                const std::vector<float> horizontal_kernel = gaussianKernel(sigma_x);
                const std::vector<float> vertical_kernel = gaussianKernel(sigma_y);
                const int horizontal_radius = static_cast<int>(horizontal_kernel.size() / 2U);
                const int vertical_radius = static_cast<int>(vertical_kernel.size() / 2U);
                for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
                    for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
                        HalationSample& value = horizontal[halationIndex(bounds, x, y)];
                        value = {0.0F, 0.0F, 0.0F, 0.0F, 0.0F};
                        for (int tap = -horizontal_radius; tap <= horizontal_radius; ++tap) {
                            const int sample_x = std::clamp(x + tap, bounds.x, bounds.x + bounds.width - 1);
                            const HalationSample& input = source[halationIndex(bounds, sample_x, y)];
                            const float weight = horizontal_kernel[static_cast<std::size_t>(tap + horizontal_radius)];
                            const float channel_value = channel == 0 ? input.r : (channel == 1 ? input.g : input.b);
                            if (channel == 0) {
                                value.r += channel_value * input.alpha_weight * weight;
                            } else if (channel == 1) {
                                value.g += channel_value * input.alpha_weight * weight;
                            } else {
                                value.b += channel_value * input.alpha_weight * weight;
                            }
                            value.alpha_weight += input.alpha_weight * weight;
                        }
                    }
                }
                for (int y = request.render_window.y1; y < request.render_window.y2; ++y) {
                    for (int x = request.render_window.x1; x < request.render_window.x2; ++x) {
                        float blurred = 0.0F;
                        float blurred_alpha = 0.0F;
                        for (int tap = -vertical_radius; tap <= vertical_radius; ++tap) {
                            const int sample_y = std::clamp(y + tap, bounds.y, bounds.y + bounds.height - 1);
                            const HalationSample& input = horizontal[halationIndex(bounds, x, sample_y)];
                            const float weight = vertical_kernel[static_cast<std::size_t>(tap + vertical_radius)];
                            blurred += (channel == 0 ? input.r : (channel == 1 ? input.g : input.b)) * weight;
                            blurred_alpha += input.alpha_weight * weight;
                        }
                        const HalationSample& original = source[halationIndex(bounds, x, y)];
                        HalationRgb& halo = destination[halationWindowIndex(request.render_window, x, y)];
                        const float original_channel = channel == 0 ? original.r : (channel == 1 ? original.g : original.b);
                        if (blurred_alpha > 0.0F) {
                            const float contribution = scale_weights[scale] *
                                                       std::max(blurred / blurred_alpha - original_channel, 0.0F);
                            if (channel == 0) {
                                halo.r += contribution;
                            } else if (channel == 1) {
                                halo.g += contribution;
                            } else {
                                halo.b += contribution;
                            }
                        }
                    }
                }
            }
        }
    };

    const float local_sigma = static_cast<float>(bounds.height) * (plan.halation().radius / 100.0F);
    if (local_sigma > 0.0F) {
        accumulateScatter(local_sigma, kHalationSigmaFactors, kHalationWeights, raw_halo);
    }
    const float global_diffusion = std::clamp(plan.halation().global_diffusion / 100.0F, 0.0F, 1.0F);
    if (global_diffusion > 0.0F) {
        constexpr std::array<float, 3> global_scale_factors = {0.60F, 1.30F, 2.40F};
        constexpr std::array<float, 3> global_scale_weights = {0.52F, 0.32F, 0.16F};
        const float global_sigma = static_cast<float>(bounds.height) * global_diffusion * 0.35F;
        accumulateScatter(global_sigma, global_scale_factors, global_scale_weights, raw_global);
    }

    const float warmth = plan.halation().warmth / 100.0F;
    const float saturation = plan.halation().saturation / 100.0F;
    const float red_bias = std::clamp(plan.halation().red_bias / 100.0F, 0.0F, 1.0F);
    const float blue_compensation = std::clamp(plan.halation().blue_compensation / 100.0F, 0.0F, 1.0F);
    constexpr Rgb generic_warm_tint{1.0, 0.58, 0.28};
    constexpr float generic_warm_luminance = 0.27411851F + 0.87363190F * 0.58F - 0.14775041F * 0.28F;
    const float core_protection = std::clamp(plan.halation().core_protection / 100.0F, 0.0F, 1.0F);
    const float background_adaptation = std::clamp(plan.halation().background_adaptation / 100.0F, 0.0F, 1.0F);
    for (int y = request.render_window.y1; y < request.render_window.y2; ++y) {
        for (int x = request.render_window.x1; x < request.render_window.x2; ++x) {
            const float* input = reinterpret_cast<const float*>(sourcePixel(request.source, x, y));
            float* output = reinterpret_cast<float*>(destinationPixel(request.destination, x, y));
            const float alpha = input[3];
            if (alpha <= kTransparentAlpha) {
                output[0] = 0.0F;
                output[1] = 0.0F;
                output[2] = 0.0F;
                std::memcpy(&output[3], &input[3], sizeof(float));
                continue;
            }
            Rgb encoded{input[0], input[1], input[2]};
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded.r /= alpha;
                encoded.g /= alpha;
                encoded.b /= alpha;
            }
            const Rgb original = toDwg(encoded, plan.workingMode());
            const auto colorize = [&](HalationRgb raw) {
                const Rgb profiled{raw.r * (0.65 + 0.70 * red_bias),
                                   raw.g * (0.95 - 0.15 * red_bias),
                                   raw.b * (0.65 + 0.85 * blue_compensation)};
                const float raw_luminance = std::max(luminance(profiled), 0.0F);
                const Rgb warm_target{raw_luminance * generic_warm_tint.r / generic_warm_luminance,
                                      raw_luminance * generic_warm_tint.g / generic_warm_luminance,
                                      raw_luminance * generic_warm_tint.b / generic_warm_luminance};
                const float warm_mix = std::clamp(warmth * 0.70F, 0.0F, 0.70F);
                const Rgb warmed{profiled.r + (warm_target.r - profiled.r) * warm_mix,
                                 profiled.g + (warm_target.g - profiled.g) * warm_mix,
                                 profiled.b + (warm_target.b - profiled.b) * warm_mix};
                const float warm_luminance = luminance(warmed);
                const Rgb profile_relative{
                    warm_luminance + (warmed.r - warm_luminance) * saturation,
                    warm_luminance + (warmed.g - warm_luminance) * saturation,
                    warm_luminance + (warmed.b - warm_luminance) * saturation};
                if (plan.halation().color_emphasis_mix <= 0.0F) {
                    return profile_relative;
                }
                float target_r = plan.halation().color_target_r;
                float target_g = plan.halation().color_target_g;
                float target_b = plan.halation().color_target_b;
                if (plan.halation().color_mode == detail::HalationColorMode::AutoSceneAdaptive) {
                    const float total = std::max(raw.r + raw.g + raw.b, 1.0e-6F);
                    const float normalized_r = std::clamp(raw.r / total, 0.0F, 1.0F);
                    const float normalized_g = std::clamp(raw.g / total, 0.0F, 1.0F);
                    const float normalized_b = std::clamp(raw.b / total, 0.0F, 1.0F);
                    const float warm_weight =
                        smoothstep(0.24F, 0.48F, normalized_r - normalized_b) *
                        smoothstep(0.12F, 0.20F, normalized_g - normalized_b);
                    const float cool_weight = smoothstep(
                        0.30F, 0.55F, std::max(normalized_b - normalized_r, normalized_g - normalized_r));
                    const float amber_weight = (1.0F - cool_weight) * warm_weight;
                    const float red_weight = 1.0F - cool_weight - amber_weight;
                    target_r = red_weight + amber_weight + cool_weight;
                    target_g = red_weight * 0.16F + amber_weight * 0.55F + cool_weight;
                    target_b = red_weight * 0.04F + amber_weight * 0.12F + cool_weight;
                    const float target_luminance = std::max(
                        0.27411851F * target_r + 0.87363190F * target_g - 0.14775041F * target_b,
                        1.0e-6F);
                    target_r /= target_luminance;
                    target_g /= target_luminance;
                    target_b /= target_luminance;
                    const float profile_r = static_cast<float>(profile_relative.r);
                    const float profile_g = static_cast<float>(profile_relative.g);
                    const float profile_b = static_cast<float>(profile_relative.b);
                    const float profile_luminance = std::max(
                        0.0F, 0.27411851F * std::max(profile_r, 0.0F) +
                                  0.87363190F * std::max(profile_g, 0.0F) -
                                  0.14775041F * std::max(profile_b, 0.0F));
                    const float emphasis_mix = plan.halation().color_emphasis_mix;
                    const float emphasized_r = profile_luminance * target_r;
                    const float emphasized_g = profile_luminance * target_g;
                    const float emphasized_b = profile_luminance * target_b;
                    return Rgb{profile_r + (emphasized_r - profile_r) * emphasis_mix,
                               profile_g + (emphasized_g - profile_g) * emphasis_mix,
                               profile_b + (emphasized_b - profile_b) * emphasis_mix};
                }
                const float profile_luminance = luminance(profile_relative);
                const Rgb target{profile_luminance * target_r, profile_luminance * target_g,
                                 profile_luminance * target_b};
                const float emphasis_mix = plan.halation().color_emphasis_mix;
                return Rgb{profile_relative.r + (target.r - profile_relative.r) * emphasis_mix,
                           profile_relative.g + (target.g - profile_relative.g) * emphasis_mix,
                           profile_relative.b + (target.b - profile_relative.b) * emphasis_mix};
            };
            const Rgb local_colored = colorize(raw_halo[halationWindowIndex(request.render_window, x, y)]);
            const Rgb global_colored = colorize(raw_global[halationWindowIndex(request.render_window, x, y)]);
            const Rgb positive_original = positive(original);
            const float local_background = std::max(luminance(positive_original), 0.0F);
            const float background_visibility =
                1.0F - background_adaptation * smoothstep(0.32F, 2.0F, local_background);
            const float source_matte = source[halationIndex(bounds, x, y)].source_matte;
            const float local_core_visibility =
                1.0F - core_protection * source[halationIndex(bounds, x, y)].source_matte;
            const float global_core_visibility = 1.0F - core_protection * 0.65F * source_matte;
            const float local_visibility = std::max(0.0F, background_visibility * local_core_visibility);
            const float global_visibility = std::max(0.0F, background_visibility * global_core_visibility);
            const float amount = plan.halation().amount / 100.0F;
            const Rgb local_component{local_colored.r * amount * local_visibility,
                                      local_colored.g * amount * local_visibility,
                                      local_colored.b * amount * local_visibility};
            const Rgb global_component{global_colored.r * amount * 0.35F * global_visibility,
                                       global_colored.g * amount * 0.35F * global_visibility,
                                       global_colored.b * amount * 0.35F * global_visibility};
            const Rgb component{local_component.r + global_component.r,
                                local_component.g + global_component.g,
                                local_component.b + global_component.b};
            Rgb result{};
            if (plan.diagnosticView() == detail::DiagnosticView::Final) {
                result = {original.r + component.r * plan.mixAmount(), original.g + component.g * plan.mixAmount(),
                          original.b + component.b * plan.mixAmount()};
            } else if (plan.diagnosticView() == detail::DiagnosticView::Component) {
                result = component;
            } else if (plan.diagnosticView() == detail::DiagnosticView::LocalOnly) {
                result = local_component;
            } else if (plan.diagnosticView() == detail::DiagnosticView::GlobalOnly) {
                result = global_component;
            } else if (plan.diagnosticView() == detail::DiagnosticView::Matte) {
                const float matte = source[halationIndex(bounds, x, y)].source_matte;
                result = {matte, matte, matte};
            } else {
                result = {0.0, 0.0, 0.0};
            }
            Rgb encoded_output = fromDwg(result, plan.workingMode());
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded_output.r *= alpha;
                encoded_output.g *= alpha;
                encoded_output.b *= alpha;
            }
            output[0] = static_cast<float>(encoded_output.r);
            output[1] = static_cast<float>(encoded_output.g);
            output[2] = static_cast<float>(encoded_output.b);
            std::memcpy(&output[3], &input[3], sizeof(float));
        }
    }
    return RenderSubmission{SubmissionKind::Completed, Error::None};
}

RenderSubmission renderFilmGrainCpu(const RenderRequest& request, const detail::CompiledEffectPlan& plan)
{
    const detail::GrainParameters& parameters = plan.grain();
    const DataWindow& bounds = request.source.data_window;
    const int format = std::clamp(parameters.format, 0, 4);
    const int stock = std::clamp(parameters.stock_response, 0, 2);
    const int processing = std::clamp(parameters.processing_modifier, 0, 2);
    const float stock_rms = kGrainStockRms[static_cast<std::size_t>(stock)];
    const float processing_gain = processing == 1 ? 1.12F : processing == 2 ? 0.88F : 1.0F;
    const float height_scale = 1080.0F / static_cast<float>(bounds.height) *
                               static_cast<float>(request.render_scale.y) * parameters.scan_sampling;
    for (int y = request.render_window.y1; y < request.render_window.y2; ++y) {
        for (int x = request.render_window.x1; x < request.render_window.x2; ++x) {
            const float* input = reinterpret_cast<const float*>(sourcePixel(request.source, x, y));
            float* output = reinterpret_cast<float*>(destinationPixel(request.destination, x, y));
            const float alpha = input[3];
            if (alpha <= kTransparentAlpha) {
                output[0] = 0.0F;
                output[1] = 0.0F;
                output[2] = 0.0F;
                std::memcpy(&output[3], &input[3], sizeof(float));
                continue;
            }

            Rgb encoded{input[0], input[1], input[2]};
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded.r /= alpha;
                encoded.g /= alpha;
                encoded.b /= alpha;
            }
            const Rgb original = toDwg(encoded, plan.workingMode());
            const Rgb positive_source = positive(original);
            const float analysis_luminance = luminance(original);
            const float exposure = std::log2(std::max(analysis_luminance, 0x1p-16F) / 0.18F) +
                                   parameters.exposure_bias;
            const float shadow_response = 1.0F - smoothstep(-5.0F, -1.0F, exposure);
            const float highlight_response = smoothstep(1.0F, 5.0F, exposure);
            const float midtone_response = std::max(0.0F, 1.0F - std::max(shadow_response, highlight_response));
            const float response = (parameters.shadow * shadow_response + parameters.midtone * midtone_response +
                                    parameters.highlight * highlight_response) /
                                   100.0F;
            const float sigma_stop = 0.08F * (parameters.amount / 100.0F) * stock_rms * processing_gain * response;
            const double canonical_x = static_cast<double>(x - bounds.x) + 0.5;
            const double canonical_y = static_cast<double>(y - bounds.y) + 0.5;
            const double scale = static_cast<double>(height_scale);
            const double grain_x = canonical_x * scale;
            const double grain_y = canonical_y * scale;
            Rgb component{};
            for (int channel = 0; channel < 3; ++channel) {
                const float field = grainChannelField(grain_x, grain_y, format, parameters.size,
                                                      parameters.softness, channel, exposure, parameters);
                const float correlated = sigma_stop * field;
                const double source_value = channel == 0 ? positive_source.r
                                         : channel == 1 ? positive_source.g
                                                        : positive_source.b;
                const double value = source_value > 0.0 ? source_value * std::exp2(correlated) - source_value : 0.0;
                if (channel == 0) component.r = value;
                if (channel == 1) component.g = value;
                if (channel == 2) component.b = value;
            }

            Rgb result{};
            if (plan.diagnosticView() == detail::DiagnosticView::Final) {
                result = {original.r + component.r * plan.mixAmount(), original.g + component.g * plan.mixAmount(),
                          original.b + component.b * plan.mixAmount()};
            } else if (plan.diagnosticView() == detail::DiagnosticView::Component) {
                result = component;
            } else {
                const float matte = std::clamp(response / 2.0F, 0.0F, 1.0F);
                result = {matte, matte, matte};
            }
            Rgb encoded_output = fromDwg(result, plan.workingMode());
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded_output.r *= alpha;
                encoded_output.g *= alpha;
                encoded_output.b *= alpha;
            }
            output[0] = static_cast<float>(encoded_output.r);
            output[1] = static_cast<float>(encoded_output.g);
            output[2] = static_cast<float>(encoded_output.b);
            std::memcpy(&output[3], &input[3], sizeof(float));
        }
    }
    return RenderSubmission{SubmissionKind::Completed, Error::None};
}

RenderSubmission renderOpticalBlurCpu(const RenderRequest& request, const detail::CompiledEffectPlan& plan)
{
    const DataWindow& bounds = request.source.data_window;
    const std::size_t count = static_cast<std::size_t>(bounds.width) * static_cast<std::size_t>(bounds.height);
    std::vector<OpticalSample> source;
    try {
        source.resize(count);
    } catch (const std::bad_alloc&) {
        return failed(Error::TemporaryAllocationFailed);
    }

    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            const float* input = reinterpret_cast<const float*>(sourcePixel(request.source, x, y));
            const float alpha = input[3];
            OpticalSample& sample = source[halationIndex(bounds, x, y)];
            if (alpha <= kTransparentAlpha) {
                sample = {{0.0, 0.0, 0.0}, 0.0F};
                continue;
            }
            Rgb encoded{input[0], input[1], input[2]};
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded.r /= alpha;
                encoded.g /= alpha;
                encoded.b /= alpha;
            }
            const Rgb original = toDwg(encoded, plan.workingMode());
            sample = {original, alpha};
        }
    }

    OpticalPyramid pyramid;
    if (!buildOpticalPyramid(std::move(source), bounds.width, bounds.height, pyramid)) {
        return failed(Error::TemporaryAllocationFailed);
    }
    const auto sequence = detail::makeOpticalSequence(plan.optical().blades, plan.optical().curvature,
                                                       plan.optical().rotation);
    const int sample_count = plan.optical().sample_count;
    const bool legacy_aperture_preview = plan.diagnosticView() == detail::DiagnosticView::FullImage &&
        plan.optical().lens_profile == 0 && std::abs(plan.optical().bokeh_bias) <= 1.0e-6F &&
        std::abs(plan.optical().cat_eye) <= 1.0e-6F && std::abs(plan.optical().vignetting) <= 1.0e-6F &&
        std::abs(plan.optical().coma) <= 1.0e-6F && std::abs(plan.optical().astigmatism) <= 1.0e-6F &&
        std::abs(plan.optical().field_curvature) <= 1.0e-6F &&
        std::abs(plan.optical().chromatic_aberration) <= 1.0e-6F;

    const float radius = static_cast<float>(bounds.height) * plan.optical().blur / 100.0F;
    const float response = plan.optical().highlight_response / 100.0F;
    for (int y = request.render_window.y1; y < request.render_window.y2; ++y) {
        for (int x = request.render_window.x1; x < request.render_window.x2; ++x) {
            const float* input = reinterpret_cast<const float*>(sourcePixel(request.source, x, y));
            float* output = reinterpret_cast<float*>(destinationPixel(request.destination, x, y));
            const float alpha = input[3];
            if (alpha <= kTransparentAlpha) {
                output[0] = 0.0F;
                output[1] = 0.0F;
                output[2] = 0.0F;
                std::memcpy(&output[3], &input[3], sizeof(float));
                continue;
            }
            Rgb encoded{input[0], input[1], input[2]};
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded.r /= alpha;
                encoded.g /= alpha;
                encoded.b /= alpha;
            }
            const Rgb original = toDwg(encoded, plan.workingMode());
            const float field_x = 2.0F * (static_cast<float>(x - bounds.x) + 0.5F) /
                                      static_cast<float>(bounds.width) -
                                  1.0F;
            const float field_y = 2.0F * (static_cast<float>(y - bounds.y) + 0.5F) /
                                      static_cast<float>(bounds.height) -
                                  1.0F;
            const float field_radius = std::clamp(std::sqrt(field_x * field_x + field_y * field_y), 0.0F, 1.41421356F);
            const float focus_bias = std::clamp(plan.optical().field_curvature / 100.0F, -1.0F, 1.0F);
            const float effective_radius = radius * (1.0F + 0.30F * focus_bias *
                                                     std::min(field_radius * field_radius, 1.0F));
            Rgb base{};
            Rgb blurred_highlight{};
            if (legacy_aperture_preview) {
                const std::vector<OpticalTap> field_kernel =
                    opticalFieldKernel(effective_radius, plan.optical(), field_x, field_y);
                base = opticalConvolve(pyramid.levels[0], bounds, x, y, field_kernel,
                                       {0.0F, 0.0F, 0.0F, 0.0F, 0.0F, 0.0F}).value;
            } else {
                for (int channel = 0; channel < 3; ++channel) {
                    const OpticalSample base_channel = opticalSequenceConvolve(
                        pyramid, sequence, sample_count, x - bounds.x, y - bounds.y, effective_radius,
                        plan.optical(), field_x, field_y, channel, false);
                    const OpticalSample highlight_channel = opticalSequenceConvolve(
                        pyramid, sequence, sample_count, x - bounds.x, y - bounds.y, effective_radius,
                        plan.optical(), field_x, field_y, channel, true);
                    if (channel == 0) {
                        base.r = base_channel.value.r;
                        blurred_highlight.r = highlight_channel.value.r;
                    } else if (channel == 1) {
                        base.g = base_channel.value.g;
                        blurred_highlight.g = highlight_channel.value.g;
                    } else {
                        base.b = base_channel.value.b;
                        blurred_highlight.b = highlight_channel.value.b;
                    }
                }
            }
            const float source_matte = opticalHighlightMatte(original, alpha);
            const Rgb source_highlight{std::max(original.r, 0.0) * source_matte,
                                       std::max(original.g, 0.0) * source_matte,
                                       std::max(original.b, 0.0) * source_matte};
            const Rgb component{response * std::max(blurred_highlight.r - source_highlight.r, 0.0),
                                response * std::max(blurred_highlight.g - source_highlight.g, 0.0),
                                response * std::max(blurred_highlight.b - source_highlight.b, 0.0)};
            const float vignette = 1.0F - 0.78F * std::clamp(plan.optical().vignetting / 100.0F, 0.0F, 1.0F) *
                                             std::min(field_radius * field_radius, 1.0F);
            const Rgb effected{(base.r + component.r) * vignette,
                               (base.g + component.g) * vignette,
                               (base.b + component.b) * vignette};
            Rgb result{};
            if (plan.diagnosticView() == detail::DiagnosticView::Final) {
                result = {original.r + (effected.r - original.r) * plan.mixAmount(),
                          original.g + (effected.g - original.g) * plan.mixAmount(),
                          original.b + (effected.b - original.b) * plan.mixAmount()};
            } else if (plan.diagnosticView() == detail::DiagnosticView::FullImage) {
                result = base;
            } else if (plan.diagnosticView() == detail::DiagnosticView::GlowOnly) {
                result = blurred_highlight;
            } else if (plan.diagnosticView() == detail::DiagnosticView::Matte) {
                const float matte = opticalHighlightMatte(original, alpha);
                result = {matte, matte, matte};
            } else {
                result = component;
            }
            Rgb encoded_output = fromDwg(result, plan.workingMode());
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded_output.r *= alpha;
                encoded_output.g *= alpha;
                encoded_output.b *= alpha;
            }
            output[0] = static_cast<float>(encoded_output.r);
            output[1] = static_cast<float>(encoded_output.g);
            output[2] = static_cast<float>(encoded_output.b);
            std::memcpy(&output[3], &input[3], sizeof(float));
        }
    }
    return RenderSubmission{SubmissionKind::Completed, Error::None};
}

detail::GhostElementPlan ghostElement(float axis_position, float magnification, float defocus,
                                      float aperture_clip, float ring_profile, float radial_falloff,
                                      std::array<float, 3> spectral_tint, float dispersion, float energy,
                                      float background_falloff, float streak_aspect,
                                      detail::GhostElementShape shape, float pattern_retention)
{
    detail::GhostElementPlan element;
    element.axis_position = axis_position;
    element.magnification = magnification;
    element.defocus = defocus;
    element.aperture_clip = aperture_clip;
    element.ring_profile = ring_profile;
    element.radial_falloff = radial_falloff;
    element.spectral_tint = spectral_tint;
    element.dispersion = dispersion;
    element.energy = energy;
    element.background_falloff = background_falloff;
    element.streak_aspect = streak_aspect;
    element.shape = shape;
    element.pattern_retention = pattern_retention;
    return element;
}

std::array<detail::GhostElementPlan, 5> lensElements(int model)
{
    using Shape = detail::GhostElementShape;
    if (model == 1) {
        return {{ghostElement(-0.22F, 0.82F, 0.12F, 0.92F, 0.00F, 1.2F, {1.00F, 0.82F, 0.66F}, 0.08F,
                              0.18F, 1.15F, 1.0F, Shape::Focused, 0.78F),
                 ghostElement(-0.58F, 1.45F, 0.48F, 0.84F, 0.00F, 1.7F, {0.76F, 1.00F, 0.84F}, 0.14F,
                              0.23F, 1.30F, 1.0F, Shape::Disc, 0.0F),
                 ghostElement(0.31F, 2.10F, 0.62F, 0.88F, 0.72F, 1.4F, {0.70F, 0.84F, 1.00F}, 0.18F,
                              0.24F, 1.45F, 1.0F, Shape::Ring, 0.0F),
                 ghostElement(-1.08F, 3.20F, 1.20F, 1.00F, 0.00F, 2.3F, {1.00F, 0.72F, 0.55F}, 0.05F,
                              0.20F, 1.75F, 1.0F, Shape::Veil, 0.0F),
                 ghostElement(0.84F, 1.15F, 0.34F, 0.94F, 0.00F, 1.8F, {0.70F, 1.00F, 0.92F}, 0.22F,
                              0.15F, 1.55F, 4.5F, Shape::Streak, 0.0F)}};
    }
    if (model == 2) {
        return {{ghostElement(-0.30F, 0.72F, 0.10F, 0.90F, 0.00F, 1.2F, {0.70F, 0.84F, 1.00F}, 0.16F,
                              0.18F, 1.25F, 1.0F, Shape::Focused, 0.72F),
                 ghostElement(-0.74F, 1.70F, 0.42F, 0.78F, 0.00F, 1.5F, {1.00F, 0.78F, 0.58F}, 0.22F,
                              0.19F, 1.40F, 1.0F, Shape::Disc, 0.0F),
                 ghostElement(0.19F, 2.45F, 0.58F, 0.86F, 0.78F, 1.3F, {0.68F, 1.00F, 0.90F}, 0.26F,
                              0.18F, 1.55F, 1.0F, Shape::Ring, 0.0F),
                 ghostElement(-1.32F, 3.60F, 1.28F, 1.00F, 0.00F, 2.1F, {1.00F, 0.70F, 0.52F}, 0.10F,
                              0.17F, 1.85F, 1.0F, Shape::Veil, 0.0F),
                 ghostElement(0.96F, 1.05F, 0.24F, 0.96F, 0.00F, 1.5F, {0.62F, 0.82F, 1.00F}, 0.32F,
                              0.28F, 1.65F, 9.0F, Shape::Streak, 0.0F)}};
    }
    return {{ghostElement(-0.34F, 0.74F, 0.08F, 0.96F, 0.00F, 1.3F, {1.00F, 0.94F, 0.84F}, 0.05F,
                          0.28F, 1.00F, 1.0F, Shape::Focused, 0.86F),
             ghostElement(-0.79F, 1.35F, 0.38F, 0.92F, 0.00F, 1.8F, {0.84F, 0.94F, 1.00F}, 0.09F,
                          0.24F, 1.15F, 1.0F, Shape::Disc, 0.0F),
             ghostElement(0.23F, 1.95F, 0.50F, 0.94F, 0.70F, 1.5F, {1.00F, 0.82F, 0.66F}, 0.12F,
                          0.18F, 1.25F, 1.0F, Shape::Ring, 0.0F),
             ghostElement(-1.16F, 2.80F, 1.00F, 1.00F, 0.00F, 2.4F, {0.82F, 1.00F, 0.90F}, 0.04F,
                          0.16F, 1.55F, 1.0F, Shape::Veil, 0.0F),
             ghostElement(0.70F, 1.05F, 0.28F, 0.96F, 0.00F, 1.8F, {0.76F, 0.90F, 1.00F}, 0.14F,
                          0.14F, 1.35F, 3.2F, Shape::Streak, 0.0F)}};
}

void convolveLens(const std::vector<Rgb>& source, const DataWindow& bounds, float sigma_y, float sigma_x,
                  std::vector<Rgb>& destination)
{
    const std::size_t count = static_cast<std::size_t>(bounds.width) * static_cast<std::size_t>(bounds.height);
    if (sigma_y <= 1.0e-6F && sigma_x <= 1.0e-6F) {
        destination = source;
        return;
    }
    const std::vector<float> horizontal_kernel = gaussianKernel(sigma_x);
    const std::vector<float> vertical_kernel = gaussianKernel(sigma_y);
    const int horizontal_radius = static_cast<int>(horizontal_kernel.size() / 2U);
    const int vertical_radius = static_cast<int>(vertical_kernel.size() / 2U);
    std::vector<Rgb> horizontal(count, Rgb{0.0, 0.0, 0.0});
    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            Rgb& value = horizontal[halationIndex(bounds, x, y)];
            for (int tap = -horizontal_radius; tap <= horizontal_radius; ++tap) {
                const int sample_x = x + tap;
                if (sample_x < bounds.x || sample_x >= bounds.x + bounds.width) {
                    continue;
                }
                const Rgb& sample = source[halationIndex(bounds, sample_x, y)];
                const float weight = horizontal_kernel[static_cast<std::size_t>(tap + horizontal_radius)];
                value.r += sample.r * weight;
                value.g += sample.g * weight;
                value.b += sample.b * weight;
            }
        }
    }
    destination.assign(count, Rgb{0.0, 0.0, 0.0});
    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            Rgb& value = destination[halationIndex(bounds, x, y)];
            for (int tap = -vertical_radius; tap <= vertical_radius; ++tap) {
                const int sample_y = y + tap;
                if (sample_y < bounds.y || sample_y >= bounds.y + bounds.height) {
                    continue;
                }
                const Rgb& sample = horizontal[halationIndex(bounds, x, sample_y)];
                const float weight = vertical_kernel[static_cast<std::size_t>(tap + vertical_radius)];
                value.r += sample.r * weight;
                value.g += sample.g * weight;
                value.b += sample.b * weight;
            }
        }
    }
}

float lensSourceMetric(Rgb value, int metric)
{
    value = positive(value);
    if (metric == 1) {
        return static_cast<float>(std::max({value.r, value.g, value.b}));
    }
    if (metric == 2) {
        return static_cast<float>(std::max({value.r, value.g, value.b}));
    }
    return luminance(value);
}

float lensSourceMatte(Rgb original, float alpha, float threshold, int metric, float gamma, float smoothness)
{
    if (alpha <= kTransparentAlpha) {
        return 0.0F;
    }
    const float metric_value = lensSourceMetric(original, metric);
    const float stops = std::log2(std::max(metric_value, 0x1p-16F) / 0.18F);
    const float knee = 1.0F + std::clamp(smoothness, 0.0F, 100.0F) * 0.02F;
    const float upper = smoothness <= 0.0F ? threshold : threshold + knee * 0.25F;
    const float matte = smoothstep(threshold - knee, upper, stops);
    return std::pow(std::clamp(matte, 0.0F, 1.0F), 1.0F / std::max(gamma, 0.25F));
}

float manualLensMatte(int x, int y, const DataWindow& bounds, const detail::LensReflectionsEffectPlan& plan)
{
    const double normalized_x = static_cast<double>(plan.manual_x) / 100.0;
    const double normalized_y = static_cast<double>(plan.manual_y) / 100.0;
    const double center_x = static_cast<double>(bounds.x) + (normalized_x + 1.0) * 0.5 * bounds.width + 0.5;
    const double center_y = static_cast<double>(bounds.y) + (normalized_y + 1.0) * 0.5 * bounds.height + 0.5;
    const double radius_y = std::max(0.5, static_cast<double>(bounds.height) * plan.manual_size / 200.0);
    const double radius_x = std::max(0.5, radius_y * std::max(plan.anamorphism, 0.5F));
    const double dx = (static_cast<double>(x) + 0.5 - center_x) / radius_x;
    const double dy = (static_cast<double>(y) + 0.5 - center_y) / radius_y;
    const double distance = std::sqrt(dx * dx + dy * dy);
    return static_cast<float>(std::clamp(1.0 - smoothstep(0.65, 1.0, distance), 0.0, 1.0));
}

Rgb manualLensColor(Rgb original, int mode)
{
    if (mode == 1) {
        const double value = std::max(0.0, static_cast<double>(luminance(original)));
        return {value, value, value};
    }
    if (mode == 2) {
        const double value = std::max(0.0, static_cast<double>(luminance(original)));
        return {value * 1.10, value * 0.90, value * 0.68};
    }
    return positive(original);
}

void applyLensMorphology(std::vector<float>& matte, const DataWindow& bounds, float morphology)
{
    const float amount = std::abs(morphology);
    if (amount < 1.0F) {
        return;
    }
    const int radius = std::clamp(static_cast<int>(std::ceil(amount / 50.0F)), 1, 2);
    const std::vector<float> input = matte;
    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            float value = morphology > 0.0F ? 0.0F : 1.0F;
            for (int dy = -radius; dy <= radius; ++dy) {
                for (int dx = -radius; dx <= radius; ++dx) {
                    const int sx = x + dx;
                    const int sy = y + dy;
                    if (sx < bounds.x || sx >= bounds.x + bounds.width || sy < bounds.y ||
                        sy >= bounds.y + bounds.height) {
                        continue;
                    }
                    const float sample = input[halationIndex(bounds, sx, sy)];
                    if (morphology > 0.0F) {
                        value = std::max(value, sample);
                    } else {
                        value = std::min(value, sample);
                    }
                }
            }
            matte[halationIndex(bounds, x, y)] = value;
        }
    }
}

std::vector<LensDetectedSource> detectLensSources(const std::vector<float>& matte, const std::vector<Rgb>& values,
                                                  const DataWindow& bounds)
{
    constexpr int kTileSize = 8;
    const int tile_columns = (bounds.width + kTileSize - 1) / kTileSize;
    const int tile_rows = (bounds.height + kTileSize - 1) / kTileSize;
    struct Tile {
        double energy = 0.0;
        double weighted_x = 0.0;
        double weighted_y = 0.0;
        double weighted_x2 = 0.0;
        double weighted_y2 = 0.0;
        Rgb color{0.0, 0.0, 0.0};
    };
    std::vector<Tile> tiles(static_cast<std::size_t>(tile_columns * tile_rows));
    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            const float weight = matte[halationIndex(bounds, x, y)];
            if (weight <= 0.0F) {
                continue;
            }
            const int tx = (x - bounds.x) / kTileSize;
            const int ty = (y - bounds.y) / kTileSize;
            Tile& tile = tiles[static_cast<std::size_t>(ty * tile_columns + tx)];
            const double energy = static_cast<double>(weight) *
                                  std::max(0.0, static_cast<double>(luminance(values[halationIndex(bounds, x, y)])));
            tile.energy += energy;
            tile.weighted_x += static_cast<double>(x) * energy;
            tile.weighted_y += static_cast<double>(y) * energy;
            tile.weighted_x2 += static_cast<double>(x) * static_cast<double>(x) * energy;
            tile.weighted_y2 += static_cast<double>(y) * static_cast<double>(y) * energy;
            tile.color.r += values[halationIndex(bounds, x, y)].r * energy;
            tile.color.g += values[halationIndex(bounds, x, y)].g * energy;
            tile.color.b += values[halationIndex(bounds, x, y)].b * energy;
        }
    }
    struct Candidate {
        int index;
        double energy;
    };
    std::vector<Candidate> candidates;
    for (int ty = 0; ty < tile_rows; ++ty) {
        for (int tx = 0; tx < tile_columns; ++tx) {
            const int index = ty * tile_columns + tx;
            const Tile& tile = tiles[static_cast<std::size_t>(index)];
            if (tile.energy <= 0.0) {
                continue;
            }
            bool maximum = true;
            for (int oy = -1; oy <= 1 && maximum; ++oy) {
                for (int ox = -1; ox <= 1; ++ox) {
                    const int nx = tx + ox;
                    const int ny = ty + oy;
                    if (nx < 0 || nx >= tile_columns || ny < 0 || ny >= tile_rows || (ox == 0 && oy == 0)) {
                        continue;
                    }
                    const Tile& neighbor = tiles[static_cast<std::size_t>(ny * tile_columns + nx)];
                    if (neighbor.energy > tile.energy ||
                        (neighbor.energy == tile.energy && ny * tile_columns + nx < index)) {
                        maximum = false;
                        break;
                    }
                }
            }
            if (maximum) {
                candidates.push_back({index, tile.energy});
            }
        }
    }
    std::sort(candidates.begin(), candidates.end(), [](const Candidate& left, const Candidate& right) {
        if (left.energy != right.energy) {
            return left.energy > right.energy;
        }
        return left.index < right.index;
    });
    if (candidates.empty()) {
        for (std::size_t index = 0; index < tiles.size(); ++index) {
            if (tiles[index].energy > 0.0) {
                candidates.push_back({static_cast<int>(index), tiles[index].energy});
            }
        }
        std::sort(candidates.begin(), candidates.end(), [](const Candidate& left, const Candidate& right) {
            if (left.energy != right.energy) {
                return left.energy > right.energy;
            }
            return left.index < right.index;
        });
    }
    candidates.resize(std::min<std::size_t>(candidates.size(), 8U));
    std::vector<LensDetectedSource> result;
    result.reserve(candidates.size());
    for (const Candidate& candidate : candidates) {
        const Tile& tile = tiles[static_cast<std::size_t>(candidate.index)];
        const double inverse = tile.energy > 0.0 ? 1.0 / tile.energy : 0.0;
        const double center_x = tile.weighted_x * inverse;
        const double center_y = tile.weighted_y * inverse;
        const double variance = std::max(0.0, tile.weighted_x2 * inverse - center_x * center_x) +
                                std::max(0.0, tile.weighted_y2 * inverse - center_y * center_y);
        result.push_back({tile.weighted_x * inverse, tile.weighted_y * inverse,
                          static_cast<float>(std::max(1.0, 1.5 * std::sqrt(variance))),
                          static_cast<float>(tile.energy),
                          {tile.color.r * inverse, tile.color.g * inverse, tile.color.b * inverse}});
    }
    return result;
}

RenderSubmission renderLensReflectionsCpu(const RenderRequest& request, const detail::CompiledEffectPlan& plan)
{
    const DataWindow& bounds = request.source.data_window;
    const std::size_t count = static_cast<std::size_t>(bounds.width) * static_cast<std::size_t>(bounds.height);
    std::vector<LensSource> source;
    std::vector<Rgb> source_values;
    std::vector<float> source_matte_before_external;
    std::vector<float> source_matte;
    std::vector<float> source_map_before_external;
    std::vector<float> source_map;
    std::vector<float> source_alpha;
    std::vector<Rgb> component;
    std::vector<Rgb> ghost_paths;
    std::vector<Rgb> warped;
    std::vector<Rgb> blurred;
    try {
        source.resize(count);
        source_values.assign(count, Rgb{0.0, 0.0, 0.0});
        source_matte_before_external.assign(count, 0.0F);
        source_matte.assign(count, 0.0F);
        source_map_before_external.assign(count, 0.0F);
        source_map.assign(count, 0.0F);
        source_alpha.assign(count, 0.0F);
        component.assign(count, Rgb{0.0, 0.0, 0.0});
        ghost_paths.assign(count, Rgb{0.0, 0.0, 0.0});
        warped.assign(count, Rgb{0.0, 0.0, 0.0});
        blurred.assign(count, Rgb{0.0, 0.0, 0.0});
    } catch (const std::bad_alloc&) {
        return failed(Error::TemporaryAllocationFailed);
    }

    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            const float* input = reinterpret_cast<const float*>(sourcePixel(request.source, x, y));
            const float alpha = input[3];
            source_alpha[halationIndex(bounds, x, y)] = alpha;
            LensSource& value = source[halationIndex(bounds, x, y)];
            if (alpha <= kTransparentAlpha) {
                value = {{0.0, 0.0, 0.0}, 0.0F};
                continue;
            }
            Rgb encoded{input[0], input[1], input[2]};
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded.r /= alpha;
                encoded.g /= alpha;
                encoded.b /= alpha;
            }
            const Rgb original = toDwg(encoded, plan.workingMode());
            const float matte_before_external = plan.reflections().source_mode == 1
                                                    ? manualLensMatte(x, y, bounds, plan.reflections()) *
                                                          static_cast<float>(std::clamp(plan.reflections().manual_intensity / 100.0F,
                                                                                         0.0F, 2.0F))
                                                    : lensSourceMatte(original, alpha, plan.reflections().threshold,
                                                                      plan.reflections().source_metric,
                                                                      plan.reflections().source_gamma,
                                                                      plan.reflections().source_smoothness);
            Rgb source_rgb = plan.reflections().source_mode == 1
                                 ? manualLensColor(original, plan.reflections().manual_color)
                                 : positive(original);
            if (plan.reflections().source_mode == 1 && luminance(source_rgb) <= 1.0e-6F) {
                source_rgb = {1.0, 1.0, 1.0};
            }
            source_values[halationIndex(bounds, x, y)] = source_rgb;
            source_matte_before_external[halationIndex(bounds, x, y)] = std::clamp(matte_before_external, 0.0F, 1.0F);
            source_matte[halationIndex(bounds, x, y)] = std::clamp(matte_before_external, 0.0F, 1.0F);
            value = {{source_rgb.r * matte_before_external * alpha, source_rgb.g * matte_before_external * alpha,
                      source_rgb.b * matte_before_external * alpha},
                     matte_before_external};
        }
    }

    applyLensMorphology(source_matte_before_external, bounds, plan.reflections().source_morphology);
    applyLensMorphology(source_matte, bounds, plan.reflections().source_morphology);
    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            const std::size_t index = halationIndex(bounds, x, y);
            if (source_alpha[index] <= kTransparentAlpha) {
                source_matte_before_external[index] = 0.0F;
                source_matte[index] = 0.0F;
            } else {
                source_matte[index] *= sampleExternalMatte(request, x, y);
            }
        }
    }
    const std::vector<LensDetectedSource> detected_sources_before_external =
        detectLensSources(source_matte_before_external, source_values, bounds);
    std::vector<LensDetectedSource> detected_sources =
        detectLensSources(source_matte, source_values, bounds);
    auto selectedMap = [&](const std::vector<float>& matte, const std::vector<LensDetectedSource>& candidates) {
        std::vector<float> selected = matte;
        if (plan.reflections().source_mode == 0 && !candidates.empty()) {
            std::fill(selected.begin(), selected.end(), 0.0F);
            for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
                for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
                    const std::size_t index = halationIndex(bounds, x, y);
                    float weight = 0.0F;
                    for (const LensDetectedSource& candidate : candidates) {
                        const double candidate_x = std::round(candidate.x * 16.0) / 16.0;
                        const double candidate_y = std::round(candidate.y * 16.0) / 16.0;
                        const double candidate_radius = std::round(static_cast<double>(candidate.radius) * 16.0) / 16.0;
                        const double dx = static_cast<double>(x) - candidate_x;
                        const double dy = static_cast<double>(y) - candidate_y;
                        const double reach = std::max(8.0, candidate_radius * 2.0 + 2.0);
                        if (dx * dx + dy * dy <= reach * reach) {
                            weight = std::max(weight, matte[index]);
                        }
                    }
                    selected[index] = weight;
                }
            }
        }
        return selected;
    };
    source_map_before_external = selectedMap(source_matte_before_external, detected_sources_before_external);
    source_map = selectedMap(source_matte, detected_sources);
    for (std::size_t index = 0; index < count; ++index) {
        source[index].matte = source_matte[index];
        source[index].value = {source_values[index].r * source_matte[index] * source_alpha[index],
                               source_values[index].g * source_matte[index] * source_alpha[index],
                               source_values[index].b * source_matte[index] * source_alpha[index]};
    }

    const double center_x = static_cast<double>(bounds.x + bounds.width / 2) +
                            static_cast<double>(plan.reflections().center_x) / 100.0 * 0.5 * bounds.width;
    const double center_y = static_cast<double>(bounds.y + bounds.height / 2) +
                            static_cast<double>(plan.reflections().center_y) / 100.0 * 0.5 * bounds.height;
    const double spread = static_cast<double>(plan.reflections().spread) / 100.0;
    const float chroma = std::clamp(plan.reflections().chroma / 100.0F, 0.0F, 1.0F);

    if (plan.reflections().source_mode == 1 && detected_sources.empty() && request.external_matte == nullptr) {
        const double source_x = static_cast<double>(bounds.x) +
                                (static_cast<double>(plan.reflections().manual_x) / 100.0 + 1.0) *
                                    0.5 * static_cast<double>(bounds.width) + 0.5;
        const double source_y = static_cast<double>(bounds.y) +
                                (static_cast<double>(plan.reflections().manual_y) / 100.0 + 1.0) *
                                    0.5 * static_cast<double>(bounds.height) + 0.5;
        const double nearest_x = std::clamp(source_x, static_cast<double>(bounds.x),
                                            static_cast<double>(bounds.x + bounds.width - 1));
        const double nearest_y = std::clamp(source_y, static_cast<double>(bounds.y),
                                            static_cast<double>(bounds.y + bounds.height - 1));
        const double outside_distance = std::hypot(source_x - nearest_x, source_y - nearest_y);
        const double reach = 0.55 * std::hypot(static_cast<double>(bounds.width), static_cast<double>(bounds.height));
        if (outside_distance <= reach) {
            const Rgb color = plan.reflections().manual_color == 2 ? Rgb{1.10, 0.90, 0.68} : Rgb{1.0, 1.0, 1.0};
            detected_sources.push_back({source_x, source_y,
                                        std::max(1.0F, bounds.height * plan.reflections().manual_size / 200.0F),
                                        std::clamp(plan.reflections().manual_intensity / 100.0F, 0.0F, 2.0F), color});
        }
    }

    const int profile = std::clamp(plan.reflections().lens_model, 0, 2);
    const int aperture_blades = profile == 0 ? 9 : profile == 1 ? 7 : 8;
    const float aperture_curvature = profile == 0 ? 0.88F : profile == 1 ? 0.42F : 0.62F;
    const float aperture_rotation = profile == 2 ? 0.0F : 11.0F;
    auto splat = [&](std::vector<Rgb>& plane, double x, double y, Rgb value) {
        const int x0 = static_cast<int>(std::floor(x));
        const int y0 = static_cast<int>(std::floor(y));
        const double fx = x - static_cast<double>(x0);
        const double fy = y - static_cast<double>(y0);
        for (int oy = 0; oy <= 1; ++oy) {
            const int py = y0 + oy;
            if (py < bounds.y || py >= bounds.y + bounds.height) {
                continue;
            }
            for (int ox = 0; ox <= 1; ++ox) {
                const int px = x0 + ox;
                if (px < bounds.x || px >= bounds.x + bounds.width) {
                    continue;
                }
                const double weight = (ox == 0 ? 1.0 - fx : fx) * (oy == 0 ? 1.0 - fy : fy);
                Rgb& destination = plane[halationIndex(bounds, px, py)];
                destination.r += value.r * weight;
                destination.g += value.g * weight;
                destination.b += value.b * weight;
            }
        }
    };
    auto elementWeight = [&](const detail::GhostElementPlan& element, double dx, double dy,
                             double radius_x, double radius_y) {
        const float nx = static_cast<float>(dx / std::max(radius_x, 1.0e-6));
        const float ny = static_cast<float>(dy / std::max(radius_y, 1.0e-6));
        const float radial = std::sqrt(nx * nx + ny * ny);
        if (element.shape == detail::GhostElementShape::Disc) {
            if (!apertureContainsShape(nx / std::max(element.aperture_clip, 0.1F),
                                       ny / std::max(element.aperture_clip, 0.1F), aperture_blades,
                                       aperture_curvature, aperture_rotation)) {
                return 0.0F;
            }
            return std::pow(std::max(0.0F, 1.0F - radial * radial), std::max(0.2F, element.radial_falloff));
        }
        if (element.shape == detail::GhostElementShape::Ring) {
            if (!apertureContainsShape(nx / std::max(element.aperture_clip, 0.1F),
                                       ny / std::max(element.aperture_clip, 0.1F), aperture_blades,
                                       aperture_curvature, aperture_rotation)) {
                return 0.0F;
            }
            const float width = 0.08F + 0.18F * (1.0F - std::clamp(element.ring_profile, 0.0F, 1.0F));
            const float offset = (radial - std::clamp(element.ring_profile, 0.2F, 0.95F)) / width;
            return std::exp(-0.5F * offset * offset) *
                   std::pow(std::max(0.0F, 1.0F - 0.35F * radial), std::max(0.2F, element.radial_falloff));
        }
        const float exponent = element.shape == detail::GhostElementShape::Veil ? 0.65F : 1.25F;
        return std::exp(-0.5F * exponent * radial * radial * std::max(0.2F, element.radial_falloff));
    };

    for (std::size_t ghost = 0; ghost < plan.reflections().elements.size(); ++ghost) {
        if (plan.reflections().element_solo > 0 && ghost + 1U != static_cast<std::size_t>(plan.reflections().element_solo)) {
            continue;
        }
        const detail::GhostElementPlan& element = plan.reflections().elements[ghost];
        std::fill(warped.begin(), warped.end(), Rgb{0.0, 0.0, 0.0});
        const float tint_luminance = std::max(luminance({element.spectral_tint[0], element.spectral_tint[1],
                                                         element.spectral_tint[2]}), 1.0e-6F);
        const Rgb tint_gain{1.0 + chroma * (static_cast<double>(element.spectral_tint[0] / tint_luminance) - 1.0),
                            1.0 + chroma * (static_cast<double>(element.spectral_tint[1] / tint_luminance) - 1.0),
                            1.0 + chroma * (static_cast<double>(element.spectral_tint[2] / tint_luminance) - 1.0)};

        for (const LensDetectedSource& candidate : detected_sources) {
            const double ghost_x = center_x + static_cast<double>(element.axis_position) * spread *
                                                  (candidate.x - center_x);
            const double ghost_y = center_y + static_cast<double>(element.axis_position) * spread *
                                                  (candidate.y - center_y);
            const double axis_length = std::hypot(candidate.x - center_x, candidate.y - center_y);
            const double axis_x = axis_length > 1.0e-6 ? (candidate.x - center_x) / axis_length : 1.0;
            const double axis_y = axis_length > 1.0e-6 ? (candidate.y - center_y) / axis_length : 0.0;

            const double path_dx = ghost_x - candidate.x;
            const double path_dy = ghost_y - candidate.y;
            const double path_length2 = path_dx * path_dx + path_dy * path_dy;
            if (path_length2 > 1.0e-8) {
                const int x0 = std::max(bounds.x, static_cast<int>(std::floor(std::min(candidate.x, ghost_x) - 1.0)));
                const int x1 = std::min(bounds.x + bounds.width - 1,
                                        static_cast<int>(std::ceil(std::max(candidate.x, ghost_x) + 1.0)));
                const int y0 = std::max(bounds.y, static_cast<int>(std::floor(std::min(candidate.y, ghost_y) - 1.0)));
                const int y1 = std::min(bounds.y + bounds.height - 1,
                                        static_cast<int>(std::ceil(std::max(candidate.y, ghost_y) + 1.0)));
                for (int y = y0; y <= y1; ++y) {
                    for (int x = x0; x <= x1; ++x) {
                        const double t = std::clamp(((static_cast<double>(x) - candidate.x) * path_dx +
                                                     (static_cast<double>(y) - candidate.y) * path_dy) /
                                                        path_length2,
                                                    0.0, 1.0);
                        const double closest_x = candidate.x + t * path_dx;
                        const double closest_y = candidate.y + t * path_dy;
                        if (std::hypot(static_cast<double>(x) - closest_x,
                                       static_cast<double>(y) - closest_y) <= 0.75) {
                            const double value = static_cast<double>(element.energy) *
                                                 std::min(1.0F, candidate.energy);
                            Rgb& path = ghost_paths[halationIndex(bounds, x, y)];
                            path.r += value;
                            path.g += value;
                            path.b += value;
                        }
                    }
                }
            }

            if (element.shape == detail::GhostElementShape::Focused) {
                std::fill(blurred.begin(), blurred.end(), Rgb{0.0, 0.0, 0.0});
                const double source_reach = std::max(4.0, static_cast<double>(candidate.radius) * 2.8);
                for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
                    for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
                        const LensSource& source_value = source[halationIndex(bounds, x, y)];
                        if (source_value.matte <= 0.0F ||
                            std::hypot(static_cast<double>(x) - candidate.x,
                                       static_cast<double>(y) - candidate.y) > source_reach) {
                            continue;
                        }
                        const double destination_x = ghost_x + static_cast<double>(element.magnification) *
                                                                   (static_cast<double>(x) - candidate.x);
                        const double destination_y = ghost_y + static_cast<double>(element.magnification) *
                                                                   (static_cast<double>(y) - candidate.y);
                        splat(blurred, destination_x, destination_y, source_value.value);
                    }
                }
                const float sigma_y = static_cast<float>(bounds.height) *
                                      (plan.reflections().blur + element.defocus * (1.0F - 0.65F * element.pattern_retention)) /
                                      100.0F;
                const float sigma_x = sigma_y * std::max(plan.reflections().anamorphism, 0.01F);
                std::vector<Rgb> focused;
                convolveLens(blurred, bounds, sigma_y, sigma_x, focused);
                double focused_luma = 0.0;
                for (const Rgb& value : focused) {
                    focused_luma += std::max(0.0F, luminance({value.r * tint_gain.r, value.g * tint_gain.g,
                                                              value.b * tint_gain.b}));
                }
                const double scale = focused_luma > 1.0e-9
                                         ? static_cast<double>(candidate.energy) * element.energy / focused_luma
                                         : 0.0;
                for (std::size_t index = 0; index < count; ++index) {
                    warped[index].r += focused[index].r * tint_gain.r * scale;
                    warped[index].g += focused[index].g * tint_gain.g * scale;
                    warped[index].b += focused[index].b * tint_gain.b * scale;
                }
                continue;
            }

            double radius_y = std::max(1.25, static_cast<double>(candidate.radius) * element.magnification +
                                                 static_cast<double>(bounds.height) *
                                                     (element.defocus + plan.reflections().blur) / 100.0);
            if (element.shape == detail::GhostElementShape::Veil) {
                radius_y *= 2.2;
            }
            const double radius_x = radius_y * std::max(0.25F, plan.reflections().anamorphism) *
                                    (element.shape == detail::GhostElementShape::Streak
                                         ? std::max(1.0F, element.streak_aspect)
                                         : 1.0F);
            const double support = element.shape == detail::GhostElementShape::Veil ||
                                           element.shape == detail::GhostElementShape::Streak
                                       ? 3.2
                                       : 1.15;
            const double dispersion = static_cast<double>(element.dispersion) * chroma * radius_y * 0.35;
            std::array<double, 3> denominator{};
            for (int channel = 0; channel < 3; ++channel) {
                const double channel_shift = static_cast<double>(channel - 1) * dispersion;
                const int x0 = std::max(bounds.x, static_cast<int>(std::floor(ghost_x - support * radius_x - dispersion)));
                const int x1 = std::min(bounds.x + bounds.width - 1,
                                        static_cast<int>(std::ceil(ghost_x + support * radius_x + dispersion)));
                const int y0 = std::max(bounds.y, static_cast<int>(std::floor(ghost_y - support * radius_y - dispersion)));
                const int y1 = std::min(bounds.y + bounds.height - 1,
                                        static_cast<int>(std::ceil(ghost_y + support * radius_y + dispersion)));
                for (int y = y0; y <= y1; ++y) {
                    for (int x = x0; x <= x1; ++x) {
                        denominator[static_cast<std::size_t>(channel)] += elementWeight(
                            element, static_cast<double>(x) - ghost_x - channel_shift * axis_x,
                            static_cast<double>(y) - ghost_y - channel_shift * axis_y, radius_x, radius_y);
                    }
                }
            }
            const double candidate_luma = std::max(1.0e-9, static_cast<double>(luminance(candidate.color)));
            Rgb target{candidate.color.r / candidate_luma * tint_gain.r,
                       candidate.color.g / candidate_luma * tint_gain.g,
                       candidate.color.b / candidate_luma * tint_gain.b};
            const double target_luma = std::max(1.0e-9, static_cast<double>(luminance(target)));
            const double target_scale = static_cast<double>(candidate.energy) * element.energy / target_luma;
            target.r *= target_scale;
            target.g *= target_scale;
            target.b *= target_scale;
            const int x0 = std::max(bounds.x, static_cast<int>(std::floor(ghost_x - support * radius_x - dispersion)));
            const int x1 = std::min(bounds.x + bounds.width - 1,
                                    static_cast<int>(std::ceil(ghost_x + support * radius_x + dispersion)));
            const int y0 = std::max(bounds.y, static_cast<int>(std::floor(ghost_y - support * radius_y - dispersion)));
            const int y1 = std::min(bounds.y + bounds.height - 1,
                                    static_cast<int>(std::ceil(ghost_y + support * radius_y + dispersion)));
            for (int y = y0; y <= y1; ++y) {
                for (int x = x0; x <= x1; ++x) {
                    Rgb& destination = warped[halationIndex(bounds, x, y)];
                    const double red = elementWeight(element, static_cast<double>(x) - ghost_x + dispersion * axis_x,
                                                     static_cast<double>(y) - ghost_y + dispersion * axis_y,
                                                     radius_x, radius_y);
                    const double green = elementWeight(element, static_cast<double>(x) - ghost_x,
                                                       static_cast<double>(y) - ghost_y, radius_x, radius_y);
                    const double blue = elementWeight(element, static_cast<double>(x) - ghost_x - dispersion * axis_x,
                                                      static_cast<double>(y) - ghost_y - dispersion * axis_y,
                                                      radius_x, radius_y);
                    destination.r += denominator[0] > 1.0e-9 ? target.r * red / denominator[0] : 0.0;
                    destination.g += denominator[1] > 1.0e-9 ? target.g * green / denominator[1] : 0.0;
                    destination.b += denominator[2] > 1.0e-9 ? target.b * blue / denominator[2] : 0.0;
                }
            }
        }

        const double global_adaptation = std::clamp(static_cast<double>(plan.reflections().background_adaptation) /
                                                         100.0,
                                                     0.0, 1.0);
        for (std::size_t index = 0; index < count; ++index) {
            const double background = std::max(0.0, static_cast<double>(luminance(source_values[index])));
            const double adaptation = 1.0 /
                                      (1.0 + global_adaptation * element.background_falloff * background);
            component[index].r += warped[index].r * adaptation;
            component[index].g += warped[index].g * adaptation;
            component[index].b += warped[index].b * adaptation;
        }
    }

    const double amount = static_cast<double>(plan.reflections().amount) / 100.0;
    const double background_adaptation = std::clamp(static_cast<double>(plan.reflections().background_adaptation) / 100.0,
                                                    0.0, 1.0);
    const double veil = std::clamp(static_cast<double>(plan.reflections().veil) / 100.0, 0.0, 1.0);
    for (int y = request.render_window.y1; y < request.render_window.y2; ++y) {
        for (int x = request.render_window.x1; x < request.render_window.x2; ++x) {
            const float* input = reinterpret_cast<const float*>(sourcePixel(request.source, x, y));
            float* output = reinterpret_cast<float*>(destinationPixel(request.destination, x, y));
            const float alpha = input[3];
            if (alpha <= kTransparentAlpha) {
                output[0] = 0.0F;
                output[1] = 0.0F;
                output[2] = 0.0F;
                std::memcpy(&output[3], &input[3], sizeof(float));
                continue;
            }
            Rgb encoded{input[0], input[1], input[2]};
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded.r /= alpha;
                encoded.g /= alpha;
                encoded.b /= alpha;
            }
            const Rgb original = toDwg(encoded, plan.workingMode());
            const Rgb raw = component[halationIndex(bounds, x, y)];
            const double background_luma = std::max(0.0, static_cast<double>(luminance(original)));
            const double adaptation = 1.0 / (1.0 + background_adaptation * background_luma);
            const float source_weight = source[halationIndex(bounds, x, y)].matte;
            const float map_weight = source_map[halationIndex(bounds, x, y)];
            const float map_weight_before_external = source_map_before_external[halationIndex(bounds, x, y)];
            const Rgb contribution{raw.r * amount * adaptation + original.r * veil * source_weight * 0.05 * adaptation,
                                   raw.g * amount * adaptation + original.g * veil * source_weight * 0.05 * adaptation,
                                   raw.b * amount * adaptation + original.b * veil * source_weight * 0.05 * adaptation};
            Rgb result{};
            if (plan.diagnosticView() == detail::DiagnosticView::Final) {
                result = {original.r + contribution.r * plan.mixAmount(), original.g + contribution.g * plan.mixAmount(),
                          original.b + contribution.b * plan.mixAmount()};
            } else if (plan.diagnosticView() == detail::DiagnosticView::Component) {
                result = contribution;
            } else if (plan.diagnosticView() == detail::DiagnosticView::GhostPaths) {
                result = ghost_paths[halationIndex(bounds, x, y)];
            } else if (plan.diagnosticView() == detail::DiagnosticView::ElementsOnly ||
                       plan.diagnosticView() == detail::DiagnosticView::ElementSolo) {
                result = contribution;
            } else {
                const float diagnostic_weight = plan.diagnosticView() == detail::DiagnosticView::SourceMap
                                                    ? map_weight_before_external
                                                    : (plan.diagnosticView() == detail::DiagnosticView::MatteLimited
                                                           ? map_weight
                                                           : source_weight);
                result = {diagnostic_weight, diagnostic_weight, diagnostic_weight};
            }
            Rgb encoded_output = fromDwg(result, plan.workingMode());
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded_output.r *= alpha;
                encoded_output.g *= alpha;
                encoded_output.b *= alpha;
            }
            output[0] = static_cast<float>(encoded_output.r);
            output[1] = static_cast<float>(encoded_output.g);
            output[2] = static_cast<float>(encoded_output.b);
            std::memcpy(&output[3], &input[3], sizeof(float));
        }
    }
    return RenderSubmission{SubmissionKind::Completed, Error::None};
}

void convolveMist(const std::vector<MistSample>& source, const DataWindow& bounds, float sigma_y, float sigma_x,
                  std::vector<Rgb>& destination)
{
    const std::size_t count = static_cast<std::size_t>(bounds.width) * static_cast<std::size_t>(bounds.height);
    std::vector<MistSample> horizontal(count);
    const std::vector<float> horizontal_kernel = gaussianKernel(sigma_x);
    const std::vector<float> vertical_kernel = gaussianKernel(sigma_y);
    const int horizontal_radius = static_cast<int>(horizontal_kernel.size() / 2U);
    const int vertical_radius = static_cast<int>(vertical_kernel.size() / 2U);
    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            MistSample& value = horizontal[halationIndex(bounds, x, y)];
            value = {{0.0, 0.0, 0.0}, 0.0F};
            for (int tap = -horizontal_radius; tap <= horizontal_radius; ++tap) {
                const int sample_x = std::clamp(x + tap, bounds.x, bounds.x + bounds.width - 1);
                const MistSample& sample = source[halationIndex(bounds, sample_x, y)];
                const float weight = horizontal_kernel[static_cast<std::size_t>(tap + horizontal_radius)];
                value.positive.r += sample.positive.r * sample.alpha * weight;
                value.positive.g += sample.positive.g * sample.alpha * weight;
                value.positive.b += sample.positive.b * sample.alpha * weight;
                value.alpha += sample.alpha * weight;
            }
        }
    }
    destination.assign(count, Rgb{0.0, 0.0, 0.0});
    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            Rgb weighted{0.0, 0.0, 0.0};
            float alpha_weight = 0.0F;
            for (int tap = -vertical_radius; tap <= vertical_radius; ++tap) {
                const int sample_y = std::clamp(y + tap, bounds.y, bounds.y + bounds.height - 1);
                const MistSample& sample = horizontal[halationIndex(bounds, x, sample_y)];
                const float weight = vertical_kernel[static_cast<std::size_t>(tap + vertical_radius)];
                weighted.r += sample.positive.r * weight;
                weighted.g += sample.positive.g * weight;
                weighted.b += sample.positive.b * weight;
                alpha_weight += sample.alpha * weight;
            }
            if (alpha_weight > 0.0F) {
                Rgb& value = destination[halationIndex(bounds, x, y)];
                value = {weighted.r / alpha_weight, weighted.g / alpha_weight, weighted.b / alpha_weight};
            }
        }
    }
}

RenderSubmission renderMistCpu(const RenderRequest& request, const detail::CompiledEffectPlan& plan)
{
    const DataWindow& bounds = request.source.data_window;
    const std::size_t count = static_cast<std::size_t>(bounds.width) * static_cast<std::size_t>(bounds.height);
    std::vector<MistSample> source;
    std::vector<MistSample> highlighted;
    std::vector<Rgb> diffusion_first;
    std::vector<Rgb> diffusion_second;
    std::vector<Rgb> bloom_first;
    std::vector<Rgb> bloom_second;
    std::vector<Rgb> detail_fine;
    std::vector<Rgb> detail_mid;
    std::vector<float> matte;
    try {
        source.resize(count);
        highlighted.resize(count);
        diffusion_first.resize(count);
        diffusion_second.resize(count);
        bloom_first.resize(count);
        bloom_second.resize(count);
        detail_fine.resize(count);
        detail_mid.resize(count);
        matte.resize(count, 0.0F);
    } catch (const std::bad_alloc&) {
        return failed(Error::TemporaryAllocationFailed);
    }

    for (int y = bounds.y; y < bounds.y + bounds.height; ++y) {
        for (int x = bounds.x; x < bounds.x + bounds.width; ++x) {
            const float* input = reinterpret_cast<const float*>(sourcePixel(request.source, x, y));
            const float alpha = input[3];
            MistSample& sample = source[halationIndex(bounds, x, y)];
            if (alpha <= kTransparentAlpha) {
                sample = {{0.0, 0.0, 0.0}, 0.0F};
                continue;
            }
            Rgb encoded{input[0], input[1], input[2]};
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded.r /= alpha;
                encoded.g /= alpha;
                encoded.b /= alpha;
            }
            const Rgb original = toDwg(encoded, plan.workingMode());
            sample = {positive(original), std::max(0.0F, alpha)};
            const float value = std::log2(std::max(luminance(original), 0x1p-16F) / 0.18F);
            const float pixel_matte = smoothstep(1.0F, 3.0F, value);
            matte[halationIndex(bounds, x, y)] = pixel_matte;
            highlighted[halationIndex(bounds, x, y)] = {
                {sample.positive.r * pixel_matte, sample.positive.g * pixel_matte,
                 sample.positive.b * pixel_matte},
                sample.alpha};
        }
    }

    const std::size_t grade = static_cast<std::size_t>(plan.mist().grade);
    const float radius_factor = kMistRadiusFactors[grade];
    const float energy_factor = kMistEnergyFactors[grade];
    const bool generic_white = plan.mist().profile == 1;
    const float profile_radius = generic_white ? 1.25F : 1.0F;
    const float height = static_cast<float>(bounds.height);
    const float veil_radius = height * ((0.10F + 1.40F * plan.mist().veil / 100.0F) / 100.0F) * radius_factor *
                              profile_radius * plan.mist().veil_radius_base;
    const float glow_radius = height * ((0.10F + 1.40F * plan.mist().glow / 100.0F) / 100.0F) * radius_factor *
                              profile_radius * plan.mist().glow_radius_base;
    const float scale_x = static_cast<float>(request.render_scale.y / request.render_scale.x);
    convolveMist(source, bounds, veil_radius, veil_radius * scale_x, diffusion_first);
    convolveMist(source, bounds, veil_radius * plan.mist().veil_radius_tail,
                 veil_radius * plan.mist().veil_radius_tail * scale_x, diffusion_second);
    convolveMist(highlighted, bounds, glow_radius, glow_radius * scale_x, bloom_first);
    convolveMist(highlighted, bounds, glow_radius * plan.mist().glow_radius_tail,
                 glow_radius * plan.mist().glow_radius_tail * scale_x, bloom_second);

    const float detail_scale = std::max(0.5F, height / 256.0F);
    convolveMist(source, bounds, plan.mist().detail_fine_sigma * detail_scale,
                 plan.mist().detail_fine_sigma * detail_scale * scale_x, detail_fine);
    convolveMist(source, bounds, plan.mist().detail_mid_sigma * detail_scale,
                 plan.mist().detail_mid_sigma * detail_scale * scale_x, detail_mid);

    const float veil_amount = plan.mist().veil / 100.0F * energy_factor;
    const float glow_amount = plan.mist().glow / 100.0F * energy_factor;
    const float contrast_slope = (veil_amount > 0.0F || plan.mist().contrast > 0.0F)
                                     ? std::max(0.20F, 1.0F - energy_factor * plan.mist().contrast /
                                                               plan.mist().veil_contrast)
                                     : 1.0F;
    const float texture = plan.mist().detail_retention / 100.0F;
    for (int y = request.render_window.y1; y < request.render_window.y2; ++y) {
        for (int x = request.render_window.x1; x < request.render_window.x2; ++x) {
            const std::size_t index = halationIndex(bounds, x, y);
            const float* input = reinterpret_cast<const float*>(sourcePixel(request.source, x, y));
            float* output = reinterpret_cast<float*>(destinationPixel(request.destination, x, y));
            const float alpha = input[3];
            if (alpha <= kTransparentAlpha) {
                output[0] = 0.0F;
                output[1] = 0.0F;
                output[2] = 0.0F;
                std::memcpy(&output[3], &input[3], sizeof(float));
                continue;
            }
            Rgb encoded{input[0], input[1], input[2]};
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded.r /= alpha;
                encoded.g /= alpha;
                encoded.b /= alpha;
            }
            const Rgb original = toDwg(encoded, plan.workingMode());
            const Rgb source_positive = source[index].positive;
            const Rgb& first = diffusion_first[index];
            const Rgb& second = diffusion_second[index];
            const Rgb& bloom_narrow = bloom_first[index];
            const Rgb& bloom_wide = bloom_second[index];
            Rgb veil_raw{};
            const Rgb veil_blur{0.70 * first.r + 0.30 * second.r,
                                0.70 * first.g + 0.30 * second.g,
                                0.70 * first.b + 0.30 * second.b};
            const Rgb highlighted_source{source_positive.r * matte[index], source_positive.g * matte[index],
                                         source_positive.b * matte[index]};
            const Rgb glow_blur{0.65 * bloom_narrow.r + 0.35 * bloom_wide.r,
                                0.65 * bloom_narrow.g + 0.35 * bloom_wide.g,
                                0.65 * bloom_narrow.b + 0.35 * bloom_wide.b};
            if (!generic_white) {
                veil_raw = {std::max(veil_blur.r - source_positive.r, 0.0),
                            std::max(veil_blur.g - source_positive.g, 0.0),
                            std::max(veil_blur.b - source_positive.b, 0.0)};
            } else {
                veil_raw = {veil_blur.r - source_positive.r, veil_blur.g - source_positive.g,
                            veil_blur.b - source_positive.b};
            }
            const Rgb glow_raw{std::max(glow_blur.r - highlighted_source.r, 0.0),
                               std::max(glow_blur.g - highlighted_source.g, 0.0),
                               std::max(glow_blur.b - highlighted_source.b, 0.0)};
            const float signed_veil_amount = generic_white ? std::min(veil_amount, 1.0F) : veil_amount;
            const float excess_veil_amount = generic_white ? std::max(veil_amount - 1.0F, 0.0F) : 0.0F;
            const Rgb veil_contribution{
                veil_raw.r * signed_veil_amount + std::max(veil_raw.r, 0.0) * excess_veil_amount,
                veil_raw.g * signed_veil_amount + std::max(veil_raw.g, 0.0) * excess_veil_amount,
                veil_raw.b * signed_veil_amount + std::max(veil_raw.b, 0.0) * excess_veil_amount};
            const Rgb glow_contribution{glow_raw.r * glow_amount, glow_raw.g * glow_amount,
                                        glow_raw.b * glow_amount};
            const Rgb veil_input{source_positive.r + veil_contribution.r,
                                 source_positive.g + veil_contribution.g,
                                 source_positive.b + veil_contribution.b};
            const float veil_luminance = std::max(luminance(veil_input), 0x1p-16F);
            const float target_luminance = 0.18F * std::exp2(contrast_slope * std::log2(veil_luminance / 0.18F));
            const float contrast_ratio = target_luminance / veil_luminance;
            const Rgb contrasted{veil_input.r * contrast_ratio, veil_input.g * contrast_ratio,
                                  veil_input.b * contrast_ratio};
            const Rgb veil_component = (veil_amount <= 0.0F && plan.mist().contrast <= 0.0F)
                                           ? Rgb{0.0, 0.0, 0.0}
                                           : Rgb{contrasted.r - source_positive.r, contrasted.g - source_positive.g,
                                                 contrasted.b - source_positive.b};
            const Rgb fine = detail_fine[index];
            const Rgb mid = detail_mid[index];
            const float source_luma = static_cast<float>(luminance(source_positive));
            const auto lumaAt = [&](int sample_x, int sample_y) {
                const int clamped_x = std::clamp(sample_x, bounds.x, bounds.x + bounds.width - 1);
                const int clamped_y = std::clamp(sample_y, bounds.y, bounds.y + bounds.height - 1);
                return static_cast<float>(luminance(source[halationIndex(bounds, clamped_x, clamped_y)].positive));
            };
            const float gradient = std::abs(lumaAt(x + 1, y) - lumaAt(x - 1, y)) +
                                   std::abs(lumaAt(x, y + 1) - lumaAt(x, y - 1));
            const float edge_protection = std::clamp(gradient * plan.mist().detail_edge_protection, 0.0F, 1.0F);
            const float softness = (1.0F - texture) * plan.mist().detail_strength * (1.0F - edge_protection);
            const float fine_delta = static_cast<float>(luminance(fine) - luminance(mid));
            const float mid_delta = static_cast<float>(luminance(mid) - source_luma);
            const float detail_gain = std::clamp(0.18F * fine_delta + 0.82F * mid_delta, -source_luma, 8.0F);
            const float detail_ratio = source_luma > 1.0e-6F ? detail_gain / source_luma : 0.0F;
            const Rgb detail_component{source_positive.r * detail_ratio * softness,
                                       source_positive.g * detail_ratio * softness,
                                       source_positive.b * detail_ratio * softness};
            const Rgb raw_contribution{glow_contribution.r + veil_component.r + detail_component.r,
                                       glow_contribution.g + veil_component.g + detail_component.g,
                                       glow_contribution.b + veil_component.b + detail_component.b};
            const Rgb positive_effected{source_positive.r + raw_contribution.r,
                                        source_positive.g + raw_contribution.g,
                                        source_positive.b + raw_contribution.b};
            const Rgb retained_positive{
                std::max(positive_effected.r, source_positive.r * plan.mist().black_retention),
                std::max(positive_effected.g, source_positive.g * plan.mist().black_retention),
                std::max(positive_effected.b, source_positive.b * plan.mist().black_retention)};
            const Rgb limited_contribution{retained_positive.r - source_positive.r,
                                           retained_positive.g - source_positive.g,
                                           retained_positive.b - source_positive.b};
            const Rgb effected{original.r - source_positive.r + retained_positive.r,
                               original.g - source_positive.g + retained_positive.g,
                               original.b - source_positive.b + retained_positive.b};
            Rgb result{};
            if (plan.diagnosticView() == detail::DiagnosticView::Final) {
                result = {original.r + (effected.r - original.r) * plan.mixAmount(),
                          original.g + (effected.g - original.g) * plan.mixAmount(),
                          original.b + (effected.b - original.b) * plan.mixAmount()};
            } else if (plan.diagnosticView() == detail::DiagnosticView::Component) {
                result = {effected.r - original.r, effected.g - original.g, effected.b - original.b};
            } else if (plan.diagnosticView() == detail::DiagnosticView::GlowOnly) {
                result = glow_contribution;
            } else if (plan.diagnosticView() == detail::DiagnosticView::VeilOnly) {
                result = veil_component;
            } else if (plan.diagnosticView() == detail::DiagnosticView::DetailDifference) {
                result = {limited_contribution.r - glow_contribution.r - veil_component.r,
                          limited_contribution.g - glow_contribution.g - veil_component.g,
                          limited_contribution.b - glow_contribution.b - veil_component.b};
            } else {
                result = {matte[index], matte[index], matte[index]};
            }
            Rgb encoded_output = fromDwg(result, plan.workingMode());
            if (request.alpha_association == AlphaAssociation::Premultiplied) {
                encoded_output.r *= alpha;
                encoded_output.g *= alpha;
                encoded_output.b *= alpha;
            }
            output[0] = static_cast<float>(encoded_output.r);
            output[1] = static_cast<float>(encoded_output.g);
            output[2] = static_cast<float>(encoded_output.b);
            std::memcpy(&output[3], &input[3], sizeof(float));
        }
    }
    return RenderSubmission{SubmissionKind::Completed, Error::None};
}

float grainScanSampling(int choice)
{
    switch (std::clamp(choice, 0, 2)) {
    case 0: return 0.75F;
    case 2: return 1.35F;
    default: return 1.0F;
    }
}

bool grainFrameIndex(double frame_time, std::int64_t& frame)
{
    const long double value = static_cast<long double>(frame_time);
    const long double rounded = value >= 0.0L ? std::floor(value + 0.5L) : std::ceil(value - 0.5L);
    if (rounded < static_cast<long double>(std::numeric_limits<std::int64_t>::min()) ||
        rounded > static_cast<long double>(std::numeric_limits<std::int64_t>::max())) {
        return false;
    }
    frame = static_cast<std::int64_t>(rounded);
    return true;
}

struct CompiledHalationColor {
    float target_r;
    float target_g;
    float target_b;
    float mix;
    detail::HalationColorMode mode;
};

CompiledHalationColor compileHalationColorEmphasis(int choice, float strength)
{
    const float mix = std::clamp(strength / 100.0F, 0.0F, 1.0F);
    if (choice == 0 || mix <= 0.0F) {
        return {1.0F, 1.0F, 1.0F, 0.0F, detail::HalationColorMode::ProfileRelative};
    }
    if (choice == 4) {
        return {1.0F, 1.0F, 1.0F, mix, detail::HalationColorMode::AutoSceneAdaptive};
    }
    std::array<float, 3> tint{};
    switch (choice) {
    case 1:
        tint = {1.0F, 0.16F, 0.04F};
        break;
    case 2:
        tint = {1.0F, 0.55F, 0.12F};
        break;
    default:
        tint = {1.0F, 1.0F, 1.0F};
        break;
    }
    const float tint_luminance =
        0.27411851F * tint[0] + 0.87363190F * tint[1] - 0.14775041F * tint[2];
    return {tint[0] / tint_luminance, tint[1] / tint_luminance, tint[2] / tint_luminance, mix,
            detail::HalationColorMode::FixedTarget};
}

detail::CompiledEffectPlan compileEffectPlan(const RenderRequest& request, detail::DiagnosticView view,
                                             std::int64_t grain_frame)
{
    const WorkingMode working_mode = static_cast<WorkingMode>(choiceSetting(request.settings, "working_mode"));
    const float mix = static_cast<float>(doubleSetting(request.settings, "mix") / 100.0);
    const detail::CommonPlan common{working_mode, view, mix};
    switch (request.effect) {
    case EffectId::Halation: {
        const CompiledHalationColor color_emphasis =
            compileHalationColorEmphasis(choiceSetting(request.settings, "color_emphasis"),
                                          static_cast<float>(doubleSetting(request.settings, "color_strength")));
        const detail::HalationEffectPlan parameters{
            static_cast<float>(doubleSetting(request.settings, "amount")),
            static_cast<float>(doubleSetting(request.settings, "radius")),
            static_cast<float>(doubleSetting(request.settings, "global_diffusion")),
            static_cast<float>(doubleSetting(request.settings, "threshold")),
            static_cast<float>(doubleSetting(request.settings, "warmth")),
            static_cast<float>(doubleSetting(request.settings, "saturation")),
            static_cast<float>(doubleSetting(request.settings, "red_bias")),
            static_cast<float>(doubleSetting(request.settings, "blue_compensation")),
            std::get<bool>(settingValue(request.settings, "highlights_only")),
            static_cast<float>(doubleSetting(request.settings, "source_smoothness")),
            static_cast<float>(doubleSetting(request.settings, "core_protection")),
            static_cast<float>(doubleSetting(request.settings, "background_adaptation")),
            color_emphasis.target_r,
            color_emphasis.target_g,
            color_emphasis.target_b,
            color_emphasis.mix,
            color_emphasis.mode,
        };
        return {request.effect, common, parameters,
                view == detail::DiagnosticView::Final && (mix == 0.0F || parameters.amount == 0.0F)};
    }
    case EffectId::FilmGrain: {
        const detail::GrainEffectPlan parameters{
            settingChoice(request.settings, "format"),
            static_cast<float>(doubleSetting(request.settings, "amount")),
            static_cast<float>(doubleSetting(request.settings, "size")),
            static_cast<float>(doubleSetting(request.settings, "softness")),
            static_cast<float>(doubleSetting(request.settings, "chroma")),
            static_cast<float>(doubleSetting(request.settings, "shadow")),
            static_cast<float>(doubleSetting(request.settings, "midtone")),
            static_cast<float>(doubleSetting(request.settings, "highlight")),
            static_cast<std::uint32_t>(std::get<std::int64_t>(settingValue(request.settings, "seed"))),
            grain_frame,
            settingChoice(request.settings, "stock_response"),
            grainScanSampling(settingChoice(request.settings, "scan_sampling")),
            settingChoice(request.settings, "processing_modifier"),
            static_cast<float>(doubleSetting(request.settings, "film_resolution")),
            static_cast<float>(doubleSetting(request.settings, "clump")),
            static_cast<float>(doubleSetting(request.settings, "exposure_bias")),
        };
        return {request.effect, common, parameters,
                view == detail::DiagnosticView::Final && (mix == 0.0F || parameters.amount == 0.0F)};
    }
    case EffectId::MistDiffusion: {
        const int mode = settingChoice(request.settings, "mode");
        const int grade = settingChoice(request.settings, "density");
        const float grade_step = static_cast<float>(grade) / 4.0F;
        const bool white = mode == 1;
        const detail::MistEffectPlan parameters{
            mode,
            grade,
            static_cast<float>(doubleSetting(request.settings, "diffusion")),
            static_cast<float>(doubleSetting(request.settings, "bloom")),
            static_cast<float>(doubleSetting(request.settings, "contrast")),
            static_cast<float>(doubleSetting(request.settings, "texture")),
            mode,
            grade,
            static_cast<float>(doubleSetting(request.settings, "diffusion")),
            static_cast<float>(doubleSetting(request.settings, "bloom")),
            static_cast<float>(doubleSetting(request.settings, "texture")),
            (white ? 0.52F : 0.38F) * (1.0F + 0.18F * grade_step),
            (white ? 1.35F : 1.05F) * (1.0F + 0.12F * grade_step),
            (white ? 1.25F : 1.00F) * (1.0F + 0.16F * grade_step),
            (white ? 1.80F : 1.35F) * (1.0F + 0.10F * grade_step),
            (white ? 0.84F : 0.68F) * (0.35F + 0.65F * grade_step),
            (white ? 1.18F : 0.84F) * (0.35F + 0.65F * grade_step),
            white ? 125.0F : 200.0F,
            white ? 0.50F : 0.72F,
            white ? 0.72F : 0.62F,
            white ? 2.10F : 1.80F,
            white ? 0.72F : 0.82F,
            1.0F,
        };
        return {request.effect, common, parameters,
                view == detail::DiagnosticView::Final &&
                    (mix == 0.0F || (parameters.diffusion == 0.0F && parameters.bloom == 0.0F &&
                                     parameters.contrast == 0.0F && parameters.texture >= 100.0F))};
    }
    case EffectId::OpticalBlur: {
        const detail::OpticalDefocusEffectPlan parameters{
            static_cast<float>(doubleSetting(request.settings, "blur")),
            static_cast<int>(std::get<std::int64_t>(settingValue(request.settings, "blades"))),
            static_cast<float>(doubleSetting(request.settings, "curvature")),
            static_cast<float>(doubleSetting(request.settings, "rotation")),
            static_cast<float>(doubleSetting(request.settings, "anamorphism")),
            static_cast<float>(doubleSetting(request.settings, "highlight_response")),
            settingChoice(request.settings, "lens_profile"),
            static_cast<float>(doubleSetting(request.settings, "bokeh_bias")),
            static_cast<float>(doubleSetting(request.settings, "cat_eye")),
            static_cast<float>(doubleSetting(request.settings, "vignetting")),
            static_cast<float>(doubleSetting(request.settings, "coma")),
            static_cast<float>(doubleSetting(request.settings, "astigmatism")),
            static_cast<float>(doubleSetting(request.settings, "field_curvature")),
            static_cast<float>(doubleSetting(request.settings, "chromatic_aberration")),
            settingChoice(request.settings, "quality"),
            detail::opticalSampleCount(settingChoice(request.settings, "quality")),
        };
        return {request.effect, common, parameters,
                view == detail::DiagnosticView::Final && (mix == 0.0F || parameters.blur == 0.0F)};
    }
    case EffectId::LensReflections: {
        const int lens_model = settingChoice(request.settings, "lens_model");
        const detail::LensReflectionsEffectPlan parameters{
            static_cast<float>(doubleSetting(request.settings, "amount")),
            static_cast<float>(doubleSetting(request.settings, "threshold")),
            lens_model,
            static_cast<float>(doubleSetting(request.settings, "spread")),
            static_cast<float>(doubleSetting(request.settings, "blur")),
            static_cast<float>(doubleSetting(request.settings, "chroma")),
            static_cast<float>(doubleSetting(request.settings, "anamorphism")),
            settingChoice(request.settings, "source_mode"),
            settingChoice(request.settings, "source_metric"),
            static_cast<float>(doubleSetting(request.settings, "source_gamma")),
            static_cast<float>(doubleSetting(request.settings, "source_smoothness")),
            static_cast<float>(doubleSetting(request.settings, "source_morphology")),
            static_cast<float>(doubleSetting(request.settings, "manual_x")),
            static_cast<float>(doubleSetting(request.settings, "manual_y")),
            static_cast<float>(doubleSetting(request.settings, "manual_size")),
            static_cast<float>(doubleSetting(request.settings, "manual_intensity")),
            settingChoice(request.settings, "manual_color"),
            static_cast<float>(doubleSetting(request.settings, "center_x")),
            static_cast<float>(doubleSetting(request.settings, "center_y")),
            static_cast<float>(doubleSetting(request.settings, "background_adaptation")),
            static_cast<float>(doubleSetting(request.settings, "veil")),
            settingChoice(request.settings, "element_solo"),
            lensElements(lens_model),
        };
        return {request.effect, common, parameters,
                view == detail::DiagnosticView::Final && (mix == 0.0F || parameters.amount == 0.0F)};
    }
    }
    return {request.effect, common, detail::HalationEffectPlan{}, true};
}

}

const std::vector<EffectDefinition>& effectDefinitions()
{
    return definitions();
}

const EffectDefinition& effectDefinition(EffectId effect)
{
    const EffectDefinition* definition = findDefinition(effect);
    if (definition == nullptr) {
        throw std::out_of_range("unsupported CBEF effect ID");
    }
    return *definition;
}

Settings defaultSettings(EffectId effect)
{
    const EffectDefinition& definition = effectDefinition(effect);
    return settingsForPreset(effect, definition.default_preset);
}

Settings settingsForPreset(EffectId effect, std::size_t preset_index)
{
    const EffectDefinition& definition = effectDefinition(effect);
    Settings settings{effect, {}};
    settings.values.reserve(definition.parameters.size());
    for (const ParameterDefinition& parameter : definition.parameters) {
        settings.values.push_back(parameter.default_value);
    }
    if (preset_index >= definition.presets.size()) {
        return settings;
    }
    for (const ParameterAssignment& assignment : definition.presets[preset_index].assignments) {
        const std::size_t index = parameterIndex(definition, assignment.parameter_id);
        if (index != definition.parameters.size()) {
            settings.values[index] = assignment.value;
        }
    }
    const std::size_t preset_parameter = parameterIndex(definition, "preset");
    settings.values[preset_parameter] = static_cast<int>(preset_index);
    return settings;
}

bool setSetting(Settings& settings, std::string_view parameter_id, SettingValue value)
{
    const EffectDefinition* definition = findDefinition(settings.effect);
    if (definition == nullptr || settings.values.size() != definition->parameters.size()) {
        return false;
    }
    const std::size_t index = parameterIndex(*definition, parameter_id);
    if (index == definition->parameters.size() || value.index() != static_cast<std::size_t>(definition->parameters[index].type)) {
        return false;
    }
    settings.values[index] = std::move(value);
    if (isPresetControlled(definition->parameters[index].id)) {
        const std::size_t preset_parameter = parameterIndex(*definition, "preset");
        std::size_t matching_preset = definition->presets.size();
        for (std::size_t preset_index = 0; preset_index < definition->presets.size(); ++preset_index) {
            const Settings expected = settingsForPreset(settings.effect, preset_index);
            bool matches = true;
            for (std::size_t parameter_index = 0; parameter_index < definition->parameters.size(); ++parameter_index) {
                if (isPresetControlled(definition->parameters[parameter_index].id) &&
                    !valuesEqual(settings.values[parameter_index], expected.values[parameter_index])) {
                    matches = false;
                    break;
                }
            }
            if (matches) {
                matching_preset = preset_index;
                break;
            }
        }
        settings.values[preset_parameter] = static_cast<int>(matching_preset);
    }
    return true;
}

const SettingValue& settingValue(const Settings& settings, std::string_view parameter_id)
{
    static const SettingValue invalid = 0.0;
    const EffectDefinition* definition = findDefinition(settings.effect);
    if (definition == nullptr || settings.values.size() != definition->parameters.size()) {
        return invalid;
    }
    const std::size_t index = parameterIndex(*definition, parameter_id);
    return index == definition->parameters.size() ? invalid : settings.values[index];
}

int settingChoice(const Settings& settings, std::string_view parameter_id)
{
    const SettingValue& value = settingValue(settings, parameter_id);
    return std::holds_alternative<int>(value) ? std::get<int>(value) : -1;
}

bool settingsUsePreset(const Settings& settings)
{
    const EffectDefinition* definition = findDefinition(settings.effect);
    if (definition == nullptr || settings.values.size() != definition->parameters.size()) {
        return false;
    }
    const int selected = settingChoice(settings, "preset");
    if (selected < 0 || selected >= static_cast<int>(definition->presets.size())) {
        return false;
    }
    const Settings expanded = settingsForPreset(settings.effect, static_cast<std::size_t>(selected));
    for (std::size_t index = 0; index < definition->parameters.size(); ++index) {
        if (isPresetControlled(definition->parameters[index].id) &&
            !valuesEqual(settings.values[index], expanded.values[index])) {
            return false;
        }
    }
    return true;
}

BackendKind CpuRenderBackend::kind() const
{
    return BackendKind::Cpu;
}

RenderSubmission render(const RenderRequest& request, RenderBackend& backend)
{
    const EffectDefinition* definition = findDefinition(request.effect);
    if (definition == nullptr) {
        return failed(Error::UnsupportedEffectId);
    }
    if (request.source.pixel_format != PixelFormat::RgbaFloat32 ||
        request.destination.pixel_format != PixelFormat::RgbaFloat32) {
        return failed(Error::UnsupportedPixelFormat);
    }
    const DataWindow& source_bounds = request.source.data_window;
    const DataWindow& destination_bounds = request.destination.data_window;
    if (source_bounds.width <= 0 || source_bounds.height <= 0 || destination_bounds.width <= 0 ||
        destination_bounds.height <= 0 || request.source.data == nullptr || request.destination.data == nullptr) {
        return failed(Error::InvalidDimensions);
    }
    const std::size_t minimum_stride = static_cast<std::size_t>(source_bounds.width) * 16U;
    if (request.source.row_bytes < minimum_stride || request.destination.row_bytes < minimum_stride ||
        request.source.row_bytes % 4U != 0U || request.destination.row_bytes % 4U != 0U) {
        return failed(Error::InvalidStride);
    }
    if (source_bounds.x != destination_bounds.x || source_bounds.y != destination_bounds.y ||
        source_bounds.width != destination_bounds.width || source_bounds.height != destination_bounds.height) {
        return failed(Error::MismatchedSurfaceBounds);
    }
    if (!validWindow(destination_bounds, request.render_window)) {
        return failed(Error::InvalidRenderWindow);
    }
    if (!isFinite(request.frame_time) || !isFinite(request.render_scale.x) || !isFinite(request.render_scale.y) ||
        request.render_scale.x <= 0.0 || request.render_scale.y <= 0.0) {
        return failed(Error::InvalidFrameTime);
    }
    const Error settings_error = validateSettings(request, *definition);
    if (settings_error != Error::None) {
        return failed(settings_error);
    }
    std::int64_t grain_frame = 0;
    if (request.effect == EffectId::FilmGrain && !grainFrameIndex(request.frame_time, grain_frame)) {
        return failed(Error::InvalidFrameTime);
    }
    const MemoryKind backend_memory = backend.kind() == BackendKind::Cpu ? MemoryKind::Cpu : MemoryKind::Metal;
    if (request.source.memory_kind != backend_memory || request.destination.memory_kind != backend_memory) {
        return failed(Error::BackendUnavailable);
    }
    if (rangeOverlaps(request.source, request.destination)) {
        return failed(Error::AliasedSurfaces);
    }
    const Error external_matte_error = validateExternalMatte(request, backend.kind());
    if (external_matte_error != Error::None) {
        return failed(external_matte_error);
    }
    const detail::CompiledEffectPlan plan = compileEffectPlan(request, diagnosticView(request), grain_frame);
    return backend.submit(request, plan);
}

RenderSubmission CpuRenderBackend::submit(const RenderRequest& request, const detail::CompiledEffectPlan& plan)
{
    if (plan.is_identity) {
        for (int y = request.render_window.y1; y < request.render_window.y2; ++y) {
            for (int x = request.render_window.x1; x < request.render_window.x2; ++x) {
                std::memcpy(destinationPixel(request.destination, x, y), sourcePixel(request.source, x, y), 16U);
            }
        }
        return RenderSubmission{SubmissionKind::Completed, Error::None};
    }

    if (plan.effect == EffectId::Halation) {
        return renderHalationCpu(request, plan);
    }
    if (plan.effect == EffectId::FilmGrain) {
        return renderFilmGrainCpu(request, plan);
    }
    if (plan.effect == EffectId::OpticalBlur) {
        return renderOpticalBlurCpu(request, plan);
    }
    if (plan.effect == EffectId::LensReflections) {
        return renderLensReflectionsCpu(request, plan);
    }
    if (plan.effect == EffectId::MistDiffusion) {
        return renderMistCpu(request, plan);
    }

    return failed(Error::UnsupportedEffectId);
}

}
