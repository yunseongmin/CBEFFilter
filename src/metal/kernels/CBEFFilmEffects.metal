#include <metal_stdlib>
using namespace metal;

struct CopyArguments {
    int data_x;
    int data_y;
    int window_x;
    int window_y;
    int width;
    int height;
    uint source_row_bytes;
    uint destination_row_bytes;
};

struct HalationArguments {
    int data_x;
    int data_y;
    int window_x;
    int window_y;
    int width;
    int height;
    uint source_row_bytes;
    uint destination_row_bytes;
    uint working_mode;
    uint diagnostic_view;
    float mix;
    float amount;
    float radius;
    float threshold;
    float warmth;
    float saturation;
    uint highlights_only;
    uint alpha_association;
    uint render_width;
    uint render_height;
    uint horizontal_radius;
    uint vertical_radius;
    float scale_weight;
    float source_smoothness;
    float global_diffusion;
    float red_bias;
    float blue_compensation;
    float core_protection;
    float background_adaptation;
    uint channel;
    float color_target_r;
    float color_target_g;
    float color_target_b;
    float color_emphasis_mix;
    uint color_mode;
};

struct HalationFusedArguments {
    HalationArguments base;
    uint pair_offsets[3];
    uint pair_counts[3];
    uint vertical_pair_offsets[3];
    uint vertical_pair_counts[3];
    float scale_weights[3];
};

struct HalationPyramidRG32Arguments {
    HalationArguments base;
    uint level_width;
    uint level_height;
    uint downsample;
    uint channel;
    uint source_row_stride;
    uint output_row_stride;
    uint source_plane_stride;
    uint output_plane_stride;
    uint horizontal_pair_offsets[3];
    uint vertical_pair_offsets[3];
    uint horizontal_radii[3];
    uint vertical_radii[3];
};

struct HalationPyramidCompositeArguments {
    HalationArguments base;
    uint downsample[3];
    uint global_branch;
    uint initialize;
};

struct GrainArguments {
    int data_x;
    int data_y;
    int window_x;
    int window_y;
    int width;
    int height;
    int source_height;
    uint source_row_bytes;
    uint destination_row_bytes;
    uint working_mode;
    uint diagnostic_view;
    float mix;
    int format;
    float amount;
    float size;
    float softness;
    float chroma;
    float shadow;
    float midtone;
    float highlight;
    uint seed;
    long frame;
    uint alpha_association;
    uint is_identity;
    int stock_response;
    float scan_sampling;
    int processing_modifier;
    float film_resolution;
    float clump;
    float exposure_bias;
    float grain_scale;
};

struct GrainLatticeGenerateArguments {
    GrainArguments grain;
    int origin_x;
    int origin_y;
    uint width;
    uint height;
    uint octave;
};

struct GrainLatticeBlurArguments {
    uint width;
    uint height;
    uint radius;
    uint vertical;
    float sigma;
};

struct GrainLatticeInfo {
    int origin_x;
    int origin_y;
    uint width;
    uint height;
    float diameter;
};

struct GrainRenderArguments {
    GrainArguments grain;
    GrainLatticeInfo lattices[3];
};

struct MistArguments {
    int data_x;
    int data_y;
    int window_x;
    int window_y;
    int width;
    int height;
    uint source_row_bytes;
    uint destination_row_bytes;
    uint working_mode;
    uint diagnostic_view;
    float mix;
    int mode;
    int density;
    float diffusion;
    float bloom;
    float contrast;
    float texture;
    uint alpha_association;
    uint is_identity;
    uint render_width;
    uint render_height;
    uint horizontal_radius;
    uint vertical_radius;
    float accumulation_weight;
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

struct MistPyramidArguments {
    MistArguments base;
    int source_x;
    int source_y;
    uint source_width;
    uint source_height;
    uint downsample;
    uint output_width;
    uint output_height;
};

struct OpticalArguments {
    int data_x;
    int data_y;
    int window_x;
    int window_y;
    int width;
    int height;
    uint source_row_bytes;
    uint destination_row_bytes;
    uint working_mode;
    uint diagnostic_view;
    float mix;
    float highlight_response;
    uint alpha_association;
    uint tap_count;
    uint render_width;
    uint render_height;
    float blur_radius;
    float anamorphism;
    float bokeh_bias;
    float cat_eye;
    float vignetting;
    float coma;
    float astigmatism;
    float field_curvature;
    float chromatic_aberration;
    uint lens_profile;
    uint half_width;
    uint half_height;
    uint quarter_width;
    uint quarter_height;
    uint eighth_width;
    uint eighth_height;
    uint half_offset;
    uint quarter_offset;
    uint eighth_offset;
    uint downsample_level;
};

struct OpticalPoint {
    float x;
    float y;
    float weight;
    float padding;
};

struct LensV2Arguments {
    int data_x;
    int data_y;
    int window_x;
    int window_y;
    int width;
    int height;
    uint source_row_bytes;
    uint destination_row_bytes;
    uint working_mode;
    uint diagnostic_view;
    float mix;
    float amount;
    float threshold;
    float spread;
    float blur;
    float chroma;
    float anamorphism;
    uint alpha_association;
    uint render_width;
    uint render_height;
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
    uint has_matte;
    uint matte_format;
    uint matte_alpha_association;
    int matte_x;
    int matte_y;
    int matte_width;
    int matte_height;
    uint matte_row_bytes;
    float render_scale_x;
    float render_scale_y;
    uint tile_columns;
    uint tile_rows;
    uint half_width;
    uint half_height;
    uint lens_model;
    uint use_half_source;
    uint projection_downsample;
    uint projection_width;
    uint projection_height;
};

struct LensElementGpu {
    float axis_position;
    float magnification;
    float defocus;
    float aperture_clip;
    float ring_profile;
    float radial_falloff;
    float tint_r;
    float tint_g;
    float tint_b;
    float dispersion;
    float energy;
    float background_falloff;
    float streak_aspect;
    float pattern_retention;
    uint shape;
    uint padding;
};

struct LensTileStats {
    float energy;
    float weighted_x;
    float weighted_y;
    float weighted_x2;
    float weighted_y2;
    float red;
    float green;
    float blue;
};

struct LensTilePair {
    LensTileStats before;
    LensTileStats limited;
};

struct LensCandidate {
    float x;
    float y;
    float radius;
    float energy;
    float red;
    float green;
    float blue;
    uint valid;
};

struct GaussianPair {
    float weight;
    float offset;
};

struct ClearArguments {
    uint width;
    uint height;
};

constexpr sampler cbef_linear_sampler(coord::pixel, address::clamp_to_edge, filter::linear);

float decode_dwg(float value) {
    return value > 0.02740668f ? exp2(value / 0.07329248f - 7.0f) - 0.0075f : value / 10.44426855f;
}

float encode_dwg(float value) {
    return value > 0.00262409f ? (log2(value + 0.0075f) + 7.0f) * 0.07329248f : value * 10.44426855f;
}

float signed_power(float value, float exponent) {
    return copysign(pow(fabs(value), exponent), value);
}

float3 to_dwg(float3 value, uint mode) {
    if (mode == 0u) {
        return float3(decode_dwg(value.r), decode_dwg(value.g), decode_dwg(value.b));
    }
    if (mode == 1u) {
        return value;
    }
    const float3 linear = float3(signed_power(value.r, 2.4f), signed_power(value.g, 2.4f),
                                 signed_power(value.b, 2.4f));
    const float x = 0.41239080f * linear.r + 0.35758434f * linear.g + 0.18048079f * linear.b;
    const float y = 0.21263901f * linear.r + 0.71516868f * linear.g + 0.07219232f * linear.b;
    const float z = 0.01933082f * linear.r + 0.11919478f * linear.g + 0.95053215f * linear.b;
    return float3(1.51667204f * x - 0.28147805f * y - 0.14696363f * z,
                  -0.46491710f * x + 1.25142378f * y + 0.17488461f * z,
                  0.06484905f * x + 0.10913934f * y + 0.76141462f * z);
}

float3 from_dwg(float3 value, uint mode) {
    if (mode == 0u) {
        return float3(encode_dwg(value.r), encode_dwg(value.g), encode_dwg(value.b));
    }
    if (mode == 1u) {
        return value;
    }
    const float x = 0.70062239f * value.r + 0.14877482f * value.g + 0.10105872f * value.b;
    const float y = 0.27411851f * value.r + 0.87363190f * value.g - 0.14775041f * value.b;
    const float z = -0.09896291f * value.r - 0.13789533f * value.g + 1.32591599f * value.b;
    const float red = 3.24096994f * x - 1.53738318f * y - 0.49861076f * z;
    const float green = -0.96924364f * x + 1.87596750f * y + 0.04155506f * z;
    const float blue = 0.05563008f * x - 0.20397696f * y + 1.05697151f * z;
    return float3(signed_power(red, 1.0f / 2.4f), signed_power(green, 1.0f / 2.4f),
                  signed_power(blue, 1.0f / 2.4f));
}

float luminance(float3 value) {
    const float3 positive = max(value, float3(0.0f));
    return max(0.0f, 0.27411851f * positive.r + 0.87363190f * positive.g - 0.14775041f * positive.b);
}

constant float grain_diameters[4] = {1.80f, 1.10f, 1.40f, 0.80f};
constant float grain_octave_weights[3] = {0.65f, 0.25f, 0.10f};
constant float grain_octave_rms = 0.703562363974f;
constant float grain_capture_diameters[5] = {1.80f, 1.10f, 1.35f, 0.80f, 2.45f};
constant float grain_stock_rms[3] = {1.05f, 1.12f, 1.24f};
constant float grain_record_diameter[3][3] = {{1.00f, 1.00f, 1.00f},
                                                {1.00f, 1.00f, 1.00f},
                                                {1.08f, 1.00f, 0.94f}};
constant float grain_record_mtf[3][3] = {{0.85f, 1.00f, 1.15f},
                                           {0.97f, 1.00f, 1.03f},
                                           {1.08f, 1.00f, 0.94f}};
constant float grain_record_rho[3][3] = {{0.982f, 0.990f, 0.970f},
                                           {0.995f, 0.992f, 0.990f},
                                           {0.965f, 0.975f, 0.990f}};
constant float grain_population_weights[3][3] = {{0.56f, 0.30f, 0.14f},
                                                   {0.66f, 0.25f, 0.09f},
                                                   {0.42f, 0.32f, 0.26f}};

uint philox_word(int ix, int iy, long frame, uint seed, int layer, int octave, int channel, int block, int lane) {
    const ulong frame_bits = as_type<ulong>(frame);
    uint c0 = as_type<uint>(ix);
    uint c1 = as_type<uint>(iy);
    uint c2 = (uint)frame_bits;
    uint c3 = ((uint)layer << 24u) | ((uint)octave << 16u) | ((uint)channel << 8u) | (uint)block;
    uint k0 = seed;
    uint k1 = 0xCBEF2026u ^ (uint)(frame_bits >> 32u);
    for (int round = 0; round < 10; ++round) {
        const ulong product0 = (ulong)0xD2511F53u * (ulong)c0;
        const ulong product1 = (ulong)0xCD9E8D57u * (ulong)c2;
        const uint next_c0 = (uint)(product1 >> 32u) ^ c1 ^ k0;
        const uint next_c1 = (uint)product1;
        const uint next_c2 = (uint)(product0 >> 32u) ^ c3 ^ k1;
        const uint next_c3 = (uint)product0;
        c0 = next_c0;
        c1 = next_c1;
        c2 = next_c2;
        c3 = next_c3;
        if (round != 9) {
            k0 += 0x9E3779B9u;
            k1 += 0xBB67AE85u;
        }
    }
    return lane == 0 ? c0 : lane == 1 ? c1 : lane == 2 ? c2 : c3;
}

uint4 philox_words(int ix, int iy, long frame, uint seed, int layer, int octave, int channel, int block) {
    const ulong frame_bits = as_type<ulong>(frame);
    uint c0 = as_type<uint>(ix);
    uint c1 = as_type<uint>(iy);
    uint c2 = (uint)frame_bits;
    uint c3 = ((uint)layer << 24u) | ((uint)octave << 16u) | ((uint)channel << 8u) | (uint)block;
    uint k0 = seed;
    uint k1 = 0xCBEF2026u ^ (uint)(frame_bits >> 32u);
    for (int round = 0; round < 10; ++round) {
        const ulong product0 = (ulong)0xD2511F53u * (ulong)c0;
        const ulong product1 = (ulong)0xCD9E8D57u * (ulong)c2;
        const uint next_c0 = (uint)(product1 >> 32u) ^ c1 ^ k0;
        const uint next_c1 = (uint)product1;
        const uint next_c2 = (uint)(product0 >> 32u) ^ c3 ^ k1;
        const uint next_c3 = (uint)product0;
        c0 = next_c0;
        c1 = next_c1;
        c2 = next_c2;
        c3 = next_c3;
        if (round != 9) {
            k0 += 0x9E3779B9u;
            k1 += 0xBB67AE85u;
        }
    }
    return uint4(c0, c1, c2, c3);
}

float4 lattice_gaussian4(int ix, int iy, long frame, uint seed, int octave) {
    float4 sum = float4(0.0f);
    for (int block = 0; block < 3; ++block) {
        const uint4 shared_words = philox_words(ix, iy, frame, seed, 0, octave, 0, block);
        const uint4 red_words = philox_words(ix, iy, frame, seed, 1, octave, 1, block);
        const uint4 green_words = philox_words(ix, iy, frame, seed, 1, octave, 2, block);
        const uint4 blue_words = philox_words(ix, iy, frame, seed, 1, octave, 3, block);
        sum.x += ((float)shared_words.x + 0.5f) / 4294967296.0f;
        sum.x += ((float)shared_words.y + 0.5f) / 4294967296.0f;
        sum.x += ((float)shared_words.z + 0.5f) / 4294967296.0f;
        sum.x += ((float)shared_words.w + 0.5f) / 4294967296.0f;
        sum.y += ((float)red_words.x + 0.5f) / 4294967296.0f;
        sum.y += ((float)red_words.y + 0.5f) / 4294967296.0f;
        sum.y += ((float)red_words.z + 0.5f) / 4294967296.0f;
        sum.y += ((float)red_words.w + 0.5f) / 4294967296.0f;
        sum.z += ((float)green_words.x + 0.5f) / 4294967296.0f;
        sum.z += ((float)green_words.y + 0.5f) / 4294967296.0f;
        sum.z += ((float)green_words.z + 0.5f) / 4294967296.0f;
        sum.z += ((float)green_words.w + 0.5f) / 4294967296.0f;
        sum.w += ((float)blue_words.x + 0.5f) / 4294967296.0f;
        sum.w += ((float)blue_words.y + 0.5f) / 4294967296.0f;
        sum.w += ((float)blue_words.z + 0.5f) / 4294967296.0f;
        sum.w += ((float)blue_words.w + 0.5f) / 4294967296.0f;
    }
    return sum - float4(6.0f);
}

float lattice_gaussian(int ix, int iy, constant GrainArguments& arguments, int layer, int octave, int channel) {
    float sum = 0.0f;
    for (int block = 0; block < 3; ++block) {
        for (int lane = 0; lane < 4; ++lane) {
            const uint word = philox_word(ix, iy, arguments.frame, arguments.seed, layer, octave, channel,
                                          block, lane);
            sum += ((float)word + 0.5f) / 4294967296.0f;
        }
    }
    return sum - 6.0f;
}

float softened_lattice_gaussian(int ix, int iy, float sigma, constant GrainArguments& arguments,
                                int layer, int octave, int channel) {
    const float basis_sigma = 1.0f;
    const float sigma_squared = basis_sigma * basis_sigma;
    float weighted = 0.0f;
    float coefficient_squared = 0.0f;
    for (int dy = -4; dy <= 4; ++dy) {
        for (int dx = -4; dx <= 4; ++dx) {
            const float distance_squared = (float)(dx * dx + dy * dy);
            const float coefficient = exp(-0.5f * distance_squared / sigma_squared);
            weighted += coefficient * lattice_gaussian(ix + dx, iy + dy, arguments, layer, octave, channel);
            coefficient_squared += coefficient * coefficient;
        }
    }
    return weighted / sqrt(coefficient_squared);
}

float grain_field(float u, float v, float diameter, float softness, constant GrainArguments& arguments,
                  int layer, int octave, int channel) {
    const float lattice_x = u / diameter;
    const float lattice_y = v / diameter;
    const int ix = (int)floor(lattice_x);
    const int iy = (int)floor(lattice_y);
    const float tx = lattice_x - (float)ix;
    const float ty = lattice_y - (float)iy;
    const float hx = tx * tx * (3.0f - 2.0f * tx);
    const float hy = ty * ty * (3.0f - 2.0f * ty);
    const float sigma = 0.75f * (softness / 100.0f) * diameter;
    const float weights[4] = {(1.0f - hx) * (1.0f - hy), hx * (1.0f - hy),
                              (1.0f - hx) * hy, hx * hy};
    const float values[4] = {
        softened_lattice_gaussian(ix, iy, sigma, arguments, layer, octave, channel),
        softened_lattice_gaussian(ix + 1, iy, sigma, arguments, layer, octave, channel),
        softened_lattice_gaussian(ix, iy + 1, sigma, arguments, layer, octave, channel),
        softened_lattice_gaussian(ix + 1, iy + 1, sigma, arguments, layer, octave, channel),
    };
    float value = 0.0f;
    float coefficient_squared = 0.0f;
    for (int index = 0; index < 4; ++index) {
        value += weights[index] * values[index];
        coefficient_squared += weights[index] * weights[index];
    }
    return coefficient_squared > 1.0e-12f ? value / sqrt(coefficient_squared) : 0.0f;
}

float grain_channel_field(float x, float y, int channel, constant GrainArguments& arguments) {
    const int format = clamp(arguments.format, 0, 3);
    const float scaled_diameter = grain_diameters[format] * (arguments.size / 100.0f);
    const float q = arguments.chroma / 100.0f;
    float value = 0.0f;
    for (int octave = 0; octave < 3; ++octave) {
        const float diameter = scaled_diameter * (float)(1 << octave);
        const float shared_value = grain_field(x, y, diameter, arguments.softness, arguments, 0, octave, 0);
        const float independent_value = grain_field(x, y, diameter, arguments.softness, arguments, 1, octave,
                                                    channel + 1);
        const float correlated = sqrt(1.0f - q) * shared_value + sqrt(q) * independent_value;
        value += grain_octave_weights[octave] * correlated;
    }
    return value / grain_octave_rms;
}

struct GrainPopulationProfile {
    float fine;
    float medium;
    float coarse;
    float diameter_scale;
    float asymmetry;
};

GrainPopulationProfile grain_population_profile(float exposure, float clump, int stock) {
    const int index = clamp(stock, 0, 2);
    const float normalized_clump = clamp(clump / 100.0f, 0.0f, 1.0f);
    const float shadow_bias = clamp(-exposure / 6.0f, -0.5f, 0.5f);
    float fine = grain_population_weights[index][0] - 0.10f * shadow_bias;
    float medium = grain_population_weights[index][1];
    float coarse = grain_population_weights[index][2] + 0.10f * shadow_bias + 0.34f * normalized_clump;
    fine = max(0.04f, fine - 0.14f * normalized_clump);
    medium = max(0.04f, medium - 0.20f * normalized_clump);
    const float total = fine + medium + coarse;
    return GrainPopulationProfile{fine / total, medium / total, coarse / total,
                                  1.0f + 0.045f * clamp(-exposure, -4.0f, 4.0f),
                                  0.015f + 0.040f * normalized_clump};
}

float grain_population_field(float x, float y, float diameter, float softness, constant GrainArguments& arguments,
                             GrainPopulationProfile profile, float record_mtf, int layer, int octave, int channel) {
    const float population_diameter = diameter;
    constexpr float kCos22 = 0.9238795325f;
    constexpr float kSin22 = 0.3826834324f;
    const float rotated_x = kCos22 * x + kSin22 * y;
    const float rotated_y = -kSin22 * x + kCos22 * y;
    const float field = grain_field(rotated_x, rotated_y, population_diameter, clamp(softness, 0.0f, 100.0f),
                                     arguments, layer, octave, channel);
    const float mtf_gain = 0.70f + 0.30f * clamp(record_mtf, 0.0f, 1.3f);
    const float softness_gain = 0.70f + 0.20f * clamp(softness / 100.0f, 0.0f, 1.0f);
    return softness_gain * mtf_gain * (field + profile.asymmetry * 0.60f * (field * field - 1.0f));
}

float grain_channel_field_v2(float x, float y, int format, float display_scale, float softness, int channel,
                             float exposure, constant GrainArguments& arguments) {
    const int stock = clamp(arguments.stock_response, 0, 2);
    const int capture = clamp(format, 0, 4);
    const float base_diameter = grain_capture_diameters[capture];
    const float record_diameter = grain_record_diameter[stock][clamp(channel, 0, 2)];
    const float resolution = clamp(arguments.film_resolution / 100.0f, 0.0f, 1.0f);
    const float record_mtf = grain_record_mtf[stock][clamp(channel, 0, 2)] * (0.72f + 0.28f * resolution);
    const float scaled_diameter = base_diameter * record_diameter * (display_scale / 100.0f);
    const GrainPopulationProfile profile = grain_population_profile(exposure, arguments.clump, stock);
    const float q = clamp(arguments.chroma / 100.0f, 0.0f, 1.0f);
    const float rho_rg = grain_record_rho[stock][0] * (1.0f - q);
    const float rho_rb = grain_record_rho[stock][1] * (1.0f - q);
    const float rho_gb = grain_record_rho[stock][2] * (1.0f - q);
    const float l11 = sqrt(max(1.0f - rho_rg * rho_rg, 1.0e-5f));
    const float l21 = (rho_gb - rho_rg * rho_rb) / l11;
    const float l22 = sqrt(max(1.0f - rho_rb * rho_rb - l21 * l21, 1.0e-5f));
    float value = 0.0f;
    for (int octave = 0; octave < 3; ++octave) {
        const float diameter = scaled_diameter * (float)(1 << octave);
        const float shared = grain_population_field(x, y, diameter, softness, arguments, profile, record_mtf,
                                                    0, octave, 0);
        const float independent_g = grain_population_field(x, y, diameter, softness, arguments, profile, record_mtf,
                                                            1, octave, 1);
        const float independent_b = grain_population_field(x, y, diameter, softness, arguments, profile, record_mtf,
                                                            1, octave, 2);
        const float correlated = channel == 0 ? shared
                               : channel == 1 ? rho_rg * shared + l11 * independent_g
                                              : rho_rb * shared + l21 * independent_g + l22 * independent_b;
        value += grain_octave_weights[octave] * correlated;
    }
    return value / grain_octave_rms;
}

float grain_smoothstep(float lower, float upper, float value) {
    if (value <= lower) return 0.0f;
    if (value >= upper) return 1.0f;
    const float t = (value - lower) / (upper - lower);
    return t * t * (3.0f - 2.0f * t);
}

float mist_smoothstep(float lower, float upper, float value) {
    if (value <= lower) return 0.0f;
    if (value >= upper) return 1.0f;
    const float t = (value - lower) / (upper - lower);
    return t * t * (3.0f - 2.0f * t);
}

kernel void cbef_grain_lattice_generate(device float4* lattice [[buffer(0)]],
                                         constant GrainLatticeGenerateArguments& layout [[buffer(1)]],
                                         uint2 position [[thread_position_in_grid]]) {
    if (position.x >= layout.width || position.y >= layout.height) return;
    const int ix = layout.origin_x + (int)position.x;
    const int iy = layout.origin_y + (int)position.y;
    lattice[position.y * layout.width + position.x] =
        lattice_gaussian4(ix, iy, layout.grain.frame, layout.grain.seed, (int)layout.octave);
}

kernel void cbef_grain_lattice_blur(device const float4* input [[buffer(0)]],
                                    device float4* output [[buffer(1)]],
                                    constant GrainLatticeBlurArguments& arguments [[buffer(2)]],
                                    uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.width || position.y >= arguments.height) return;
    const int radius = (int)arguments.radius;
    float4 weighted = float4(0.0f);
    float coefficient_squared = 0.0f;
    const float sigma_squared = arguments.sigma * arguments.sigma;
    for (int offset = -radius; offset <= radius; ++offset) {
        const float distance_squared = (float)(offset * offset);
        const float coefficient = arguments.radius == 0u || sigma_squared <= 1.0e-8f
                                      ? 1.0f
                                      : exp(-0.5f * distance_squared / sigma_squared);
        const int sample_x = arguments.vertical == 0u
                                 ? clamp((int)position.x + offset, 0, (int)arguments.width - 1)
                                 : (int)position.x;
        const int sample_y = arguments.vertical == 0u
                                 ? (int)position.y
                                 : clamp((int)position.y + offset, 0, (int)arguments.height - 1);
        const uint2 sample_position = uint2((uint)sample_x, (uint)sample_y);
        weighted += coefficient * input[sample_position.y * arguments.width + sample_position.x];
        coefficient_squared += coefficient * coefficient;
    }
    output[position.y * arguments.width + position.x] =
        weighted / sqrt(max(coefficient_squared, 1.0e-20f));
}

