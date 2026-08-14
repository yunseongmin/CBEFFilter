#pragma once

#include "cbef/RenderCore.h"

#include <array>
#include <variant>

namespace cbef::detail {

enum class DiagnosticView : std::uint32_t {
    Final = 0,
    Component = 1,
    Matte = 2,
    FullImage = 3,
    GlobalOnly = 4,
    LocalOnly = 5,
    GlowOnly = 6,
    VeilOnly = 7,
    DetailDifference = 8,
    SourceMap = 9,
    GhostPaths = 10,
    ElementsOnly = 11,
    ElementSolo = 12,
    MatteLimited = 13,
};

enum class GhostElementShape : std::uint8_t {
    Focused = 0,
    Disc = 1,
    Ring = 2,
    Veil = 3,
    Streak = 4,
};

enum class HalationColorMode : std::uint32_t {
    ProfileRelative = 0,
    FixedTarget = 1,
    AutoSceneAdaptive = 2,
};

struct GhostElementPlan {
    float axis_position = 0.0F;
    float magnification = 1.0F;
    float defocus = 0.0F;
    float aperture_clip = 1.0F;
    float ring_profile = 0.0F;
    float radial_falloff = 1.0F;
    std::array<float, 3> spectral_tint{1.0F, 1.0F, 1.0F};
    float dispersion = 0.0F;
    float energy = 0.0F;
    float background_falloff = 1.0F;
    float streak_aspect = 1.0F;
    GhostElementShape shape = GhostElementShape::Disc;
    float pattern_retention = 0.0F;
};

struct HalationEffectPlan {
    float amount;
    float radius;
    float global_diffusion;
    float threshold;
    float warmth;
    float saturation;
    float red_bias;
    float blue_compensation;
    bool highlights_only;
    float source_smoothness;
    float core_protection;
    float background_adaptation;
    float color_target_r;
    float color_target_g;
    float color_target_b;
    float color_emphasis_mix;
    HalationColorMode color_mode;
};
using HalationParameters = HalationEffectPlan;

struct GrainEffectPlan {
    int format;
    float amount;
    float size;
    float softness;
    float chroma;
    float shadow;
    float midtone;
    float highlight;
    std::uint32_t seed;
    std::int64_t frame;
    int stock_response;
    float scan_sampling;
    int processing_modifier;
    float film_resolution;
    float clump;
    float exposure_bias;
};
using GrainParameters = GrainEffectPlan;

struct MistEffectPlan {
    int profile;
    int grade;
    float veil;
    float glow;
    float contrast;
    float detail_retention;
    int mode;
    int density;
    float diffusion;
    float bloom;
    float texture;
    float glow_radius_base;
    float glow_radius_tail;
    float veil_radius_base;
    float veil_radius_tail;
    float glow_energy;
    float veil_energy;
    float veil_contrast;
    float black_retention;
    float detail_fine_sigma;
    float detail_mid_sigma;
    float detail_edge_protection;
    float detail_strength;
};
using MistParameters = MistEffectPlan;

struct OpticalDefocusEffectPlan {
    float blur;
    int blades;
    float curvature;
    float rotation;
    float anamorphism;
    float highlight_response;
    int lens_profile;
    float bokeh_bias;
    float cat_eye;
    float vignetting;
    float coma;
    float astigmatism;
    float field_curvature;
    float chromatic_aberration;
    int quality;
    int sample_count;
};
using OpticalBlurParameters = OpticalDefocusEffectPlan;

struct LensReflectionsEffectPlan {
    float amount;
    float threshold;
    int lens_model;
    float spread;
    float blur;
    float chroma;
    float anamorphism;
    int source_mode;
    int source_metric;
    float source_gamma;
    float source_smoothness;
    float source_morphology;
    float manual_x;
    float manual_y;
    float manual_size;
    float manual_intensity;
    int manual_color;
    float center_x;
    float center_y;
    float background_adaptation;
    float veil;
    int element_solo;
    std::array<GhostElementPlan, 5> elements{};
};
using LensReflectionsParameters = LensReflectionsEffectPlan;

struct CommonPlan {
    WorkingMode working_mode;
    DiagnosticView diagnostic_view;
    float mix;
};

using EffectPlan = std::variant<HalationEffectPlan,
                                GrainEffectPlan,
                                MistEffectPlan,
                                OpticalDefocusEffectPlan,
                                LensReflectionsEffectPlan>;

struct CompiledEffectPlan {
    EffectId effect;
    CommonPlan common;
    EffectPlan effect_plan;
    bool is_identity;

    WorkingMode workingMode() const { return common.working_mode; }
    DiagnosticView diagnosticView() const { return common.diagnostic_view; }
    float mixAmount() const { return common.mix; }
    const HalationEffectPlan& halation() const { return std::get<HalationEffectPlan>(effect_plan); }
    const GrainEffectPlan& grain() const { return std::get<GrainEffectPlan>(effect_plan); }
    const MistEffectPlan& mist() const { return std::get<MistEffectPlan>(effect_plan); }
    const OpticalDefocusEffectPlan& optical() const { return std::get<OpticalDefocusEffectPlan>(effect_plan); }
    const LensReflectionsEffectPlan& reflections() const { return std::get<LensReflectionsEffectPlan>(effect_plan); }
};

}
