#include <array>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string_view>
#include <vector>
#include <algorithm>

#include "cbef/RenderCore.h"

namespace {

using cbef::EffectDefinition;
using cbef::EffectId;
using cbef::ParameterGroup;
using cbef::ParameterRole;
using cbef::Settings;

int fail(const char* message)
{
    std::fprintf(stderr, "inspector_metadata_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) { \
            return fail(message); \
        } \
    } while (false)

const cbef::ParameterDefinition* findParameter(const EffectDefinition& definition, std::string_view id)
{
    for (const cbef::ParameterDefinition& parameter : definition.parameters) {
        if (id == parameter.id) {
            return &parameter;
        }
    }
    return nullptr;
}

int run()
{
    constexpr std::array<EffectId, 5> effects = {
        EffectId::Halation,
        EffectId::FilmGrain,
        EffectId::OpticalBlur,
        EffectId::LensReflections,
        EffectId::MistDiffusion,
    };
    constexpr std::array<const char*, 5> identifiers = {
        "com.cbef.filmeffects.halation",
        "com.cbef.filmeffects.filmgrain",
        "com.cbef.filmeffects.opticalblur",
        "com.cbef.filmeffects.lensreflections",
        "com.cbef.filmeffects.mistdiffusion",
    };

    const auto& definitions = cbef::effectDefinitions();
    CHECK(definitions.size() == effects.size(), "metadata must describe exactly five effects");
    for (std::size_t effect_index = 0; effect_index < effects.size(); ++effect_index) {
        const EffectDefinition& definition = cbef::effectDefinition(effects[effect_index]);
        CHECK(std::strcmp(definition.identifier, identifiers[effect_index]) == 0,
              "stable effect identifiers must remain unchanged");

        const cbef::ParameterDefinition* preset = findParameter(definition, "preset");
        const cbef::ParameterDefinition* working_mode = findParameter(definition, "working_mode");
        const cbef::ParameterDefinition* output_view = findParameter(definition, "output_view");
        const cbef::ParameterDefinition* mix = findParameter(definition, "mix");
        CHECK(preset != nullptr && working_mode != nullptr && output_view != nullptr && mix != nullptr,
              "every effect must expose the common Inspector controls");
        CHECK(preset->group == ParameterGroup::Basic && preset->role == ParameterRole::Preset,
              "Preset must be the first Basic control");
        CHECK(mix->group == ParameterGroup::Basic && mix->role == ParameterRole::Mix,
              "Mix must be in Basic");
        CHECK(working_mode->group == ParameterGroup::Advanced &&
                  working_mode->role == ParameterRole::WorkingMode,
              "Working Mode must be an explicit Advanced control");
        CHECK(output_view->group == ParameterGroup::Diagnostics &&
                  output_view->role == ParameterRole::OutputView,
              "Output View must be in Diagnostics");
        CHECK(definition.presets.size() > 0U && definition.default_preset < definition.presets.size(),
              "each effect must have a valid natural preset");

        std::array<int, 3> group_counts = {0, 0, 0};
        std::array<std::vector<int>, 3> group_orders;
        for (const cbef::ParameterDefinition& parameter : definition.parameters) {
            const std::size_t group = static_cast<std::size_t>(parameter.group);
            CHECK(group < group_orders.size(), "parameter group must be one of Basic, Advanced, Diagnostics");
            group_orders[group].push_back(parameter.display_order);
            ++group_counts[group];
            CHECK(parameter.hint != nullptr && std::strlen(parameter.hint) > 0U,
                  "every control needs a directional hint");
            CHECK(parameter.unit != nullptr && std::strlen(parameter.unit) > 0U,
                  "every control needs a workspace-aware unit");
            CHECK(parameter.minimum <= parameter.maximum && parameter.increment > 0.0,
                  "metadata range and precision must be valid");
            CHECK(parameter.default_value.index() == static_cast<std::size_t>(parameter.type),
                  "typed default must match the parameter type");
        }
        for (std::vector<int>& orders : group_orders) {
            std::sort(orders.begin(), orders.end());
            for (std::size_t index = 1; index < orders.size(); ++index) {
                CHECK(orders[index] > orders[index - 1],
                      "display order must be strictly increasing within each group");
            }
        }
        const int maximum_basic_controls = effects[effect_index] == EffectId::Halation ? 9 : 7;
        CHECK(group_counts[static_cast<std::size_t>(ParameterGroup::Basic)] >= 5 &&
                  group_counts[static_cast<std::size_t>(ParameterGroup::Basic)] <= maximum_basic_controls,
              "Basic must contain Preset, three core controls, and Mix");

        if (effects[effect_index] == EffectId::Halation) {
            const cbef::ParameterDefinition* color_emphasis = findParameter(definition, "color_emphasis");
            const cbef::ParameterDefinition* color_strength = findParameter(definition, "color_strength");
            CHECK(color_emphasis != nullptr && color_strength != nullptr &&
                      color_emphasis->group == ParameterGroup::Basic &&
                      color_strength->group == ParameterGroup::Basic &&
                      color_emphasis->choices.size() == 5U &&
                      std::string_view(color_emphasis->choices[4]) == "Auto (Scene Adaptive)" &&
                      std::get<int>(color_emphasis->default_value) == 0 &&
                      color_emphasis->display_order < color_strength->display_order &&
                      color_strength->display_order < mix->display_order,
                  "Halation Color Emphasis and Color Strength must be easy to reach in Basic before Mix");
        }

        Settings natural = cbef::defaultSettings(effects[effect_index]);
        CHECK(cbef::settingChoice(natural, "preset") == static_cast<int>(definition.default_preset),
              "default settings must select the natural preset");
        const int working_before = cbef::settingChoice(natural, "working_mode");
        const int output_before = cbef::settingChoice(natural, "output_view");
        CHECK(cbef::setSetting(natural, "mix", 37.0), "Mix must be editable through typed settings");
        CHECK(cbef::settingChoice(natural, "working_mode") == working_before &&
                  cbef::settingChoice(natural, "output_view") == output_before,
              "editing a Basic value must preserve Working Mode and Output View");
        const char* controlled_id = effects[effect_index] == EffectId::OpticalBlur ? "blur" :
                                    effects[effect_index] == EffectId::MistDiffusion ? "diffusion" : "amount";
        CHECK(cbef::setSetting(natural, controlled_id,
                               std::get<double>(cbef::settingValue(natural, controlled_id)) + 1.0),
              "effect controls must be editable through typed settings");
        CHECK(cbef::settingChoice(natural, "preset") == static_cast<int>(definition.presets.size()),
              "editing a preset-controlled value must expose Custom");

        const cbef::ParameterDefinition* lens_model = findParameter(definition, "lens_model");
        const cbef::ParameterDefinition* anamorphism = findParameter(definition, "anamorphism");
        if (effects[effect_index] == EffectId::LensReflections) {
            CHECK(lens_model != nullptr && anamorphism != nullptr,
                  "lens metadata must contain model and anamorphism controls");
            CHECK(anamorphism->enabled_when_parameter != nullptr &&
                      std::strcmp(anamorphism->enabled_when_parameter, "lens_model") == 0 &&
                      anamorphism->enabled_when_choice == 2,
                  "anamorphism must activate only for the anamorphic lens profile");
        }
    }
    return 0;
}

}

int main()
{
    return run();
}