float4 grain_lattice_sample(device const float4* lattice, constant GrainLatticeInfo& info, float u, float v) {
    const float lattice_x = u / info.diameter;
    const float lattice_y = v / info.diameter;
    const int ix = (int)floor(lattice_x);
    const int iy = (int)floor(lattice_y);
    const float tx = lattice_x - (float)ix;
    const float ty = lattice_y - (float)iy;
    const float hx = tx * tx * (3.0f - 2.0f * tx);
    const float hy = ty * ty * (3.0f - 2.0f * ty);
    const float weights[4] = {(1.0f - hx) * (1.0f - hy), hx * (1.0f - hy),
                              (1.0f - hx) * hy, hx * hy};
    const int local_x = ix - info.origin_x;
    const int local_y = iy - info.origin_y;
    const uint row = info.width;
    const float4 values[4] = {
        lattice[(uint)local_y * row + (uint)local_x],
        lattice[(uint)local_y * row + (uint)(local_x + 1)],
        lattice[(uint)(local_y + 1) * row + (uint)local_x],
        lattice[(uint)(local_y + 1) * row + (uint)(local_x + 1)],
    };
    float4 value = float4(0.0f);
    float coefficient_squared = 0.0f;
    for (int index = 0; index < 4; ++index) {
        value += weights[index] * values[index];
        coefficient_squared += weights[index] * weights[index];
    }
    return coefficient_squared > 1.0e-12f ? value / sqrt(coefficient_squared) : float4(0.0f);
}

float grain_channel_field_lattice(float x, float y, int channel, float exposure, constant GrainRenderArguments& arguments,
                                  device const float4* octave0, device const float4* octave1,
                                  device const float4* octave2) {
    const GrainArguments grain = arguments.grain;
    const int stock = clamp(grain.stock_response, 0, 2);
    const float q = clamp(grain.chroma / 100.0f, 0.0f, 1.0f);
    const float rho_rg = grain_record_rho[stock][0] * (1.0f - q);
    const float rho_rb = grain_record_rho[stock][1] * (1.0f - q);
    const float rho_gb = grain_record_rho[stock][2] * (1.0f - q);
    const float l11 = sqrt(max(1.0f - rho_rg * rho_rg, 1.0e-5f));
    const float l21 = (rho_gb - rho_rg * rho_rb) / l11;
    const float l22 = sqrt(max(1.0f - rho_rb * rho_rb - l21 * l21, 1.0e-5f));
    constexpr float kCos22 = 0.9238795325f;
    constexpr float kSin22 = 0.3826834324f;
    const float rotated_x = kCos22 * x + kSin22 * y;
    const float rotated_y = -kSin22 * x + kCos22 * y;
    const float record_diameter = grain_record_diameter[stock][clamp(channel, 0, 2)];
    // The CPU reference applies record diameter once before the octave's
    // capture/display diameter. Population/profile sizing is a response
    // shaping term, not a second spatial coordinate transform.
    const float coordinate_scale = record_diameter;
    const float4 values0 = grain_lattice_sample(octave0, arguments.lattices[0], rotated_x / coordinate_scale, rotated_y / coordinate_scale);
    const float4 values1 = grain_lattice_sample(octave1, arguments.lattices[1], rotated_x / coordinate_scale, rotated_y / coordinate_scale);
    const float4 values2 = grain_lattice_sample(octave2, arguments.lattices[2], rotated_x / coordinate_scale, rotated_y / coordinate_scale);
    const float4 values[3] = {values0, values1, values2};
    const float mtf = grain_record_mtf[stock][clamp(channel, 0, 2)] *
                      (0.72f + 0.28f * clamp(grain.film_resolution / 100.0f, 0.0f, 1.0f));
    const float softness_gain = 0.70f + 0.20f * clamp(grain.softness / 100.0f, 0.0f, 1.0f);
    const float field_gain = softness_gain * (0.70f + 0.30f * clamp(mtf, 0.0f, 1.3f));
    float value = 0.0f;
    const float asymmetry = 0.015f + 0.040f * clamp(grain.clump / 100.0f, 0.0f, 1.0f);
    for (int octave = 0; octave < 3; ++octave) {
        const float shared_raw = values[octave].x;
        const float independent_g_raw = values[octave].y;
        const float independent_b_raw = values[octave].z;
        const float shared_value = field_gain * (shared_raw + asymmetry * 0.60f * (shared_raw * shared_raw - 1.0f));
        const float independent_g = field_gain *
                                    (independent_g_raw + asymmetry * 0.60f * (independent_g_raw * independent_g_raw - 1.0f));
        const float independent_b = field_gain *
                                    (independent_b_raw + asymmetry * 0.60f * (independent_b_raw * independent_b_raw - 1.0f));
        const float correlated = channel == 0 ? shared_value
                               : channel == 1 ? rho_rg * shared_value + l11 * independent_g
                                              : rho_rb * shared_value + l21 * independent_g + l22 * independent_b;
        value += grain_octave_weights[octave] * correlated;
    }
    return value / grain_octave_rms;
}

kernel void cbef_grain_final(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                             device const float4* octave0 [[buffer(2)]],
                             device const float4* octave1 [[buffer(3)]],
                             device const float4* octave2 [[buffer(4)]],
                             constant GrainRenderArguments& arguments [[buffer(5)]],
                             uint2 position [[thread_position_in_grid]]) {
    const GrainArguments grain = arguments.grain;
    if (position.x >= uint(grain.width) || position.y >= uint(grain.height)) return;
    const int x = grain.window_x + (int)position.x;
    const int y = grain.window_y + (int)position.y;
    const uint source_word = (uint(y - grain.data_y) * grain.source_row_bytes +
                              uint(x - grain.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - grain.data_y) * grain.destination_row_bytes +
                                   uint(x - grain.data_x) * 16u) / 4u;
    if (grain.is_identity != 0u) {
        destination[destination_word + 0u] = source[source_word + 0u];
        destination[destination_word + 1u] = source[source_word + 1u];
        destination[destination_word + 2u] = source[source_word + 2u];
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]),
                            as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (grain.alpha_association == 1u) encoded /= alpha;
    const float3 original = to_dwg(encoded, grain.working_mode);
    const float3 positive_source = max(original, float3(0.0f));
    const float analysis_luminance = luminance(original);
    const float exposure = log2(max(analysis_luminance, 0x1p-16f) / 0.18f) + grain.exposure_bias;
    const float shadow_response = 1.0f - grain_smoothstep(-5.0f, -1.0f, exposure);
    const float highlight_response = grain_smoothstep(1.0f, 5.0f, exposure);
    const float midtone_response = max(0.0f, 1.0f - max(shadow_response, highlight_response));
    const float response = (grain.shadow * shadow_response + grain.midtone * midtone_response +
                            grain.highlight * highlight_response) / 100.0f;
    const float stock_rms = grain_stock_rms[clamp(grain.stock_response, 0, 2)];
    const float processing_gain = grain.processing_modifier == 1 ? 1.12f : grain.processing_modifier == 2 ? 0.88f : 1.0f;
    const float sigma_stop = 0.08f * (grain.amount / 100.0f) * stock_rms * processing_gain * response;
    const float scale = grain.grain_scale;
    const float grain_x = ((float)(x - grain.data_x) + 0.5f) * scale;
    const float grain_y = ((float)(y - grain.data_y) + 0.5f) * scale;
    float3 component = float3(0.0f);
    for (int channel = 0; channel < 3; ++channel) {
        const float field = grain_channel_field_lattice(grain_x, grain_y, channel, exposure, arguments, octave0, octave1,
                                                         octave2);
        const float correlated = sigma_stop * field;
        const float source_value = positive_source[channel];
        component[channel] = source_value > 0.0f ? source_value * exp2(correlated) - source_value : 0.0f;
    }
    float3 result = original;
    if (grain.diagnostic_view == 0u) {
        result = original + component * grain.mix;
    } else if (grain.diagnostic_view == 1u) {
        result = component;
    } else {
        result = float3(clamp(response / 2.0f, 0.0f, 1.0f));
    }
    float3 output = from_dwg(result, grain.working_mode);
    if (grain.alpha_association == 1u) output *= alpha;
        destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}

kernel void cbef_mist_copy(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                           constant MistArguments& arguments [[buffer(2)]],
                           uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.render_width) || position.y >= uint(arguments.render_height)) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes +
                              uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.data_y) * arguments.destination_row_bytes +
                                   uint(x - arguments.data_x) * 16u) / 4u;
    destination[destination_word + 0u] = source[source_word + 0u];
    destination[destination_word + 1u] = source[source_word + 1u];
    destination[destination_word + 2u] = source[source_word + 2u];
    destination[destination_word + 3u] = source[source_word + 3u];
}

kernel void cbef_clear_float4(device float4* destination [[buffer(0)]],
                              constant ClearArguments& arguments [[buffer(1)]],
                              uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.width || position.y >= arguments.height) return;
    destination[position.y * arguments.width + position.x] = float4(0.0f);
}

kernel void cbef_mist_prepare(const device uint* source [[buffer(0)]], device float4* positive [[buffer(1)]],
                              device float4* highlighted [[buffer(2)]], constant MistArguments& arguments [[buffer(3)]],
                              uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const uint source_word = (position.y * arguments.source_row_bytes + position.x * 16u) / 4u;
    const uint index = position.y * uint(arguments.width) + position.x;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        positive[index] = float4(0.0f);
        highlighted[index] = float4(0.0f);
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    const float3 original = to_dwg(encoded, arguments.working_mode);
    const float3 value = max(original, float3(0.0f));
    const float matte = mist_smoothstep(1.0f, 3.0f,
                                        log2(max(luminance(original), 0x1p-16f) / 0.18f));
    const float stored_alpha = max(0.0f, alpha);
    const float3 stored_positive = arguments.is_identity != 0u ? value * stored_alpha : value;
    const float3 stored_highlighted = arguments.is_identity != 0u ? value * matte * stored_alpha : value * matte;
    positive[index] = float4(stored_positive, stored_alpha);
    highlighted[index] = float4(stored_highlighted, stored_alpha);
}

kernel void cbef_mist_prepare_pyramid(const device uint* source [[buffer(0)]], device float4* positive [[buffer(1)]],
                                      device float4* highlighted [[buffer(2)]], constant MistPyramidArguments& arguments [[buffer(3)]],
                                      uint2 position [[thread_position_in_grid]]) {
    const MistArguments base = arguments.base;
    if (position.x >= uint(base.width) || position.y >= uint(base.height)) return;
    const uint ds = max(arguments.downsample, 1u);
    float3 weighted = float3(0.0f);
    float3 highlighted_weighted = float3(0.0f);
    float alpha_sum = 0.0f;
    const uint start_x = min(position.x * ds, arguments.source_width - 1u);
    const uint start_y = min(position.y * ds, arguments.source_height - 1u);
    for (uint oy = 0u; oy < ds && start_y + oy < arguments.source_height; ++oy) {
        for (uint ox = 0u; ox < ds && start_x + ox < arguments.source_width; ++ox) {
            const uint source_word = ((start_y + oy) * base.source_row_bytes + (start_x + ox) * 16u) / 4u;
            const float alpha = as_type<float>(source[source_word + 3u]);
            if (alpha <= 1.0e-6f) continue;
            float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                                    as_type<float>(source[source_word + 2u]));
            if (base.alpha_association == 1u) encoded /= alpha;
            const float3 original = to_dwg(encoded, base.working_mode);
            const float3 value = max(original, float3(0.0f));
            const float matte = mist_smoothstep(1.0f, 3.0f,
                                                log2(max(luminance(original), 0x1p-16f) / 0.18f));
            weighted += value * alpha;
            highlighted_weighted += value * matte * alpha;
            alpha_sum += alpha;
        }
    }
    const uint index = position.y * uint(base.width) + position.x;
    const float3 value = alpha_sum > 0.0f ? weighted / alpha_sum : float3(0.0f);
    const float3 glow = alpha_sum > 0.0f ? highlighted_weighted / alpha_sum : float3(0.0f);
    positive[index] = float4(value, min(alpha_sum / float(ds * ds), 1.0f));
    highlighted[index] = float4(glow, min(alpha_sum / float(ds * ds), 1.0f));
}

kernel void cbef_mist_horizontal(const device float4* source [[buffer(0)]], device float4* destination [[buffer(1)]],
                                 const device float* weights [[buffer(2)]], constant MistArguments& arguments [[buffer(3)]],
                                 uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const int radius = int(arguments.horizontal_radius);
    float4 value = float4(0.0f);
    for (int tap = -radius; tap <= radius; ++tap) {
        const int sample_x = clamp(int(position.x) + tap, 0, arguments.width - 1);
        const float4 input = source[position.y * uint(arguments.width) + uint(sample_x)];
        const float weight = weights[uint(tap + radius)];
        value.rgb += input.rgb * input.a * weight;
        value.a += input.a * weight;
    }
    destination[position.y * uint(arguments.width) + position.x] = value;
}

kernel void cbef_mist_horizontal_linear(texture2d<float, access::sample> source [[texture(0)]],
                                         device float4* destination [[buffer(0)]],
                                         const device GaussianPair* pairs [[buffer(1)]],
                                         constant MistArguments& arguments [[buffer(2)]],
                                         uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const uint width = uint(arguments.width);
    const float2 center = float2(position) + 0.5f;
    const GaussianPair center_pair = pairs[0u];
    const float4 center_value = source.sample(cbef_linear_sampler, center);
    float4 value = float4(center_value.rgb * center_pair.weight,
                          center_value.a * center_pair.weight);
    const uint pair_count = (arguments.horizontal_radius + 1u) / 2u;
    for (uint pair_index = 0u; pair_index < pair_count; ++pair_index) {
        const GaussianPair pair = pairs[pair_index + 1u];
        const float4 positive = source.sample(cbef_linear_sampler, center + float2(pair.offset, 0.0f));
        const float4 negative = source.sample(cbef_linear_sampler, center - float2(pair.offset, 0.0f));
        value.rgb += (positive.rgb + negative.rgb) * pair.weight;
        value.a += (positive.a + negative.a) * pair.weight;
    }
    destination[position.y * width + position.x] = value;
}

kernel void cbef_mist_vertical(const device float4* source [[buffer(0)]], device float4* destination [[buffer(1)]],
                               const device float* weights [[buffer(2)]], constant MistArguments& arguments [[buffer(3)]],
                               uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const int radius = int(arguments.vertical_radius);
    float3 weighted = float3(0.0f);
    float alpha_weight = 0.0f;
    for (int tap = -radius; tap <= radius; ++tap) {
        const int sample_y = clamp(y - arguments.data_y + tap, 0, arguments.height - 1);
        const float4 input = source[uint(sample_y) * uint(arguments.width) + uint(x - arguments.data_x)];
        const float weight = weights[uint(tap + radius)];
        weighted += input.rgb * weight;
        alpha_weight += input.a * weight;
    }
    const uint index = position.y * arguments.render_width + position.x;
    const float3 blurred = alpha_weight > 0.0f ? weighted / alpha_weight : float3(0.0f);
    destination[index].rgb += blurred * arguments.accumulation_weight;
    destination[index].a = 0.0f;
}

kernel void cbef_mist_vertical_linear(texture2d<float, access::sample> source [[texture(0)]],
                                       device float4* destination [[buffer(0)]],
                                       const device GaussianPair* pairs [[buffer(1)]],
                                       constant MistArguments& arguments [[buffer(2)]],
                                       uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const float2 center = float2(x - arguments.data_x, y - arguments.data_y) + 0.5f;
    const GaussianPair center_pair = pairs[0u];
    const float4 center_value = source.sample(cbef_linear_sampler, center);
    float3 weighted = center_value.rgb * center_pair.weight;
    float alpha_weight = center_value.a * center_pair.weight;
    const uint pair_count = (arguments.vertical_radius + 1u) / 2u;
    for (uint pair_index = 0u; pair_index < pair_count; ++pair_index) {
        const GaussianPair pair = pairs[pair_index + 1u];
        const float4 positive = source.sample(cbef_linear_sampler, center + float2(0.0f, pair.offset));
        const float4 negative = source.sample(cbef_linear_sampler, center - float2(0.0f, pair.offset));
        weighted += (positive.rgb + negative.rgb) * pair.weight;
        alpha_weight += (positive.a + negative.a) * pair.weight;
    }
    const uint index = position.y * arguments.render_width + position.x;
    const float3 blurred = alpha_weight > 0.0f ? weighted / alpha_weight : float3(0.0f);
    destination[index].rgb += blurred * arguments.accumulation_weight;
    destination[index].a = 0.0f;
}

kernel void cbef_mist_finalize(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                               const device float4* positive [[buffer(2)]], const device float4* diffusion [[buffer(3)]],
                               const device float4* bloom [[buffer(4)]], const device float4* detail_fine [[buffer(5)]],
                               const device float4* detail_mid [[buffer(6)]], constant MistArguments& arguments [[buffer(7)]],
                               uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes +
                              uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.data_y) * arguments.destination_row_bytes +
                                   uint(x - arguments.data_x) * 16u) / 4u;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    const float3 original = to_dwg(encoded, arguments.working_mode);
    const float3 original_positive = max(original, float3(0.0f));
    const uint index = position.y * arguments.render_width + position.x;
    float3 source_positive = positive[uint(y - arguments.data_y) * uint(arguments.width) + uint(x - arguments.data_x)].rgb;
    if (arguments.is_identity != 0u) {
        const float source_alpha = positive[uint(y - arguments.data_y) * uint(arguments.width) + uint(x - arguments.data_x)].a;
        source_positive /= max(source_alpha, 1.0e-6f);
    }
    const float matte = mist_smoothstep(1.0f, 3.0f,
                                        log2(max(luminance(original), 0x1p-16f) / 0.18f));
    const float3 diffusion_blur = diffusion[index].rgb;
    const float3 highlighted_source = source_positive * matte;
    const float3 bloom_blur = bloom[index].rgb;
    float3 diffusion_raw;
    if (arguments.mode == 0) {
        diffusion_raw = max(diffusion_blur - source_positive, float3(0.0f));
    } else {
        diffusion_raw = diffusion_blur - source_positive;
    }
    const float3 bloom_raw = max(bloom_blur - highlighted_source, float3(0.0f));
    const float signed_veil_amount = arguments.mode == 1 ? min(arguments.diffusion, 1.0f) : arguments.diffusion;
    const float excess_veil_amount = arguments.mode == 1 ? max(arguments.diffusion - 1.0f, 0.0f) : 0.0f;
    const float3 veil_contribution = diffusion_raw * signed_veil_amount +
                                     max(diffusion_raw, float3(0.0f)) * excess_veil_amount;
    const float3 glow_contribution = bloom_raw * arguments.bloom;
    const float3 veil_input = source_positive + veil_contribution;
    const float veil_luminance = max(luminance(veil_input), 0x1p-16f);
    const float target_luminance = 0.18f * exp2(arguments.contrast * log2(veil_luminance / 0.18f));
    const float contrast_ratio = target_luminance / veil_luminance;
    const float3 contrasted = veil_input * contrast_ratio;
    const float3 veil_component = (arguments.diffusion <= 0.0f && arguments.contrast >= 1.0f)
                                      ? float3(0.0f)
                                      : contrasted - source_positive;
    const float3 fine = detail_fine[index].rgb;
    const float3 mid = detail_mid[index].rgb;
    const float source_luma = luminance(source_positive);
    const int sample_x0 = max(0, x - arguments.data_x);
    const int sample_y0 = max(0, y - arguments.data_y);
    const int sample_x1 = min(arguments.width - 1, sample_x0 + 1);
    const int sample_y1 = min(arguments.height - 1, sample_y0 + 1);
    const float luma_left = luminance(positive[uint(sample_y0) * uint(arguments.width) + uint(max(0, sample_x0 - 1))].rgb);
    const float luma_right = luminance(positive[uint(sample_y0) * uint(arguments.width) + uint(sample_x1)].rgb);
    const float luma_up = luminance(positive[uint(max(0, sample_y0 - 1)) * uint(arguments.width) + uint(sample_x0)].rgb);
    const float luma_down = luminance(positive[uint(sample_y1) * uint(arguments.width) + uint(sample_x0)].rgb);
    const float gradient = fabs(luma_right - luma_left) + fabs(luma_down - luma_up);
    const float edge_protection = clamp(gradient * arguments.detail_edge_protection, 0.0f, 1.0f);
    const float softness = (1.0f - arguments.texture) * arguments.detail_strength * (1.0f - edge_protection);
    const float fine_delta = luminance(fine) - luminance(mid);
    const float mid_delta = luminance(mid) - source_luma;
    const float detail_gain = clamp(0.18f * fine_delta + 0.82f * mid_delta, -source_luma, 8.0f);
    const float detail_ratio = source_luma > 1.0e-6f ? detail_gain / source_luma : 0.0f;
    const float3 detail_component = source_positive * (detail_ratio * softness);
    const float3 raw_contribution = glow_contribution + veil_component + detail_component;
    const float3 positive_effected = original_positive + raw_contribution;
    const float3 retained_positive = max(positive_effected, original_positive * arguments.black_retention);
    const float3 limited_contribution = retained_positive - original_positive;
    const float3 effected = original - original_positive + retained_positive;
    float3 result;
    if (arguments.diagnostic_view == 0u) {
        result = original + (effected - original) * arguments.mix;
    } else if (arguments.diagnostic_view == 1u) {
        result = effected - original;
    } else if (arguments.diagnostic_view == 6u) {
        result = glow_contribution;
    } else if (arguments.diagnostic_view == 7u) {
        result = veil_component;
    } else if (arguments.diagnostic_view == 8u) {
        result = limited_contribution - glow_contribution - veil_component;
    } else {
        result = float3(matte);
    }
    float3 output = from_dwg(result, arguments.working_mode);
    if (arguments.alpha_association == 1u) output *= alpha;
    destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}

kernel void cbef_mist_finalize_pyramid(texture2d<float, access::sample> positive [[texture(0)]],
                                       texture2d<float, access::sample> diffusion [[texture(1)]],
                                       texture2d<float, access::sample> bloom [[texture(2)]],
                                       texture2d<float, access::sample> detail_fine [[texture(3)]],
                                       texture2d<float, access::sample> detail_mid [[texture(4)]],
                                       const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                                       constant MistPyramidArguments& arguments [[buffer(2)]],
                                       uint2 position [[thread_position_in_grid]]) {
    const MistArguments base = arguments.base;
    if (position.x >= arguments.output_width || position.y >= arguments.output_height) return;
    const uint source_word = (uint(position.y) * base.source_row_bytes + uint(position.x) * 16u) / 4u;
    const uint destination_word = (uint(position.y) * base.destination_row_bytes + uint(position.x) * 16u) / 4u;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (base.alpha_association == 1u) encoded /= alpha;
    const float3 original = to_dwg(encoded, base.working_mode);
    const float3 original_positive = max(original, float3(0.0f));
    const float2 center = (float2(position) + 0.5f) / float(arguments.downsample);
    const float3 source_positive = positive.sample(cbef_linear_sampler, center).rgb;
    const float matte = mist_smoothstep(1.0f, 3.0f,
                                        log2(max(luminance(original), 0x1p-16f) / 0.18f));
    const float3 diffusion_blur = diffusion.sample(cbef_linear_sampler, center).rgb;
    const float3 bloom_blur = bloom.sample(cbef_linear_sampler, center).rgb;
    const float3 highlighted_source = source_positive * matte;
    const float3 diffusion_raw = base.mode == 0 ? max(diffusion_blur - source_positive, float3(0.0f))
                                                : diffusion_blur - source_positive;
    const float3 bloom_raw = max(bloom_blur - highlighted_source, float3(0.0f));
    const float signed_veil_amount = base.mode == 1 ? min(base.diffusion, 1.0f) : base.diffusion;
    const float excess_veil_amount = base.mode == 1 ? max(base.diffusion - 1.0f, 0.0f) : 0.0f;
    const float3 veil_contribution = diffusion_raw * signed_veil_amount +
                                     max(diffusion_raw, float3(0.0f)) * excess_veil_amount;
    const float3 glow_contribution = bloom_raw * base.bloom;
    const float3 veil_input = source_positive + veil_contribution;
    const float veil_luminance = max(luminance(veil_input), 0x1p-16f);
    const float target_luminance = 0.18f * exp2(base.contrast * log2(veil_luminance / 0.18f));
    const float3 contrasted = veil_input * (target_luminance / veil_luminance);
    const float3 veil_component = (base.diffusion <= 0.0f && base.contrast >= 1.0f)
                                      ? float3(0.0f) : contrasted - source_positive;
    const float3 fine = detail_fine.sample(cbef_linear_sampler, center).rgb;
    const float3 mid = detail_mid.sample(cbef_linear_sampler, center).rgb;
    const float source_luma = luminance(source_positive);
    const float2 step = float2(1.0f, 0.0f);
    const float luma_left = luminance(positive.sample(cbef_linear_sampler, center - step).rgb);
    const float luma_right = luminance(positive.sample(cbef_linear_sampler, center + step).rgb);
    const float luma_up = luminance(positive.sample(cbef_linear_sampler, center - step.yx).rgb);
    const float luma_down = luminance(positive.sample(cbef_linear_sampler, center + step.yx).rgb);
    const float edge_protection = clamp((fabs(luma_right - luma_left) + fabs(luma_down - luma_up)) *
                                            base.detail_edge_protection, 0.0f, 1.0f);
    const float softness = (1.0f - base.texture) * base.detail_strength * (1.0f - edge_protection);
    const float detail_gain = clamp(0.18f * (luminance(fine) - luminance(mid)) +
                                        0.82f * (luminance(mid) - source_luma), -source_luma, 8.0f);
    const float3 detail_component = source_positive * (source_luma > 1.0e-6f ? detail_gain / source_luma : 0.0f) * softness;
    const float3 raw_contribution = glow_contribution + veil_component + detail_component;
    const float3 positive_effected = original_positive + raw_contribution;
    const float3 retained_positive = max(positive_effected, original_positive * base.black_retention);
    const float3 limited_contribution = retained_positive - original_positive;
    const float3 effected = original - original_positive + retained_positive;
    float3 result = original;
    if (base.diagnostic_view == 0u) result = original + (effected - original) * base.mix;
    else if (base.diagnostic_view == 1u) result = effected - original;
    else if (base.diagnostic_view == 6u) result = glow_contribution;
    else if (base.diagnostic_view == 7u) result = veil_component;
    else if (base.diagnostic_view == 8u) result = limited_contribution - glow_contribution - veil_component;
    else result = float3(matte);
    float3 output = from_dwg(result, base.working_mode);
    if (base.alpha_association == 1u) output *= alpha;
    destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}

float optical_matte(float3 value, float alpha) {
    if (alpha <= 1.0e-6f) return 0.0f;
    const float light = luminance(value);
    if (light <= 0.50911688f) return 0.0f;
    if (light >= 1.01823376f) return 1.0f;
    const float t = (light - 0.50911688f) / 0.50911688f;
    return t * t * (3.0f - 2.0f * t);
}

float4 optical_fetch(const device float4* samples, const device float4* pyramid,
                     constant OpticalArguments& arguments, uint level, int x, int y) {
    uint width = uint(arguments.width);
    uint height = uint(arguments.height);
    uint offset = 0u;
    if (level == 1u) {
        width = arguments.half_width;
        height = arguments.half_height;
        offset = arguments.half_offset;
    } else if (level == 2u) {
        width = arguments.quarter_width;
        height = arguments.quarter_height;
        offset = arguments.quarter_offset;
    } else if (level == 3u) {
        width = arguments.eighth_width;
        height = arguments.eighth_height;
        offset = arguments.eighth_offset;
    }
    const int safe_x = clamp(x, 0, int(width) - 1);
    const int safe_y = clamp(y, 0, int(height) - 1);
    const uint index = uint(safe_y) * width + uint(safe_x);
    return level == 0u ? samples[index] : pyramid[offset + index];
}

float4 optical_sample(const device float4* samples, const device float4* pyramid,
                      constant OpticalArguments& arguments, uint level, float2 source_position) {
    const float2 level_position = source_position / float(1u << level);
    const int2 lower = int2(floor(level_position));
    const float2 fraction = clamp(level_position - float2(lower), 0.0f, 1.0f);
    const float4 a = optical_fetch(samples, pyramid, arguments, level, lower.x, lower.y);
    const float4 b = optical_fetch(samples, pyramid, arguments, level, lower.x + 1, lower.y);
    const float4 c = optical_fetch(samples, pyramid, arguments, level, lower.x, lower.y + 1);
    const float4 d = optical_fetch(samples, pyramid, arguments, level, lower.x + 1, lower.y + 1);
    const float alpha = mix(mix(a.a, b.a, fraction.x), mix(c.a, d.a, fraction.x), fraction.y);
    const float3 weighted = mix(mix(a.rgb * a.a, b.rgb * b.a, fraction.x),
                                mix(c.rgb * c.a, d.rgb * d.a, fraction.x), fraction.y);
    return float4(alpha > 1.0e-12f ? weighted / alpha : float3(0.0f), alpha);
}

struct OpticalLevelBlend {
    uint lower;
    uint upper;
    float amount;
};

OpticalLevelBlend optical_level_blend(float radius) {
    if (radius <= 4.0f) return {0u, 0u, 0.0f};
    if (radius < 8.0f) {
        const float t = (radius - 4.0f) * 0.25f;
        return {0u, 1u, t * t * (3.0f - 2.0f * t)};
    }
    if (radius < 16.0f) return {1u, 1u, 0.0f};
    if (radius < 24.0f) {
        const float t = (radius - 16.0f) * 0.125f;
        return {1u, 2u, t * t * (3.0f - 2.0f * t)};
    }
    if (radius < 48.0f) return {2u, 2u, 0.0f};
    if (radius < 64.0f) {
        const float t = (radius - 48.0f) * 0.0625f;
        return {2u, 3u, t * t * (3.0f - 2.0f * t)};
    }
    return {3u, 3u, 0.0f};
}

kernel void cbef_optical_copy(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                              constant OpticalArguments& arguments [[buffer(2)]],
                              uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes +
                              uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.data_y) * arguments.destination_row_bytes +
                                   uint(x - arguments.data_x) * 16u) / 4u;
    destination[destination_word + 0u] = source[source_word + 0u];
    destination[destination_word + 1u] = source[source_word + 1u];
    destination[destination_word + 2u] = source[source_word + 2u];
    destination[destination_word + 3u] = source[source_word + 3u];
}

kernel void cbef_optical_prepare(const device uint* source [[buffer(0)]], device float4* samples [[buffer(1)]],
                                 constant OpticalArguments& arguments [[buffer(2)]],
                                 uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const uint source_word = (position.y * arguments.source_row_bytes + position.x * 16u) / 4u;
    const uint index = position.y * uint(arguments.width) + position.x;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        samples[index] = float4(0.0f);
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]),
                            as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    const float3 original = to_dwg(encoded, arguments.working_mode);
    samples[index] = float4(original, alpha);
}

kernel void cbef_optical_downsample(const device float4* samples [[buffer(0)]], device float4* pyramid [[buffer(1)]],
                                    constant OpticalArguments& arguments [[buffer(2)]],
                                    uint2 position [[thread_position_in_grid]]) {
    const uint level = arguments.downsample_level;
    const uint width = level == 1u ? arguments.half_width :
                       level == 2u ? arguments.quarter_width : arguments.eighth_width;
    const uint height = level == 1u ? arguments.half_height :
                        level == 2u ? arguments.quarter_height : arguments.eighth_height;
    if (position.x >= width || position.y >= height) return;
    const uint offset = level == 1u ? arguments.half_offset :
                        level == 2u ? arguments.quarter_offset : arguments.eighth_offset;
    constexpr float weights[3] = {0.25f, 0.50f, 0.25f};
    float alpha = 0.0f;
    float3 weighted = float3(0.0f);
    for (int oy = -1; oy <= 1; ++oy) {
        for (int ox = -1; ox <= 1; ++ox) {
            const float filter_weight = weights[ox + 1] * weights[oy + 1];
            const float4 sample = optical_fetch(samples, pyramid, arguments, level - 1u,
                                                int(position.x) * 2 + ox, int(position.y) * 2 + oy);
            alpha += sample.a * filter_weight;
            weighted += sample.rgb * sample.a * filter_weight;
        }
    }
    pyramid[offset + position.y * width + position.x] =
        float4(alpha > 1.0e-12f ? weighted / alpha : float3(0.0f), alpha);
}

kernel void cbef_optical_render(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                                const device float4* samples [[buffer(2)]],
                                const device float4* pyramid [[buffer(3)]],
                                const device OpticalPoint* points [[buffer(4)]],
                                constant OpticalArguments& arguments [[buffer(5)]],
                                uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes +
                              uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.data_y) * arguments.destination_row_bytes +
                                   uint(x - arguments.data_x) * 16u) / 4u;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    const int local_x = x - arguments.data_x;
    const int local_y = y - arguments.data_y;
    const uint index = uint(local_y) * uint(arguments.width) + uint(local_x);
    const float field_x = 2.0f * (float(local_x) + 0.5f) / float(arguments.width) - 1.0f;
    const float field_y = 2.0f * (float(local_y) + 0.5f) / float(arguments.height) - 1.0f;
    const float raw_field_radius = clamp(length(float2(field_x, field_y)), 0.0f, 1.41421356f);
    const float focus_bias = clamp(arguments.field_curvature / 100.0f, -1.0f, 1.0f);
    const float effective_radius = arguments.blur_radius *
        (1.0f + 0.30f * focus_bias * min(raw_field_radius * raw_field_radius, 1.0f));
    const float curved_field_radius = clamp(raw_field_radius *
        (1.0f + 0.28f * focus_bias * raw_field_radius), 0.0f, 1.41421356f);
    const float2 radial_direction = curved_field_radius > 1.0e-6f ?
        float2(field_x, field_y) / curved_field_radius : float2(0.0f);
    constexpr float profile_cat_eye[4] = {1.00f, 0.82f, 1.08f, 1.18f};
    const float cat_eye = clamp(arguments.cat_eye / 100.0f, 0.0f, 1.0f) *
                          profile_cat_eye[min(arguments.lens_profile, 3u)];
    const float field_factor = min(curved_field_radius, 1.0f);
    const float pupil_limit = 1.0f - 0.48f * cat_eye * field_factor;
    const float pupil_softness = 0.10f + 0.04f * (1.0f - field_factor);
    const float bokeh_bias = clamp(arguments.bokeh_bias / 100.0f, -1.0f, 1.0f);
    const float coma = clamp(arguments.coma / 100.0f, 0.0f, 1.0f);
    const float astigmatism = clamp(arguments.astigmatism / 100.0f, 0.0f, 1.0f);
    const float dispersion = 0.35f * clamp(arguments.chromatic_aberration / 100.0f, 0.0f, 1.0f) *
                             field_factor * effective_radius;
    const float radius_x = effective_radius * max(arguments.anamorphism, 0.01f);
    const OpticalLevelBlend levels = optical_level_blend(effective_radius);
    float3 weighted_base = float3(0.0f);
    float3 weighted_highlight = float3(0.0f);
    float3 accumulated_alpha = float3(0.0f);
    for (uint sample_index = 0u; sample_index < arguments.tap_count; ++sample_index) {
        const OpticalPoint point = points[sample_index];
        const float aperture_radius = clamp(point.x * point.x + point.y * point.y, 0.0f, 1.0f);
        const float radial = dot(float2(point.x, point.y), radial_direction);
        const float tangential = -point.x * radial_direction.y + point.y * radial_direction.x;
        const float clip = cat_eye <= 1.0e-6f ? 0.0f :
            smoothstep(pupil_limit - pupil_softness, pupil_limit + pupil_softness, radial);
        const float radial_weight = max(0.02f, 1.0f + bokeh_bias * (2.0f * aperture_radius - 1.0f));
        const float coma_weight = 1.0f + 0.52f * coma * field_factor * radial *
                                  (1.0f - 0.55f * aperture_radius);
        const float astig_weight = 1.0f + 0.32f * astigmatism * field_factor *
                                   (radial * radial - tangential * tangential);
        const float weight = point.weight * (1.0f - 0.92f * clip) * radial_weight *
                             max(0.02f, coma_weight * astig_weight);
        const float2 aperture_position = float2(local_x, local_y) +
            float2(point.x * radius_x, point.y * effective_radius);
        if (dispersion <= 1.0e-8f) {
            float4 sampled = optical_sample(samples, pyramid, arguments, levels.lower, aperture_position);
            if (levels.upper != levels.lower) {
                const float4 upper = optical_sample(samples, pyramid, arguments, levels.upper, aperture_position);
                sampled = mix(sampled, upper, levels.amount);
            }
            const float sample_weight = sampled.a * weight;
            weighted_base += sampled.rgb * sample_weight;
            weighted_highlight += max(sampled.rgb, float3(0.0f)) * optical_matte(sampled.rgb, sampled.a) *
                                  sample_weight;
            accumulated_alpha += float3(sample_weight);
        } else {
            for (uint channel = 0u; channel < 3u; ++channel) {
                const float channel_sign = channel == 0u ? 1.0f : channel == 2u ? -1.0f : 0.0f;
                const float2 sample_position = aperture_position + channel_sign * dispersion * radial_direction;
                float4 sampled = optical_sample(samples, pyramid, arguments, levels.lower, sample_position);
                if (levels.upper != levels.lower) {
                    const float4 upper = optical_sample(samples, pyramid, arguments, levels.upper, sample_position);
                    sampled = mix(sampled, upper, levels.amount);
                }
                const float channel_value = sampled[channel];
                const float highlight_value = max(channel_value, 0.0f) * optical_matte(sampled.rgb, sampled.a);
                weighted_base[channel] += channel_value * sampled.a * weight;
                weighted_highlight[channel] += highlight_value * sampled.a * weight;
                accumulated_alpha[channel] += sampled.a * weight;
            }
        }
    }
    const float3 denominator = max(accumulated_alpha, float3(1.0e-12f));
    const float3 base = weighted_base / denominator;
    const float3 blurred_highlight = weighted_highlight / denominator;
    const float3 original = samples[index].rgb;
    const float3 source_highlight = max(original, float3(0.0f)) * optical_matte(original, alpha);
    const float response = arguments.highlight_response / 100.0f;
    const float3 component = response * max(blurred_highlight - source_highlight, float3(0.0f));
    const float vignette = 1.0f - 0.78f * clamp(arguments.vignetting / 100.0f, 0.0f, 1.0f) *
                           min(raw_field_radius * raw_field_radius, 1.0f);
    const float3 effected = (base + component) * vignette;
    float3 result;
    if (arguments.diagnostic_view == 0u) result = original + (effected - original) * arguments.mix;
    else if (arguments.diagnostic_view == 3u) result = base;
    else if (arguments.diagnostic_view == 6u) result = blurred_highlight;
    else if (arguments.diagnostic_view == 2u) result = float3(optical_matte(original, alpha));
    else result = component;
    float3 output = from_dwg(result, arguments.working_mode);
    if (arguments.alpha_association == 1u) output *= alpha;
    destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}

float lens_smoothstep(float lower, float upper, float value) {
    if (value <= lower) return 0.0f;
    if (value >= upper) return 1.0f;
    const float t = (value - lower) / (upper - lower);
    return t * t * (3.0f - 2.0f * t);
}

kernel void cbef_lens_copy(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                           constant LensV2Arguments& arguments [[buffer(2)]],
                           uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes +
                              uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.data_y) * arguments.destination_row_bytes +
                                   uint(x - arguments.data_x) * 16u) / 4u;
    destination[destination_word + 0u] = source[source_word + 0u];
    destination[destination_word + 1u] = source[source_word + 1u];
    destination[destination_word + 2u] = source[source_word + 2u];
    destination[destination_word + 3u] = source[source_word + 3u];
}

float lens_external_pixel(const device uint* matte, int x, int y, constant LensV2Arguments& arguments) {
    const uint pixel_bytes = arguments.matte_format == 2u ? 4u : 16u;
    const uint word = (uint(y - arguments.matte_y) * arguments.matte_row_bytes +
                       uint(x - arguments.matte_x) * pixel_bytes) / 4u;
    if (arguments.matte_format == 2u) {
        const float value = as_type<float>(matte[word]);
        return isfinite(value) ? clamp(value, 0.0f, 1.0f) : 0.0f;
    }
    float alpha = as_type<float>(matte[word + 3u]);
    alpha = isfinite(alpha) ? clamp(alpha, 0.0f, 1.0f) : 0.0f;
    if (alpha <= 1.0e-6f) return 0.0f;
    float3 rgb = float3(as_type<float>(matte[word]), as_type<float>(matte[word + 1u]),
                        as_type<float>(matte[word + 2u]));
    rgb = select(float3(0.0f), rgb, isfinite(rgb));
    if (arguments.matte_alpha_association == 1u) rgb /= alpha;
    return clamp(luminance(max(rgb, float3(0.0f))) * alpha, 0.0f, 1.0f);
}

float lens_external_matte(const device uint* matte, int x, int y, constant LensV2Arguments& arguments) {
    if (arguments.has_matte == 0u) return 1.0f;
    const float u = (float(x - arguments.data_x) + 0.5f) / float(arguments.width);
    const float v = (float(y - arguments.data_y) + 0.5f) / float(arguments.height);
    if (u < 0.0f || u > 1.0f || v < 0.0f || v > 1.0f) return 0.0f;
    const float mx = float(arguments.matte_x) + u * float(arguments.matte_width) - 0.5f;
    const float my = float(arguments.matte_y) + v * float(arguments.matte_height) - 0.5f;
    const int x0 = int(floor(mx));
    const int y0 = int(floor(my));
    const float tx = clamp(mx - float(x0), 0.0f, 1.0f);
    const float ty = clamp(my - float(y0), 0.0f, 1.0f);
    const int max_x = arguments.matte_x + arguments.matte_width - 1;
    const int max_y = arguments.matte_y + arguments.matte_height - 1;
    const float p00 = lens_external_pixel(matte, clamp(x0, arguments.matte_x, max_x), clamp(y0, arguments.matte_y, max_y), arguments);
    const float p10 = lens_external_pixel(matte, clamp(x0 + 1, arguments.matte_x, max_x), clamp(y0, arguments.matte_y, max_y), arguments);
    const float p01 = lens_external_pixel(matte, clamp(x0, arguments.matte_x, max_x), clamp(y0 + 1, arguments.matte_y, max_y), arguments);
    const float p11 = lens_external_pixel(matte, clamp(x0 + 1, arguments.matte_x, max_x), clamp(y0 + 1, arguments.matte_y, max_y), arguments);
    return clamp(mix(mix(p00, p10, tx), mix(p01, p11, tx), ty), 0.0f, 1.0f);
}

float3 lens_source_rgb(const device uint* source, int x, int y, constant LensV2Arguments& arguments,
                       thread float& alpha) {
    const uint word = (uint(y - arguments.data_y) * arguments.source_row_bytes +
                       uint(x - arguments.data_x) * 16u) / 4u;
    alpha = as_type<float>(source[word + 3u]);
    if (alpha <= 1.0e-6f) return float3(0.0f);
    float3 encoded = float3(as_type<float>(source[word]), as_type<float>(source[word + 1u]),
                            as_type<float>(source[word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    return to_dwg(encoded, arguments.working_mode);
}

float3 lens_analysis_rgb(float3 original, constant LensV2Arguments& arguments) {
    if (arguments.source_mode == 0) return max(original, float3(0.0f));
    const float value = luminance(original);
    float3 result = arguments.manual_color == 1 ? float3(value) :
                    arguments.manual_color == 2 ? float3(value * 1.10f, value * 0.90f, value * 0.68f) :
                                                  max(original, float3(0.0f));
    return luminance(result) <= 1.0e-6f ? float3(1.0f) : result;
}

float lens_source_matte(float3 original, float alpha, int x, int y,
                        constant LensV2Arguments& arguments) {
    if (alpha <= 1.0e-6f) return 0.0f;
    if (arguments.source_mode == 1) {
        const float cx = float(arguments.data_x) +
                         (arguments.manual_x / 100.0f + 1.0f) * 0.5f * float(arguments.width) + 0.5f;
        const float cy = float(arguments.data_y) +
                         (arguments.manual_y / 100.0f + 1.0f) * 0.5f * float(arguments.height) + 0.5f;
        const float ry = max(0.5f, float(arguments.height) * arguments.manual_size / 200.0f);
        const float rx = max(0.5f, ry * max(arguments.anamorphism, 0.5f));
        const float distance = length(float2((float(x) + 0.5f - cx) / rx, (float(y) + 0.5f - cy) / ry));
        return clamp(1.0f - lens_smoothstep(0.65f, 1.0f, distance), 0.0f, 1.0f) *
               clamp(arguments.manual_intensity / 100.0f, 0.0f, 2.0f);
    }
    const float3 positive = max(original, float3(0.0f));
    const float metric = arguments.source_metric == 0 ? luminance(positive) :
                                                        max(positive.r, max(positive.g, positive.b));
    const float stops = log2(max(metric, 0x1p-16f) / 0.18f);
    const float knee = 1.0f + clamp(arguments.source_smoothness, 0.0f, 100.0f) * 0.02f;
    const float upper = arguments.source_smoothness <= 0.0f ? arguments.threshold :
                                                               arguments.threshold + knee * 0.25f;
    return pow(clamp(lens_smoothstep(arguments.threshold - knee, upper, stops), 0.0f, 1.0f),
               1.0f / max(arguments.source_gamma, 0.25f));
}

bool lens_uses_direct_source_matte(constant LensV2Arguments& arguments) {
    return arguments.projection_downsample > 1u && arguments.diagnostic_view == 0u &&
           arguments.has_matte == 0u && fabs(arguments.source_morphology) < 1.0f &&
           arguments.veil <= 0.0f;
}

kernel void cbef_lens_prepare_v2(const device uint* source [[buffer(0)]], const device uint* matte [[buffer(1)]],
                                 device float2* mattes [[buffer(2)]],
                                 constant LensV2Arguments& arguments [[buffer(3)]],
                                 uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const int x = arguments.data_x + int(position.x);
    const int y = arguments.data_y + int(position.y);
    float alpha = 0.0f;
    const float3 original = lens_source_rgb(source, x, y, arguments, alpha);
    const float before = lens_source_matte(original, alpha, x, y, arguments);
    mattes[position.y * uint(arguments.width) + position.x] = float2(clamp(before, 0.0f, 1.0f),
                                                                      clamp(before * lens_external_matte(matte, x, y, arguments), 0.0f, 1.0f));
}

kernel void cbef_lens_morphology_v2(const device float2* input [[buffer(0)]], const device uint* matte [[buffer(1)]],
                                    device float2* output [[buffer(2)]],
                                    constant LensV2Arguments& arguments [[buffer(3)]],
                                    uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const int radius = clamp(int(ceil(fabs(arguments.source_morphology) / 50.0f)), 1, 2);
    float value = arguments.source_morphology > 0.0f ? 0.0f : 1.0f;
    for (int dy = -radius; dy <= radius; ++dy) {
        for (int dx = -radius; dx <= radius; ++dx) {
            const int sx = int(position.x) + dx;
            const int sy = int(position.y) + dy;
            if (sx < 0 || sy < 0 || sx >= arguments.width || sy >= arguments.height) continue;
            const float sample = input[uint(sy) * uint(arguments.width) + uint(sx)].x;
            value = arguments.source_morphology > 0.0f ? max(value, sample) : min(value, sample);
        }
    }
    const int x = arguments.data_x + int(position.x);
    const int y = arguments.data_y + int(position.y);
    output[position.y * uint(arguments.width) + position.x] =
        float2(value, value * lens_external_matte(matte, x, y, arguments));
}

kernel void cbef_lens_half_source_v2(const device uint* source [[buffer(0)]], const device float2* mattes [[buffer(1)]],
                                     device float4* half_source [[buffer(2)]],
                                     constant LensV2Arguments& arguments [[buffer(3)]],
                                     uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.half_width || position.y >= arguments.half_height) return;
    float4 total = float4(0.0f);
    float count = 0.0f;
    for (uint oy = 0u; oy < 2u; ++oy) {
        for (uint ox = 0u; ox < 2u; ++ox) {
            const uint sx = position.x * 2u + ox;
            const uint sy = position.y * 2u + oy;
            if (sx >= uint(arguments.width) || sy >= uint(arguments.height)) continue;
            float alpha = 0.0f;
            const float3 original = lens_source_rgb(source, arguments.data_x + int(sx), arguments.data_y + int(sy), arguments, alpha);
            const float matte = lens_uses_direct_source_matte(arguments)
                                    ? lens_source_matte(original, alpha, arguments.data_x + int(sx),
                                                        arguments.data_y + int(sy), arguments)
                                    : mattes[sy * uint(arguments.width) + sx].y;
            total += float4(max(original, float3(0.0f)) * matte * alpha, matte);
            count += 1.0f;
        }
    }
    half_source[position.y * arguments.half_width + position.x] = total / max(count, 1.0f);
}

kernel void cbef_lens_tiles_v2(const device uint* source [[buffer(0)]], const device float2* mattes [[buffer(1)]],
                               device LensTilePair* tiles [[buffer(2)]],
                               constant LensV2Arguments& arguments [[buffer(3)]],
                               uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.tile_columns || position.y >= arguments.tile_rows) return;
    LensTileStats before{};
    LensTileStats limited{};
    const uint x0 = position.x * 8u;
    const uint y0 = position.y * 8u;
    constexpr uint step = 1u;
    constexpr uint sample_offset = 0u;
    for (uint oy = sample_offset; oy < 8u && y0 + oy < uint(arguments.height); oy += step) {
        for (uint ox = sample_offset; ox < 8u && x0 + ox < uint(arguments.width); ox += step) {
            const uint sx = x0 + ox;
            const uint sy = y0 + oy;
            const uint index = sy * uint(arguments.width) + sx;
            float alpha = 0.0f;
            const float3 original = lens_source_rgb(source, arguments.data_x + int(sx), arguments.data_y + int(sy), arguments, alpha);
            const float3 color = lens_analysis_rgb(original, arguments);
            const float luma = luminance(color);
            const float color_scale = min(1.0f, 1.0e10f / max(max(color.r, color.g), max(color.b, 1.0e-20f)));
            const float3 statistics_color = color * color_scale;
            const float direct_matte = lens_source_matte(original, alpha, arguments.data_x + int(sx),
                                                         arguments.data_y + int(sy), arguments);
            const float2 matte_weights = lens_uses_direct_source_matte(arguments) ? float2(direct_matte) : mattes[index];
            const float sample_area = float(step * step);
            const float2 weights = matte_weights * luma * sample_area;
            const float gx = float(arguments.data_x + int(sx));
            const float gy = float(arguments.data_y + int(sy));
            before.energy += weights.x;
            before.weighted_x += gx * weights.x;
            before.weighted_y += gy * weights.x;
            before.weighted_x2 += gx * gx * weights.x;
            before.weighted_y2 += gy * gy * weights.x;
            before.red += statistics_color.r * weights.x;
            before.green += statistics_color.g * weights.x;
            before.blue += statistics_color.b * weights.x;
            limited.energy += weights.y;
            limited.weighted_x += gx * weights.y;
            limited.weighted_y += gy * weights.y;
            limited.weighted_x2 += gx * gx * weights.y;
            limited.weighted_y2 += gy * gy * weights.y;
            limited.red += statistics_color.r * weights.y;
            limited.green += statistics_color.g * weights.y;
            limited.blue += statistics_color.b * weights.y;
        }
    }
    tiles[position.y * arguments.tile_columns + position.x] = LensTilePair{before, limited};
}

kernel void cbef_lens_select_groups_v2(const device LensTilePair* tiles [[buffer(0)]],
                                       device LensCandidate* group_candidates [[buffer(1)]],
                                       constant LensV2Arguments& arguments [[buffer(2)]],
                                       uint2 position [[thread_position_in_grid]]) {
    constexpr uint group_size = 256u;
    const uint tile_count = arguments.tile_columns * arguments.tile_rows;
    const uint group_count = (tile_count + group_size - 1u) / group_size;
    if (position.x >= group_count || position.y >= 2u) return;
    const uint pass = position.y;
    const uint group_begin = position.x * group_size;
    const uint group_end = min(group_begin + group_size, tile_count);
    const uint output_offset = (pass * group_count + position.x) * 8u;
    for (uint slot = 0u; slot < 8u; ++slot) group_candidates[output_offset + slot] = LensCandidate{};
    {
        float best_energy[8];
        uint best_index[8];
        for (uint slot = 0u; slot < 8u; ++slot) { best_energy[slot] = 0.0f; best_index[slot] = 0xFFFFFFFFu; }
        for (uint index = group_begin; index < group_end; ++index) {
            const LensTileStats stat = pass == 0u ? tiles[index].before : tiles[index].limited;
            if (stat.energy <= 0.0f) continue;
            const int tx = int(index % arguments.tile_columns);
            const int ty = int(index / arguments.tile_columns);
            bool maximum = true;
            for (int oy = -1; oy <= 1 && maximum; ++oy) {
                for (int ox = -1; ox <= 1; ++ox) {
                    const int nx = tx + ox;
                    const int ny = ty + oy;
                    if ((ox == 0 && oy == 0) || nx < 0 || ny < 0 || nx >= int(arguments.tile_columns) || ny >= int(arguments.tile_rows)) continue;
                    const uint neighbor_index = uint(ny) * arguments.tile_columns + uint(nx);
                    const LensTileStats neighbor = pass == 0u ? tiles[neighbor_index].before : tiles[neighbor_index].limited;
                    if (neighbor.energy > stat.energy || (neighbor.energy == stat.energy && neighbor_index < index)) maximum = false;
                }
            }
            if (!maximum) continue;
            uint insert = 8u;
            for (uint slot = 0u; slot < 8u; ++slot) {
                if (stat.energy > best_energy[slot] || (stat.energy == best_energy[slot] && index < best_index[slot])) { insert = slot; break; }
            }
            if (insert < 8u) {
                for (uint slot = 7u; slot > insert; --slot) { best_energy[slot] = best_energy[slot - 1u]; best_index[slot] = best_index[slot - 1u]; }
                best_energy[insert] = stat.energy;
                best_index[insert] = index;
            }
        }
        for (uint slot = 0u; slot < 8u; ++slot) {
            if (best_index[slot] == 0xFFFFFFFFu) continue;
            const LensTileStats stat = pass == 0u ? tiles[best_index[slot]].before : tiles[best_index[slot]].limited;
            const float inverse = 1.0f / max(stat.energy, 1.0e-20f);
            const float cx = stat.weighted_x * inverse;
            const float cy = stat.weighted_y * inverse;
            const float variance = max(0.0f, stat.weighted_x2 * inverse - cx * cx) + max(0.0f, stat.weighted_y2 * inverse - cy * cy);
            group_candidates[output_offset + slot] =
                LensCandidate{cx, cy, max(1.0f, 1.5f * sqrt(variance)), stat.energy,
                              stat.red * inverse, stat.green * inverse, stat.blue * inverse,
                              best_index[slot] + 1u};
        }
    }
}

kernel void cbef_lens_select_finalize_v2(const device LensCandidate* group_candidates [[buffer(0)]],
                                         device LensCandidate* candidates [[buffer(1)]],
                                         constant LensV2Arguments& arguments [[buffer(2)]],
                                         uint2 position [[thread_position_in_grid]]) {
    if (position.x != 0u || position.y != 0u) return;
    const uint tile_count = arguments.tile_columns * arguments.tile_rows;
    const uint group_count = (tile_count + 255u) / 256u;
    for (uint index = 0u; index < 16u; ++index) candidates[index] = LensCandidate{};
    for (uint pass = 0u; pass < 2u; ++pass) {
        LensCandidate best[8];
        for (uint slot = 0u; slot < 8u; ++slot) best[slot] = LensCandidate{};
        for (uint group = 0u; group < group_count; ++group) {
            for (uint local = 0u; local < 8u; ++local) {
                const LensCandidate candidate = group_candidates[(pass * group_count + group) * 8u + local];
                if (candidate.valid == 0u) continue;
                uint insert = 8u;
                for (uint slot = 0u; slot < 8u; ++slot) {
                    if (candidate.energy > best[slot].energy ||
                        (candidate.energy == best[slot].energy && candidate.valid < best[slot].valid)) {
                        insert = slot;
                        break;
                    }
                }
                if (insert < 8u) {
                    for (uint slot = 7u; slot > insert; --slot) best[slot] = best[slot - 1u];
                    best[insert] = candidate;
                }
            }
        }
        uint count = 0u;
        for (uint slot = 0u; slot < 8u; ++slot) {
            if (best[slot].valid != 0u) candidates[pass * 8u + count++] = best[slot];
        }
        if (count == 0u && arguments.source_mode == 1 && arguments.has_matte == 0u) {
            const float sx = float(arguments.data_x) + (arguments.manual_x / 100.0f + 1.0f) * 0.5f * float(arguments.width) + 0.5f;
            const float sy = float(arguments.data_y) + (arguments.manual_y / 100.0f + 1.0f) * 0.5f * float(arguments.height) + 0.5f;
            const float nx = clamp(sx, float(arguments.data_x), float(arguments.data_x + arguments.width - 1));
            const float ny = clamp(sy, float(arguments.data_y), float(arguments.data_y + arguments.height - 1));
            const float reach = 0.55f * length(float2(arguments.width, arguments.height));
            if (length(float2(sx - nx, sy - ny)) <= reach) {
                const float3 color = arguments.manual_color == 2 ? float3(1.10f, 0.90f, 0.68f) : float3(1.0f);
                candidates[pass * 8u] = LensCandidate{sx, sy, max(1.0f, float(arguments.height) * arguments.manual_size / 200.0f),
                                                      clamp(arguments.manual_intensity / 100.0f, 0.0f, 2.0f), color.r, color.g, color.b, 1u};
            }
        }
    }
}

bool lens_aperture_contains(float x, float y, uint model) {
    const float radius = length(float2(x, y));
    if (radius > 1.0f) return false;
    const int blades = model == 0u ? 9 : model == 1u ? 7 : 8;
    const float curvature = model == 0u ? 0.88f : model == 1u ? 0.42f : 0.62f;
    const float rotation = model == 2u ? 0.0f : 11.0f;
    const float sector = 2.0f * M_PI_F / float(blades);
    float angle = fmod(atan2(y, x) - rotation * M_PI_F / 180.0f, sector);
    if (angle < 0.0f) angle += sector;
    angle = fabs(angle - 0.5f * sector);
    const float polygon = cos(0.5f * sector) / max(cos(angle), 1.0e-6f);
    return radius <= mix(polygon, 1.0f, curvature);
}

float lens_element_weight(LensElementGpu element, float dx, float dy, float rx, float ry, uint model) {
    const float nx = dx / max(rx, 1.0e-6f);
    const float ny = dy / max(ry, 1.0e-6f);
    const float radial = length(float2(nx, ny));
    if (element.shape == 1u) {
        if (!lens_aperture_contains(nx / max(element.aperture_clip, 0.1f), ny / max(element.aperture_clip, 0.1f), model)) return 0.0f;
        return pow(max(0.0f, 1.0f - radial * radial), max(0.2f, element.radial_falloff));
    }
    if (element.shape == 2u) {
        if (!lens_aperture_contains(nx / max(element.aperture_clip, 0.1f), ny / max(element.aperture_clip, 0.1f), model)) return 0.0f;
        const float width = 0.08f + 0.18f * (1.0f - clamp(element.ring_profile, 0.0f, 1.0f));
        const float offset = (radial - clamp(element.ring_profile, 0.2f, 0.95f)) / width;
        return exp(-0.5f * offset * offset) * pow(max(0.0f, 1.0f - 0.35f * radial), max(0.2f, element.radial_falloff));
    }
    const float exponent = element.shape == 3u ? 0.65f : 1.25f;
    return exp(-0.5f * exponent * radial * radial * max(0.2f, element.radial_falloff));
}

float3 lens_tint_gain(LensElementGpu element, constant LensV2Arguments& arguments) {
    const float3 tint = float3(element.tint_r, element.tint_g, element.tint_b);
    const float tint_luma = max(luminance(tint), 1.0e-6f);
    return 1.0f + clamp(arguments.chroma / 100.0f, 0.0f, 1.0f) * (tint / tint_luma - 1.0f);
}

float lens_gaussian_total(float sigma) {
    if (sigma <= 1.0e-6f) return 1.0f;
    const int radius = int(ceil(3.0f * sigma));
    float total = 0.0f;
    for (int tap = -radius; tap <= radius; ++tap) total += exp(-0.5f * float(tap * tap) / (sigma * sigma));
    return total;
}

float lens_gaussian_at(int offset, float sigma) {
    if (sigma <= 1.0e-6f) return offset == 0 ? 1.0f : 0.0f;
    const int radius = int(ceil(3.0f * sigma));
    if (abs(offset) > radius) return 0.0f;
    return exp(-0.5f * float(offset * offset) / (sigma * sigma)) / lens_gaussian_total(sigma);
}

float lens_axis_response(float mapped, int output, float sigma) {
    const int base = int(floor(mapped));
    const float fraction = mapped - float(base);
    return (1.0f - fraction) * lens_gaussian_at(output - base, sigma) +
           fraction * lens_gaussian_at(output - base - 1, sigma);
}

float lens_axis_captured(float mapped, float sigma, int minimum, int maximum) {
    const int base = int(floor(mapped));
    const float fraction = mapped - float(base);
    float total = 0.0f;
    for (int ox = 0; ox <= 1; ++ox) {
        const int splat = base + ox;
        if (splat < minimum || splat > maximum) continue;
        const float sw = ox == 0 ? 1.0f - fraction : fraction;
        const int radius = sigma <= 1.0e-6f ? 0 : int(ceil(3.0f * sigma));
        for (int tap = -radius; tap <= radius; ++tap) {
            const int output = splat + tap;
            if (output >= minimum && output <= maximum) total += sw * lens_gaussian_at(tap, sigma);
        }
    }
    return total;
}

kernel void cbef_lens_denominators_v2(const device uint* source [[buffer(0)]], const device float2* mattes [[buffer(1)]],
                                      const device LensCandidate* candidates [[buffer(2)]],
                                      const device LensElementGpu* elements [[buffer(3)]], device float4* denominators [[buffer(4)]],
                                      constant LensV2Arguments& arguments [[buffer(5)]],
                                      uint2 position [[thread_position_in_grid]]) {
    const uint pair = position.x;
    if (pair >= 40u) return;
    const uint source_index = pair / 5u;
    const uint element_index = pair % 5u;
    const LensCandidate candidate = candidates[8u + source_index];
    const LensElementGpu element = elements[element_index];
    if (candidate.valid == 0u || (arguments.element_solo > 0 && uint(arguments.element_solo - 1) != element_index)) {
        denominators[pair] = float4(0.0f);
        return;
    }
    const float spread = arguments.spread / 100.0f;
    const float gx = arguments.center_x + element.axis_position * spread * (candidate.x - arguments.center_x);
    const float gy = arguments.center_y + element.axis_position * spread * (candidate.y - arguments.center_y);
    const float axis_length = length(float2(candidate.x - arguments.center_x, candidate.y - arguments.center_y));
    const float2 axis = axis_length > 1.0e-6f ? float2(candidate.x - arguments.center_x, candidate.y - arguments.center_y) / axis_length : float2(1.0f, 0.0f);
    const float3 tint = lens_tint_gain(element, arguments);
    if (element.shape == 0u) {
        if (arguments.use_half_source != 0u) {
            denominators[pair] = float4(0.0f, 0.0f, 0.0f, 1.0f);
            return;
        }
        const float reach = max(4.0f, candidate.radius * 2.8f);
        const float sigma_y = float(arguments.height) * (arguments.blur + element.defocus * (1.0f - 0.65f * element.pattern_retention)) / 100.0f;
        const float sigma_x = sigma_y * max(arguments.anamorphism, 0.01f);
        float focused_luma = 0.0f;
        const int x0 = max(arguments.data_x, int(floor(candidate.x - reach)));
        const int x1 = min(arguments.data_x + arguments.width - 1, int(ceil(candidate.x + reach)));
        const int y0 = max(arguments.data_y, int(floor(candidate.y - reach)));
        const int y1 = min(arguments.data_y + arguments.height - 1, int(ceil(candidate.y + reach)));
        for (int y = y0; y <= y1; ++y) {
            for (int x = x0; x <= x1; ++x) {
                if (length(float2(float(x) - candidate.x, float(y) - candidate.y)) > reach) continue;
                const uint index = uint(y - arguments.data_y) * uint(arguments.width) + uint(x - arguments.data_x);
                const float matte = mattes[index].y;
                if (matte <= 0.0f) continue;
                float alpha = 0.0f;
                const float3 original = lens_source_rgb(source, x, y, arguments, alpha);
                const float3 value = lens_analysis_rgb(original, arguments) * matte * alpha;
                const float mx = gx + element.magnification * (float(x) - candidate.x);
                const float my = gy + element.magnification * (float(y) - candidate.y);
                const float capture = lens_axis_captured(mx, sigma_x, arguments.data_x, arguments.data_x + arguments.width - 1) *
                                      lens_axis_captured(my, sigma_y, arguments.data_y, arguments.data_y + arguments.height - 1);
                focused_luma += luminance(value * tint) * capture;
            }
        }
        denominators[pair] = float4(0.0f, 0.0f, 0.0f, focused_luma);
        return;
    }
    float ry = max(1.25f, candidate.radius * element.magnification + float(arguments.height) * (element.defocus + arguments.blur) / 100.0f);
    if (element.shape == 3u) ry *= 2.2f;
    const float rx = ry * max(0.25f, arguments.anamorphism) * (element.shape == 4u ? max(1.0f, element.streak_aspect) : 1.0f);
    if (arguments.use_half_source != 0u) {
        float normalized_area = M_PI_F * rx * ry;
        if (element.shape == 1u) normalized_area *= 0.56f * element.aperture_clip * element.aperture_clip;
        else if (element.shape == 2u) normalized_area *= 0.28f;
        else normalized_area *= 2.0f / max((element.shape == 3u ? 0.65f : 1.25f) * element.radial_falloff, 0.2f);
        denominators[pair] = float4(max(normalized_area, 1.0e-6f), max(normalized_area, 1.0e-6f),
                                    max(normalized_area, 1.0e-6f), 0.0f);
        return;
    }
    const float support = element.shape == 3u || element.shape == 4u ? 3.2f : 1.15f;
    const float dispersion = element.dispersion * clamp(arguments.chroma / 100.0f, 0.0f, 1.0f) * ry * 0.35f;
    float3 denominator = float3(0.0f);
    const int x0 = max(arguments.data_x, int(floor(gx - support * rx - dispersion)));
    const int x1 = min(arguments.data_x + arguments.width - 1, int(ceil(gx + support * rx + dispersion)));
    const int y0 = max(arguments.data_y, int(floor(gy - support * ry - dispersion)));
    const int y1 = min(arguments.data_y + arguments.height - 1, int(ceil(gy + support * ry + dispersion)));
    for (int y = y0; y <= y1; ++y) {
        for (int x = x0; x <= x1; ++x) {
            denominator.r += lens_element_weight(element, float(x) - gx + dispersion * axis.x, float(y) - gy + dispersion * axis.y, rx, ry, arguments.lens_model);
            denominator.g += lens_element_weight(element, float(x) - gx, float(y) - gy, rx, ry, arguments.lens_model);
            denominator.b += lens_element_weight(element, float(x) - gx - dispersion * axis.x, float(y) - gy - dispersion * axis.y, rx, ry, arguments.lens_model);
        }
    }
    denominators[pair] = float4(denominator, 0.0f);
}

float4 lens_sample_half(const device float4* half_source, float x, float y,
                        constant LensV2Arguments& arguments) {
    const float hx = (x - float(arguments.data_x)) * 0.5f - 0.25f;
    const float hy = (y - float(arguments.data_y)) * 0.5f - 0.25f;
    if (hx < -0.5f || hy < -0.5f || hx > float(arguments.half_width) - 0.5f ||
        hy > float(arguments.half_height) - 0.5f) return float4(0.0f);
    const int x0 = int(floor(hx));
    const int y0 = int(floor(hy));
    const float tx = clamp(hx - float(x0), 0.0f, 1.0f);
    const float ty = clamp(hy - float(y0), 0.0f, 1.0f);
    const int max_x = int(arguments.half_width) - 1;
    const int max_y = int(arguments.half_height) - 1;
    const int ax = clamp(x0, 0, max_x);
    const int ay = clamp(y0, 0, max_y);
    const int bx = clamp(x0 + 1, 0, max_x);
    const int by = clamp(y0 + 1, 0, max_y);
    const float4 p00 = half_source[uint(ay) * arguments.half_width + uint(ax)];
    const float4 p10 = half_source[uint(ay) * arguments.half_width + uint(bx)];
    const float4 p01 = half_source[uint(by) * arguments.half_width + uint(ax)];
    const float4 p11 = half_source[uint(by) * arguments.half_width + uint(bx)];
    return mix(mix(p00, p10, tx), mix(p01, p11, tx), ty);
}

kernel void cbef_lens_finalize_v2(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                                  const device float2* mattes [[buffer(2)]], const device float4* half_source [[buffer(3)]],
                                  const device LensCandidate* candidates [[buffer(4)]],
                                  const device LensElementGpu* elements [[buffer(5)]],
                                  const device float4* denominators [[buffer(6)]],
                                  constant LensV2Arguments& arguments [[buffer(7)]],
                                  uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x * arguments.projection_downsample);
    const int y = arguments.window_y + int(position.y * arguments.projection_downsample);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes + uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = arguments.projection_downsample == 1u
                                      ? (uint(y - arguments.data_y) * arguments.destination_row_bytes + uint(x - arguments.data_x) * 16u) / 4u
                                      : (position.y * arguments.destination_row_bytes + position.x * 16u) / 4u;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    const float3 original = to_dwg(encoded, arguments.working_mode);
    const uint pixel_index = uint(y - arguments.data_y) * uint(arguments.width) + uint(x - arguments.data_x);
    const float3 background_value = lens_analysis_rgb(original, arguments);
    float3 raw = float3(0.0f);
    float path = 0.0f;
    for (uint source_index = 0u; source_index < 8u; ++source_index) {
        const LensCandidate candidate = candidates[8u + source_index];
        if (candidate.valid == 0u) continue;
        for (uint element_index = 0u; element_index < 5u; ++element_index) {
            if (arguments.element_solo > 0 && uint(arguments.element_solo - 1) != element_index) continue;
            const LensElementGpu element = elements[element_index];
            const float spread = arguments.spread / 100.0f;
            const float gx = arguments.center_x + element.axis_position * spread * (candidate.x - arguments.center_x);
            const float gy = arguments.center_y + element.axis_position * spread * (candidate.y - arguments.center_y);
            if (arguments.diagnostic_view == 10u) {
                const float2 segment = float2(gx - candidate.x, gy - candidate.y);
                const float segment_length2 = dot(segment, segment);
                if (segment_length2 > 1.0e-8f) {
                    const float t = clamp(dot(float2(float(x) - candidate.x, float(y) - candidate.y), segment) / segment_length2, 0.0f, 1.0f);
                    if (length(float2(float(x), float(y)) - (float2(candidate.x, candidate.y) + t * segment)) <= 0.75f)
                        path += element.energy * min(1.0f, candidate.energy);
                }
                continue;
            }
            float3 element_value = float3(0.0f);
            const float4 denominator = denominators[source_index * 5u + element_index];
            if (element.shape == 0u && arguments.use_half_source != 0u) {
                const float sx = candidate.x + (float(x) - gx) / max(element.magnification, 1.0e-4f);
                const float sy = candidate.y + (float(y) - gy) / max(element.magnification, 1.0e-4f);
                const float reach = max(4.0f, candidate.radius * 2.8f);
                if (fabs(sx - candidate.x) > reach || fabs(sy - candidate.y) > reach ||
                    length(float2(sx - candidate.x, sy - candidate.y)) > reach) continue;
                const float4 sample = lens_sample_half(half_source, sx, sy, arguments);
                const float area = max(element.magnification * element.magnification, 0.25f);
                element_value = sample.rgb * lens_tint_gain(element, arguments) * element.energy / area;
            } else if (element.shape == 0u && denominator.w > 1.0e-9f) {
                const float reach = max(4.0f, candidate.radius * 2.8f);
                const float sigma_y = float(arguments.height) * (arguments.blur + element.defocus * (1.0f - 0.65f * element.pattern_retention)) / 100.0f;
                const float sigma_x = sigma_y * max(arguments.anamorphism, 0.01f);
                const float mapped_reach = reach * max(element.magnification, 0.0f);
                if (fabs(float(x) - gx) > mapped_reach + ceil(3.0f * sigma_x) + 1.0f ||
                    fabs(float(y) - gy) > mapped_reach + ceil(3.0f * sigma_y) + 1.0f) continue;
                const int x0 = max(arguments.data_x, int(floor(candidate.x - reach)));
                const int x1 = min(arguments.data_x + arguments.width - 1, int(ceil(candidate.x + reach)));
                const int y0 = max(arguments.data_y, int(floor(candidate.y - reach)));
                const int y1 = min(arguments.data_y + arguments.height - 1, int(ceil(candidate.y + reach)));
                float3 focused = float3(0.0f);
                for (int sy = y0; sy <= y1; ++sy) {
                    for (int sx = x0; sx <= x1; ++sx) {
                        if (length(float2(float(sx) - candidate.x, float(sy) - candidate.y)) > reach) continue;
                        const uint source_index_full = uint(sy - arguments.data_y) * uint(arguments.width) + uint(sx - arguments.data_x);
                        const float source_matte = mattes[source_index_full].y;
                        if (source_matte <= 0.0f) continue;
                        float source_alpha = 0.0f;
                        const float3 source_original = lens_source_rgb(source, sx, sy, arguments, source_alpha);
                        const float3 source_value = lens_analysis_rgb(source_original, arguments) * source_matte * source_alpha;
                        const float mx = gx + element.magnification * (float(sx) - candidate.x);
                        const float my = gy + element.magnification * (float(sy) - candidate.y);
                        focused += source_value * lens_axis_response(mx, x, sigma_x) * lens_axis_response(my, y, sigma_y);
                    }
                }
                element_value = focused * lens_tint_gain(element, arguments) *
                                (candidate.energy * element.energy / denominator.w);
            } else if (element.shape != 0u) {
                float ry = max(1.25f, candidate.radius * element.magnification + float(arguments.height) * (element.defocus + arguments.blur) / 100.0f);
                if (element.shape == 3u) ry *= 2.2f;
                const float rx = ry * max(0.25f, arguments.anamorphism) * (element.shape == 4u ? max(1.0f, element.streak_aspect) : 1.0f);
                const float support = element.shape == 3u || element.shape == 4u ? 3.2f : 1.15f;
                const float dispersion = element.dispersion * clamp(arguments.chroma / 100.0f, 0.0f, 1.0f) * ry * 0.35f;
                if (fabs(float(x) - gx) > support * rx + dispersion ||
                    fabs(float(y) - gy) > support * ry + dispersion) continue;
                const float axis_length = length(float2(candidate.x - arguments.center_x, candidate.y - arguments.center_y));
                const float2 axis = axis_length > 1.0e-6f ? float2(candidate.x - arguments.center_x, candidate.y - arguments.center_y) / axis_length : float2(1.0f, 0.0f);
                const float3 weight = float3(
                    lens_element_weight(element, float(x) - gx + dispersion * axis.x, float(y) - gy + dispersion * axis.y, rx, ry, arguments.lens_model),
                    lens_element_weight(element, float(x) - gx, float(y) - gy, rx, ry, arguments.lens_model),
                    lens_element_weight(element, float(x) - gx - dispersion * axis.x, float(y) - gy - dispersion * axis.y, rx, ry, arguments.lens_model));
                const float candidate_luma = max(luminance(float3(candidate.red, candidate.green, candidate.blue)), 1.0e-9f);
                float3 target = float3(candidate.red, candidate.green, candidate.blue) / candidate_luma *
                                lens_tint_gain(element, arguments);
                target *= candidate.energy * element.energy / max(luminance(target), 1.0e-9f);
                element_value = target * weight / max(denominator.rgb, float3(1.0e-20f));
            }
            const float adaptation = 1.0f / (1.0f + clamp(arguments.background_adaptation / 100.0f, 0.0f, 1.0f) *
                                             element.background_falloff * luminance(background_value));
            raw += element_value * adaptation;
        }
    }
    const float source_weight = lens_uses_direct_source_matte(arguments) ? 0.0f : mattes[pixel_index].y;
    const float local_adaptation = 1.0f / (1.0f + clamp(arguments.background_adaptation / 100.0f, 0.0f, 1.0f) * luminance(original));
    const float3 contribution = raw * (arguments.amount / 100.0f) * local_adaptation +
                                original * clamp(arguments.veil / 100.0f, 0.0f, 1.0f) * source_weight * 0.05f * local_adaptation;
    if (arguments.projection_downsample > 1u) {
        const float3 projected_contribution = contribution * arguments.mix;
        destination[destination_word + 0u] = as_type<uint>(projected_contribution.r);
        destination[destination_word + 1u] = as_type<uint>(projected_contribution.g);
        destination[destination_word + 2u] = as_type<uint>(projected_contribution.b);
        destination[destination_word + 3u] = 0u;
        return;
    }
    float3 result = float3(0.0f);
    if (arguments.diagnostic_view == 0u) result = original + contribution * arguments.mix;
    else if (arguments.diagnostic_view == 1u || arguments.diagnostic_view == 11u || arguments.diagnostic_view == 12u) result = contribution;
    else if (arguments.diagnostic_view == 10u) result = float3(path);
    else {
        float diagnostic = source_weight;
        if (arguments.diagnostic_view == 9u || arguments.diagnostic_view == 13u) {
            const uint offset = arguments.diagnostic_view == 9u ? 0u : 8u;
            diagnostic = arguments.diagnostic_view == 9u ? mattes[pixel_index].x : mattes[pixel_index].y;
            if (arguments.source_mode == 0) {
                bool selected = false;
                for (uint candidate_index = 0u; candidate_index < 8u; ++candidate_index) {
                    const LensCandidate candidate = candidates[offset + candidate_index];
                    if (candidate.valid == 0u) continue;
                    const float candidate_x = round(candidate.x * 16.0f) / 16.0f;
                    const float candidate_y = round(candidate.y * 16.0f) / 16.0f;
                    const float candidate_radius = round(candidate.radius * 16.0f) / 16.0f;
                    const float reach = max(8.0f, candidate_radius * 2.0f + 2.0f);
                    selected = selected || length(float2(float(x) - candidate_x, float(y) - candidate_y)) <= reach;
                }
                if (!selected) diagnostic = 0.0f;
            }
        }
        result = float3(diagnostic);
    }
    float3 output = from_dwg(result, arguments.working_mode);
    if (arguments.alpha_association == 1u) output *= alpha;
    destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}

kernel void cbef_lens_upscale_v2(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                                 const device float4* projected [[buffer(2)]],
                                 constant LensV2Arguments& arguments [[buffer(3)]],
                                 uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const int x = arguments.data_x + int(position.x);
    const int y = arguments.data_y + int(position.y);
    const uint source_word = (position.y * arguments.source_row_bytes + position.x * 16u) / 4u;
    const uint destination_word = (position.y * arguments.destination_row_bytes + position.x * 16u) / 4u;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    const float px = float(position.x) / float(arguments.projection_downsample);
    const float py = float(position.y) / float(arguments.projection_downsample);
    const int x0 = int(floor(px));
    const int y0 = int(floor(py));
    const float tx = px - float(x0);
    const float ty = py - float(y0);
    const int max_x = int(arguments.projection_width) - 1;
    const int max_y = int(arguments.projection_height) - 1;
    const int ax = clamp(x0, 0, max_x);
    const int ay = clamp(y0, 0, max_y);
    const int bx = clamp(x0 + 1, 0, max_x);
    const int by = clamp(y0 + 1, 0, max_y);
    const float4 p00 = projected[uint(ay) * arguments.projection_width + uint(ax)];
    const float4 p10 = projected[uint(ay) * arguments.projection_width + uint(bx)];
    const float4 p01 = projected[uint(by) * arguments.projection_width + uint(ax)];
    const float4 p11 = projected[uint(by) * arguments.projection_width + uint(bx)];
    const float3 contribution = mix(mix(p00.rgb, p10.rgb, tx), mix(p01.rgb, p11.rgb, tx), ty);
    float3 encoded = float3(as_type<float>(source[source_word]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    const float3 result = to_dwg(encoded, arguments.working_mode) + contribution;
    float3 output = from_dwg(result, arguments.working_mode);
    if (arguments.alpha_association == 1u) output *= alpha;
    destination[destination_word] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
    (void)x;
    (void)y;
}

kernel void cbef_copy_v2(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                          constant CopyArguments& arguments [[buffer(2)]],
                          uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) {
        return;
    }
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes +
                              uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.data_y) * arguments.destination_row_bytes +
                                   uint(x - arguments.data_x) * 16u) / 4u;
    destination[destination_word + 0u] = source[source_word + 0u];
    destination[destination_word + 1u] = source[source_word + 1u];
    destination[destination_word + 2u] = source[source_word + 2u];
    destination[destination_word + 3u] = source[source_word + 3u];
}

float halation_luminance(float3 value) {
    const float3 positive = max(value, float3(0.0f));
    return max(0.0f, 0.27411851f * positive.r + 0.87363190f * positive.g - 0.14775041f * positive.b);
}

float halation_smoothstep(float lower, float upper, float value) {
    if (value <= lower) return 0.0f;
    if (value >= upper) return 1.0f;
    const float t = (value - lower) / (upper - lower);
    return t * t * (3.0f - 2.0f * t);
}

float halation_matte(float3 original, float alpha, constant HalationArguments& arguments) {
    if (alpha <= 1.0e-6f) return 0.0f;
    const float3 positive_source = max(original, float3(0.0f));
    const float max_rgb = max(positive_source.r, max(positive_source.g, positive_source.b));
    const float luminance_value = max(halation_luminance(positive_source), max_rgb * 0.42f);
    if (arguments.highlights_only == 0u) return luminance_value > 0.0f ? 1.0f : 0.0f;
    const float stops = log2(max(luminance_value, 0x1p-16f) / 0.18f);
    const float knee = 0.08f + clamp(arguments.source_smoothness / 100.0f, 0.0f, 1.0f) * 1.92f;
    return halation_smoothstep(arguments.threshold - knee, arguments.threshold + knee, stops);
}

float3 halation_colorize(float3 raw, constant HalationArguments& arguments) {
    const float red_bias = clamp(arguments.red_bias / 100.0f, 0.0f, 1.0f);
    const float blue_compensation = clamp(arguments.blue_compensation / 100.0f, 0.0f, 1.0f);
    const float3 profiled = raw * float3(0.65f + 0.70f * red_bias,
                                         0.95f - 0.15f * red_bias,
                                         0.65f + 0.85f * blue_compensation);
    constexpr float3 generic_warm_tint = float3(1.0f, 0.58f, 0.28f);
    constexpr float generic_warm_luminance = 0.27411851f + 0.87363190f * 0.58f - 0.14775041f * 0.28f;
    const float raw_luminance = max(halation_luminance(profiled), 0.0f);
    const float3 warm_target = raw_luminance * generic_warm_tint / generic_warm_luminance;
    const float warm_mix = clamp(arguments.warmth / 100.0f * 0.70f, 0.0f, 0.70f);
    const float3 warmed = profiled + (warm_target - profiled) * warm_mix;
    const float warm_luminance = halation_luminance(warmed);
    const float3 profile_relative = warm_luminance + (warmed - warm_luminance) * (arguments.saturation / 100.0f);
    if (arguments.color_emphasis_mix <= 0.0f) return profile_relative;
    const float profile_luminance = halation_luminance(profile_relative);
    float3 target_chroma = float3(arguments.color_target_r, arguments.color_target_g, arguments.color_target_b);
    if (arguments.color_mode == 2u) {
        const float total = max(raw.r + raw.g + raw.b, 1.0e-6f);
        const float3 normalized = clamp(raw / total, 0.0f, 1.0f);
        const float warm_weight = halation_smoothstep(0.24f, 0.48f, normalized.r - normalized.b) *
                                  halation_smoothstep(0.12f, 0.20f, normalized.g - normalized.b);
        const float cool_weight = halation_smoothstep(
            0.30f, 0.55f, max(normalized.b - normalized.r, normalized.g - normalized.r));
        const float amber_weight = (1.0f - cool_weight) * warm_weight;
        const float red_weight = 1.0f - cool_weight - amber_weight;
        target_chroma = red_weight * float3(1.0f, 0.16f, 0.04f) +
                        amber_weight * float3(1.0f, 0.55f, 0.12f) + cool_weight;
        const float target_luminance = max(
            0.27411851f * target_chroma.r + 0.87363190f * target_chroma.g - 0.14775041f * target_chroma.b,
            1.0e-6f);
        target_chroma /= target_luminance;
    }
    const float3 target = profile_luminance * target_chroma;
    return profile_relative + (target - profile_relative) * arguments.color_emphasis_mix;
}

kernel void cbef_halation_prepare(const device uint* source [[buffer(0)]], device float4* samples [[buffer(1)]],
                                   constant HalationArguments& arguments [[buffer(2)]],
                                   uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const int x = arguments.data_x + int(position.x);
    const int y = arguments.data_y + int(position.y);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes + uint(x - arguments.data_x) * 16u) / 4u;
    const uint sample_index = position.y * uint(arguments.width) + position.x;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        samples[sample_index] = float4(0.0f);
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    const float3 original = to_dwg(encoded, arguments.working_mode);
    const float matte = halation_matte(original, alpha, arguments);
    const float3 positive = max(original, float3(0.0f));
    samples[sample_index] = float4(positive * matte, max(0.0f, alpha));
}

kernel void cbef_halation_horizontal(const device float4* source [[buffer(0)]], device float4* destination [[buffer(1)]],
                                      const device float* weights [[buffer(2)]], constant HalationArguments& arguments [[buffer(3)]],
                                      uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const int radius = int(arguments.horizontal_radius);
    float4 value = float4(0.0f);
    for (int tap = -radius; tap <= radius; ++tap) {
        const int sample_x = clamp(int(position.x) + tap, 0, arguments.width - 1);
        const float4 input = source[position.y * uint(arguments.width) + uint(sample_x)];
        const float weight = weights[uint(tap + radius)];
        value.rgb += input.rgb * input.a * weight;
        value.a += input.a * weight;
    }
    destination[position.y * uint(arguments.width) + position.x] = value;
}

kernel void cbef_halation_horizontal_linear(texture2d<float, access::sample> source [[texture(0)]],
                                             device float4* destination [[buffer(0)]],
                                             const device GaussianPair* pairs [[buffer(1)]],
                                             constant HalationArguments& arguments [[buffer(2)]],
                                             uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const uint width = uint(arguments.width);
    const float2 center = float2(position) + 0.5f;
    const GaussianPair center_pair = pairs[0u];
    const float4 center_value = source.sample(cbef_linear_sampler, center);
    float channel_value = center_value[arguments.channel] * center_value.a * center_pair.weight;
    float alpha_value = center_value.a * center_pair.weight;
    const uint pair_count = (arguments.horizontal_radius + 1u) / 2u;
    for (uint pair_index = 0u; pair_index < pair_count; ++pair_index) {
        const GaussianPair pair = pairs[pair_index + 1u];
        const float4 positive = source.sample(cbef_linear_sampler, center + float2(pair.offset, 0.0f));
        const float4 negative = source.sample(cbef_linear_sampler, center - float2(pair.offset, 0.0f));
        channel_value += (positive[arguments.channel] * positive.a + negative[arguments.channel] * negative.a) * pair.weight;
        alpha_value += (positive.a + negative.a) * pair.weight;
    }
    destination[position.y * width + position.x] = float4(arguments.channel == 0u ? channel_value : 0.0f,
                                                          arguments.channel == 1u ? channel_value : 0.0f,
                                                          arguments.channel == 2u ? channel_value : 0.0f,
                                                          alpha_value);
}

kernel void cbef_halation_horizontal_multi_buffer(texture2d<float, access::sample> source [[texture(0)]],
                                                  texture2d<float, access::write> scratch0 [[texture(1)]],
                                                  texture2d<float, access::write> scratch1 [[texture(2)]],
                                                  texture2d<float, access::write> scratch2 [[texture(3)]],
                                                  const device GaussianPair* pairs [[buffer(0)]],
                                                  constant HalationFusedArguments& arguments [[buffer(1)]],
                                                  uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.base.width) || position.y >= uint(arguments.base.height)) return;
    const float2 center = float2(position) + 0.5f;
    for (uint scale = 0u; scale < 3u; ++scale) {
        const device GaussianPair* scale_pairs = pairs + arguments.pair_offsets[scale];
        const GaussianPair center_pair = scale_pairs[0u];
        const float4 center_value = source.sample(cbef_linear_sampler, center, 0u);
        float4 value = float4(center_value.rgb * center_value.a * center_pair.weight,
                              center_value.a * center_pair.weight);
        for (uint pair_index = 0u; pair_index < arguments.pair_counts[scale]; ++pair_index) {
            const GaussianPair pair = scale_pairs[pair_index + 1u];
            const float4 positive = source.sample(cbef_linear_sampler, center + float2(pair.offset, 0.0f), 0u);
            const float4 negative = source.sample(cbef_linear_sampler, center - float2(pair.offset, 0.0f), 0u);
            value.rgb += (positive.rgb * positive.a + negative.rgb * negative.a) * pair.weight;
            value.a += (positive.a + negative.a) * pair.weight;
        }
        if (scale == 0u) scratch0.write(value, position);
        else if (scale == 1u) scratch1.write(value, position);
        else scratch2.write(value, position);
    }
}

kernel void cbef_halation_vertical(const device float4* source [[buffer(0)]], device float4* halo [[buffer(1)]],
                                    const device float4* original [[buffer(2)]], const device float* weights [[buffer(3)]],
                                    constant HalationArguments& arguments [[buffer(4)]], uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const int radius = int(arguments.vertical_radius);
    float blurred = 0.0f;
    float blurred_alpha = 0.0f;
    for (int tap = -radius; tap <= radius; ++tap) {
        const int sample_y = clamp(y - arguments.data_y + tap, 0, arguments.height - 1);
        const float4 input = source[uint(sample_y) * uint(arguments.width) + uint(x - arguments.data_x)];
        const float weight = weights[uint(tap + radius)];
        blurred += input[arguments.channel] * weight;
        blurred_alpha += input.a * weight;
    }
    const float4 source_value = original[uint(y - arguments.data_y) * uint(arguments.width) + uint(x - arguments.data_x)];
    const float value = max(blurred / max(blurred_alpha, 1.0e-6f) - source_value[arguments.channel], 0.0f);
    const uint index = position.y * arguments.render_width + position.x;
    halo[index][arguments.channel] += value * arguments.scale_weight;
}

kernel void cbef_halation_vertical_linear(texture2d<float, access::sample> source [[texture(0)]],
                                           device float4* halo [[buffer(0)]],
                                           const device float4* original [[buffer(1)]],
                                           const device GaussianPair* pairs [[buffer(2)]],
                                           constant HalationArguments& arguments [[buffer(3)]],
                                           uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const float2 center = float2(x - arguments.data_x, y - arguments.data_y) + 0.5f;
    const GaussianPair center_pair = pairs[0u];
    float blurred = source.sample(cbef_linear_sampler, center)[arguments.channel] * center_pair.weight;
    float blurred_alpha = source.sample(cbef_linear_sampler, center).a * center_pair.weight;
    const uint pair_count = (arguments.vertical_radius + 1u) / 2u;
    for (uint pair_index = 0u; pair_index < pair_count; ++pair_index) {
        const GaussianPair pair = pairs[pair_index + 1u];
        const float4 positive = source.sample(cbef_linear_sampler, center + float2(0.0f, pair.offset));
        const float4 negative = source.sample(cbef_linear_sampler, center - float2(0.0f, pair.offset));
        blurred += (positive[arguments.channel] + negative[arguments.channel]) * pair.weight;
        blurred_alpha += (positive.a + negative.a) * pair.weight;
    }
    const float4 source_value = original[uint(y - arguments.data_y) * uint(arguments.width) + uint(x - arguments.data_x)];
    const float value = max(blurred / max(blurred_alpha, 1.0e-6f) - source_value[arguments.channel], 0.0f);
    const uint index = position.y * arguments.render_width + position.x;
    halo[index][arguments.channel] += value * arguments.scale_weight;
}

kernel void cbef_halation_vertical_final_buffer(texture2d<float, access::sample> scratch0 [[texture(0)]],
                                                texture2d<float, access::sample> scratch1 [[texture(1)]],
                                                texture2d<float, access::sample> scratch2 [[texture(2)]],
                                                texture2d<float, access::sample> samples [[texture(3)]],
                                                const device uint* source [[buffer(0)]],
                                                device uint* destination [[buffer(1)]],
                                                const device GaussianPair* pairs [[buffer(2)]],
                                                constant HalationFusedArguments& arguments [[buffer(3)]],
                                                uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.base.render_width || position.y >= arguments.base.render_height) return;
    const HalationArguments base = arguments.base;
    const int x = base.window_x + int(position.x);
    const int y = base.window_y + int(position.y);
    const float2 center = float2(x - base.data_x, y - base.data_y) + 0.5f;
    float3 total = float3(0.0f);
    for (uint scale = 0u; scale < 3u; ++scale) {
        const device GaussianPair* scale_pairs = pairs + arguments.vertical_pair_offsets[scale];
        const GaussianPair center_pair = scale_pairs[0u];
        const float4 center_value = scale == 0u ? scratch0.sample(cbef_linear_sampler, center) :
                                      (scale == 1u ? scratch1.sample(cbef_linear_sampler, center) :
                                                     scratch2.sample(cbef_linear_sampler, center));
        float4 blurred = center_value * center_pair.weight;
        for (uint pair_index = 0u; pair_index < arguments.vertical_pair_counts[scale]; ++pair_index) {
            const GaussianPair pair = scale_pairs[pair_index + 1u];
            const float4 positive = scale == 0u ? scratch0.sample(cbef_linear_sampler, center + float2(0.0f, pair.offset)) :
                                      (scale == 1u ? scratch1.sample(cbef_linear_sampler, center + float2(0.0f, pair.offset)) :
                                                     scratch2.sample(cbef_linear_sampler, center + float2(0.0f, pair.offset)));
            const float4 negative = scale == 0u ? scratch0.sample(cbef_linear_sampler, center - float2(0.0f, pair.offset)) :
                                      (scale == 1u ? scratch1.sample(cbef_linear_sampler, center - float2(0.0f, pair.offset)) :
                                                     scratch2.sample(cbef_linear_sampler, center - float2(0.0f, pair.offset)));
            blurred += (positive + negative) * pair.weight;
        }
        const float3 source_value = samples.sample(cbef_linear_sampler, center).rgb;
        total += max(blurred.rgb / max(blurred.a, 1.0e-6f) - source_value, float3(0.0f)) *
                 arguments.scale_weights[scale];
    }
    const uint source_word = (uint(y - base.data_y) * base.source_row_bytes + uint(x - base.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - base.data_y) * base.destination_row_bytes + uint(x - base.data_x) * 16u) / 4u;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (base.alpha_association == 1u) encoded /= alpha;
    const float3 original_value = to_dwg(encoded, base.working_mode);
    const float3 colored = halation_colorize(total, arguments.base);
    const float3 positive_original = max(original_value, float3(0.0f));
    const float background = max(halation_luminance(positive_original), 0.0f);
    const float background_visibility = max(0.0f, 1.0f - base.background_adaptation / 100.0f *
                                           halation_smoothstep(0.32f, 2.0f, background));
    const float source_matte = halation_matte(original_value, alpha, arguments.base);
    const float local_visibility = max(0.0f, background_visibility *
                                      (1.0f - base.core_protection / 100.0f * source_matte));
    const float global_visibility = max(0.0f, background_visibility *
                                       (1.0f - base.core_protection / 100.0f * 0.65f * source_matte));
    const float3 component = colored * (base.amount / 100.0f);
    const float3 local_component = component * local_visibility;
    const float3 global_component = component * 0.35f * global_visibility;
    const float3 total_component = local_component + global_component;
    float3 result = original_value;
    if (base.diagnostic_view == 0u) result = original_value + total_component * base.mix;
    else if (base.diagnostic_view == 1u) result = total_component;
    else if (base.diagnostic_view == 4u) result = global_component;
    else if (base.diagnostic_view == 5u) result = local_component;
    else {
        result = float3(source_matte);
    }
    float3 output = from_dwg(result, base.working_mode);
    if (base.alpha_association == 1u) output *= alpha;
    destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}

kernel void cbef_halation_matte(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                                constant HalationArguments& arguments [[buffer(2)]],
                                uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes + uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.data_y) * arguments.destination_row_bytes + uint(x - arguments.data_x) * 16u) / 4u;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    const float matte = halation_matte(to_dwg(encoded, arguments.working_mode), alpha, arguments);
    float3 output = from_dwg(float3(matte), arguments.working_mode);
    if (arguments.alpha_association == 1u) output *= alpha;
    destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}

kernel void cbef_halation_pyramid_prepare_rg32(const device uint* source [[buffer(0)]],
                                                device float2* samples [[buffer(1)]],
                                                constant HalationPyramidRG32Arguments& arguments [[buffer(2)]],
                                                uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.level_width || position.y >= arguments.level_height) return;
    const uint factor = max(arguments.downsample, 1u);
    float3 numerator = float3(0.0f);
    float alpha_sum = 0.0f;
    float sample_count = 0.0f;
    for (uint fy = 0u; fy < factor; ++fy) {
        const int source_y = min(arguments.base.height - 1, int(position.y * factor + fy));
        for (uint fx = 0u; fx < factor; ++fx) {
            const int source_x = min(arguments.base.width - 1, int(position.x * factor + fx));
            const uint word = (uint(source_y) * arguments.base.source_row_bytes + uint(source_x) * 16u) / 4u;
            const float alpha = as_type<float>(source[word + 3u]);
            if (alpha > 1.0e-6f) {
                float3 encoded = float3(as_type<float>(source[word + 0u]), as_type<float>(source[word + 1u]),
                                             as_type<float>(source[word + 2u]));
                if (arguments.base.alpha_association == 1u) encoded /= alpha;
                const float3 original = to_dwg(encoded, arguments.base.working_mode);
                const float matte = halation_matte(original, alpha, arguments.base);
                numerator += max(original, float3(0.0f)) * matte;
                alpha_sum += max(alpha, 0.0f);
            }
            sample_count += 1.0f;
        }
    }
    const float divisor = max(sample_count, 1.0f);
    const float3 normalized = numerator / divisor;
    const float alpha = alpha_sum / divisor;
    const uint row_offset = position.y * arguments.source_row_stride + position.x;
    samples[row_offset] = float2(normalized.r, alpha);
    samples[arguments.source_plane_stride + row_offset] = float2(normalized.g, alpha);
    samples[arguments.source_plane_stride * 2u + row_offset] = float2(normalized.b, alpha);
}

kernel void cbef_halation_pyramid_horizontal_rg32(texture2d<float, access::sample> source_r [[texture(0)]],
                                                   texture2d<float, access::sample> source_g [[texture(1)]],
                                                   texture2d<float, access::sample> source_b [[texture(2)]],
                                                   device float2* destination [[buffer(0)]],
                                                   const device GaussianPair* pairs [[buffer(1)]],
                                                   constant HalationPyramidRG32Arguments& arguments [[buffer(2)]],
                                                   uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.level_width || position.y >= arguments.level_height) return;
    const float2 center = float2(position) + 0.5f;
    for (uint channel = 0u; channel < 3u; ++channel) {
        const device GaussianPair* channel_pairs = pairs + arguments.horizontal_pair_offsets[channel];
        float2 value = (channel == 0u ? source_r.sample(cbef_linear_sampler, center).rg :
                        (channel == 1u ? source_g.sample(cbef_linear_sampler, center).rg :
                                         source_b.sample(cbef_linear_sampler, center).rg)) * channel_pairs[0u].weight;
        const uint pair_count = (arguments.horizontal_radii[channel] + 1u) / 2u;
        for (uint pair_index = 0u; pair_index < pair_count; ++pair_index) {
            const GaussianPair pair = channel_pairs[pair_index + 1u];
            const float2 positive = channel == 0u ? source_r.sample(cbef_linear_sampler, center + float2(pair.offset, 0.0f)).rg :
                                    (channel == 1u ? source_g.sample(cbef_linear_sampler, center + float2(pair.offset, 0.0f)).rg :
                                                     source_b.sample(cbef_linear_sampler, center + float2(pair.offset, 0.0f)).rg);
            const float2 negative = channel == 0u ? source_r.sample(cbef_linear_sampler, center - float2(pair.offset, 0.0f)).rg :
                                    (channel == 1u ? source_g.sample(cbef_linear_sampler, center - float2(pair.offset, 0.0f)).rg :
                                                     source_b.sample(cbef_linear_sampler, center - float2(pair.offset, 0.0f)).rg);
            value += (positive + negative) * pair.weight;
        }
        destination[arguments.source_plane_stride * channel + position.y * arguments.source_row_stride + position.x] = value;
    }
}

kernel void cbef_halation_pyramid_vertical_rg32(texture2d<float, access::sample> source_r [[texture(0)]],
                                                 texture2d<float, access::sample> source_g [[texture(1)]],
                                                 texture2d<float, access::sample> source_b [[texture(2)]],
                                                 device float2* destination [[buffer(0)]],
                                                 const device GaussianPair* pairs [[buffer(1)]],
                                                 constant HalationPyramidRG32Arguments& arguments [[buffer(2)]],
                                                 uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.level_width || position.y >= arguments.level_height) return;
    const float2 center = float2(position) + 0.5f;
    for (uint channel = 0u; channel < 3u; ++channel) {
        const device GaussianPair* channel_pairs = pairs + arguments.vertical_pair_offsets[channel];
        float2 value = (channel == 0u ? source_r.sample(cbef_linear_sampler, center).rg :
                        (channel == 1u ? source_g.sample(cbef_linear_sampler, center).rg :
                                         source_b.sample(cbef_linear_sampler, center).rg)) * channel_pairs[0u].weight;
        const uint pair_count = (arguments.vertical_radii[channel] + 1u) / 2u;
        for (uint pair_index = 0u; pair_index < pair_count; ++pair_index) {
            const GaussianPair pair = channel_pairs[pair_index + 1u];
            const float2 positive = channel == 0u ? source_r.sample(cbef_linear_sampler, center + float2(0.0f, pair.offset)).rg :
                                    (channel == 1u ? source_g.sample(cbef_linear_sampler, center + float2(0.0f, pair.offset)).rg :
                                                     source_b.sample(cbef_linear_sampler, center + float2(0.0f, pair.offset)).rg);
            const float2 negative = channel == 0u ? source_r.sample(cbef_linear_sampler, center - float2(0.0f, pair.offset)).rg :
                                    (channel == 1u ? source_g.sample(cbef_linear_sampler, center - float2(0.0f, pair.offset)).rg :
                                                     source_b.sample(cbef_linear_sampler, center - float2(0.0f, pair.offset)).rg);
            value += (positive + negative) * pair.weight;
        }
        destination[arguments.output_plane_stride * channel + position.y * arguments.output_row_stride + position.x] = value;
    }
}

kernel void cbef_halation_pyramid_composite(
    texture2d<float, access::sample> scale0_r [[texture(0)]], texture2d<float, access::sample> scale0_g [[texture(1)]],
    texture2d<float, access::sample> scale0_b [[texture(2)]], texture2d<float, access::sample> scale1_r [[texture(3)]],
    texture2d<float, access::sample> scale1_g [[texture(4)]], texture2d<float, access::sample> scale1_b [[texture(5)]],
    texture2d<float, access::sample> scale2_r [[texture(6)]], texture2d<float, access::sample> scale2_g [[texture(7)]],
    texture2d<float, access::sample> scale2_b [[texture(8)]], const device uint* source [[buffer(0)]],
    device uint* destination [[buffer(1)]], constant HalationPyramidCompositeArguments& arguments [[buffer(2)]],
    uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.base.render_width || position.y >= arguments.base.render_height) return;
    const bool global = arguments.global_branch != 0u;
    if ((arguments.base.diagnostic_view == 5u && global) ||
        (arguments.base.diagnostic_view == 4u && !global) ||
        (arguments.base.diagnostic_view == 2u && global)) return;
    const int x = arguments.base.window_x + int(position.x);
    const int y = arguments.base.window_y + int(position.y);
    const uint source_word = (uint(y - arguments.base.data_y) * arguments.base.source_row_bytes +
                              uint(x - arguments.base.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.base.data_y) * arguments.base.destination_row_bytes +
                                   uint(x - arguments.base.data_x) * 16u) / 4u;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.base.alpha_association == 1u) encoded /= alpha;
    const float3 original = to_dwg(encoded, arguments.base.working_mode);
    const float3 positive = max(original, float3(0.0f));
    const float matte = halation_matte(original, alpha, arguments.base);
    const float2 center0 = (float2(x - arguments.base.data_x, y - arguments.base.data_y) + 0.5f) /
                           float(arguments.downsample[0]);
    const float2 center1 = (float2(x - arguments.base.data_x, y - arguments.base.data_y) + 0.5f) /
                           float(arguments.downsample[1]);
    const float2 center2 = (float2(x - arguments.base.data_x, y - arguments.base.data_y) + 0.5f) /
                           float(arguments.downsample[2]);
    const float2 s0r = scale0_r.sample(cbef_linear_sampler, center0).rg;
    const float2 s0g = scale0_g.sample(cbef_linear_sampler, center0).rg;
    const float2 s0b = scale0_b.sample(cbef_linear_sampler, center0).rg;
    const float2 s1r = scale1_r.sample(cbef_linear_sampler, center1).rg;
    const float2 s1g = scale1_g.sample(cbef_linear_sampler, center1).rg;
    const float2 s1b = scale1_b.sample(cbef_linear_sampler, center1).rg;
    const float2 s2r = scale2_r.sample(cbef_linear_sampler, center2).rg;
    const float2 s2g = scale2_g.sample(cbef_linear_sampler, center2).rg;
    const float2 s2b = scale2_b.sample(cbef_linear_sampler, center2).rg;
    const float3 blurred0 = float3(s0r.x / max(s0r.y, 1.0e-6f), s0g.x / max(s0g.y, 1.0e-6f),
                                   s0b.x / max(s0b.y, 1.0e-6f));
    const float3 blurred1 = float3(s1r.x / max(s1r.y, 1.0e-6f), s1g.x / max(s1g.y, 1.0e-6f),
                                   s1b.x / max(s1b.y, 1.0e-6f));
    const float3 blurred2 = float3(s2r.x / max(s2r.y, 1.0e-6f), s2g.x / max(s2g.y, 1.0e-6f),
                                   s2b.x / max(s2b.y, 1.0e-6f));
    const float3 raw = max(blurred0 - positive, float3(0.0f)) * 0.50f +
                       max(blurred1 - positive, float3(0.0f)) * 0.35f +
                       max(blurred2 - positive, float3(0.0f)) * 0.15f;
    const float3 global_raw = max(blurred0 - positive, float3(0.0f)) * 0.52f +
                              max(blurred1 - positive, float3(0.0f)) * 0.32f +
                              max(blurred2 - positive, float3(0.0f)) * 0.16f;
    const float3 colored = halation_colorize(global ? global_raw : raw, arguments.base);
    const float background = max(halation_luminance(positive), 0.0f);
    const float visibility = max(0.0f, 1.0f - arguments.base.background_adaptation / 100.0f *
                                halation_smoothstep(0.32f, 2.0f, background));
    const float local_visibility = max(0.0f, visibility *
                                      (1.0f - arguments.base.core_protection / 100.0f * matte));
    const float global_visibility = max(0.0f, visibility *
                                       (1.0f - arguments.base.core_protection / 100.0f * 0.65f * matte));
    const float3 component = colored * (arguments.base.amount / 100.0f) *
                             (global ? 0.35f * global_visibility : local_visibility);
    float3 result = original;
    if (arguments.base.diagnostic_view == 0u) {
        if (arguments.initialize == 0u) {
            float3 prior = float3(as_type<float>(destination[destination_word + 0u]),
                                  as_type<float>(destination[destination_word + 1u]),
                                  as_type<float>(destination[destination_word + 2u]));
            if (arguments.base.alpha_association == 1u) prior /= alpha;
            result = to_dwg(prior, arguments.base.working_mode) + component * arguments.base.mix;
        } else {
            result = original + component * arguments.base.mix;
        }
    } else if (arguments.base.diagnostic_view == 1u ||
               (arguments.base.diagnostic_view == 5u && !global) ||
               (arguments.base.diagnostic_view == 4u && global)) {
        if (arguments.initialize == 0u) {
            float3 prior = float3(as_type<float>(destination[destination_word + 0u]),
                                  as_type<float>(destination[destination_word + 1u]),
                                  as_type<float>(destination[destination_word + 2u]));
            if (arguments.base.alpha_association == 1u) prior /= alpha;
            result = to_dwg(prior, arguments.base.working_mode) + component;
        } else {
            result = component;
        }
    } else if (arguments.base.diagnostic_view == 2u) {
        result = float3(matte);
    }
    float3 output = from_dwg(result, arguments.base.working_mode);
    if (arguments.base.alpha_association == 1u) output *= alpha;
    destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}

kernel void cbef_halation_finalize(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                                    const device float4* halo [[buffer(2)]], const device float4* global_halo [[buffer(3)]],
                                    constant HalationArguments& arguments [[buffer(4)]],
                                    uint2 position [[thread_position_in_grid]]) {
    if (position.x >= arguments.render_width || position.y >= arguments.render_height) return;
    const int x = arguments.window_x + int(position.x);
    const int y = arguments.window_y + int(position.y);
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes + uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.data_y) * arguments.destination_row_bytes + uint(x - arguments.data_x) * 16u) / 4u;
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]), as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    const float3 original_value = to_dwg(encoded, arguments.working_mode);
    const uint halo_index = position.y * arguments.render_width + position.x;
    const float3 raw = halo[halo_index].rgb;
    const float3 global_raw = global_halo[halo_index].rgb;
    const float3 colored = halation_colorize(raw, arguments);
    const float3 global_colored = halation_colorize(global_raw, arguments);
    const float3 positive_original = max(original_value, float3(0.0f));
    const float background = max(halation_luminance(positive_original), 0.0f);
    const float background_visibility = max(0.0f, 1.0f - arguments.background_adaptation / 100.0f *
                                           halation_smoothstep(0.32f, 2.0f, background));
    const float source_matte = halation_matte(original_value, alpha, arguments);
    const float local_visibility = max(0.0f, background_visibility *
                                      (1.0f - arguments.core_protection / 100.0f * source_matte));
    const float global_visibility = max(0.0f, background_visibility *
                                       (1.0f - arguments.core_protection / 100.0f * 0.65f * source_matte));
    const float3 component = colored * (arguments.amount / 100.0f);
    const float3 global_component = global_colored * (arguments.amount / 100.0f * 0.35f) * global_visibility;
    const float3 local_component = component * local_visibility;
    const float3 total_component = local_component + global_component;
    float3 result = original_value;
    if (arguments.diagnostic_view == 0u) result = original_value + total_component * arguments.mix;
    else if (arguments.diagnostic_view == 1u) result = total_component;
    else if (arguments.diagnostic_view == 4u) result = global_component;
    else if (arguments.diagnostic_view == 5u) result = local_component;
    else result = float3(source_matte);
    float3 output = from_dwg(result, arguments.working_mode);
    if (arguments.alpha_association == 1u) output *= alpha;
    destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}

kernel void cbef_grain_reference_v2(const device uint* source [[buffer(0)]], device uint* destination [[buffer(1)]],
                       constant GrainArguments& arguments [[buffer(2)]],
                       uint2 position [[thread_position_in_grid]]) {
    if (position.x >= uint(arguments.width) || position.y >= uint(arguments.height)) return;
    const int x = arguments.window_x + (int)position.x;
    const int y = arguments.window_y + (int)position.y;
    const uint source_word = (uint(y - arguments.data_y) * arguments.source_row_bytes +
                              uint(x - arguments.data_x) * 16u) / 4u;
    const uint destination_word = (uint(y - arguments.data_y) * arguments.destination_row_bytes +
                                   uint(x - arguments.data_x) * 16u) / 4u;
    if (arguments.is_identity != 0u) {
        destination[destination_word + 0u] = source[source_word + 0u];
        destination[destination_word + 1u] = source[source_word + 1u];
        destination[destination_word + 2u] = source[source_word + 2u];
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    const float alpha = as_type<float>(source[source_word + 3u]);
    if (alpha <= 1.0e-6f) {
        destination[destination_word + 0u] = 0u;
        destination[destination_word + 1u] = 0u;
        destination[destination_word + 2u] = 0u;
        destination[destination_word + 3u] = source[source_word + 3u];
        return;
    }
    float3 encoded = float3(as_type<float>(source[source_word + 0u]),
                            as_type<float>(source[source_word + 1u]),
                            as_type<float>(source[source_word + 2u]));
    if (arguments.alpha_association == 1u) encoded /= alpha;
    const float3 original = to_dwg(encoded, arguments.working_mode);
    const float3 positive_source = max(original, float3(0.0f));
    const float analysis_luminance = luminance(original);
    const float exposure = log2(max(analysis_luminance, 0x1p-16f) / 0.18f) + arguments.exposure_bias;
    const float shadow_response = 1.0f - grain_smoothstep(-5.0f, -1.0f, exposure);
    const float highlight_response = grain_smoothstep(1.0f, 5.0f, exposure);
    const float midtone_response = max(0.0f, 1.0f - max(shadow_response, highlight_response));
    const float response = (arguments.shadow * shadow_response + arguments.midtone * midtone_response +
                            arguments.highlight * highlight_response) / 100.0f;
    const float processing_gain = arguments.processing_modifier == 1 ? 1.12f :
                                  arguments.processing_modifier == 2 ? 0.88f : 1.0f;
    const int stock = clamp(arguments.stock_response, 0, 2);
    const float sigma_stop = 0.08f * (arguments.amount / 100.0f) * grain_stock_rms[stock] * processing_gain * response;
    const float grain_x = ((float)(x - arguments.data_x) + 0.5f) * arguments.grain_scale;
    const float grain_y = ((float)(y - arguments.data_y) + 0.5f) * arguments.grain_scale;
    float3 component = float3(0.0f);
    for (int channel = 0; channel < 3; ++channel) {
        const float field = grain_channel_field_v2(grain_x, grain_y, arguments.format, arguments.size,
                                                   arguments.softness, channel, exposure, arguments);
        const float correlated = sigma_stop * field;
        const float source_value = positive_source[channel];
        component[channel] = source_value > 0.0f ? source_value * exp2(correlated) - source_value : 0.0f;
    }
    float3 result = original;
    if (arguments.diagnostic_view == 0u) {
        result = original + component * arguments.mix;
    } else if (arguments.diagnostic_view == 1u) {
        result = component;
    } else {
        result = float3(clamp(response / 2.0f, 0.0f, 1.0f));
    }
    float3 output = from_dwg(result, arguments.working_mode);
    if (arguments.alpha_association == 1u) output *= alpha;
    destination[destination_word + 0u] = as_type<uint>(output.r);
    destination[destination_word + 1u] = as_type<uint>(output.g);
    destination[destination_word + 2u] = as_type<uint>(output.b);
    destination[destination_word + 3u] = source[source_word + 3u];
}
