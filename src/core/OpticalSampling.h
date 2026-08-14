#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>

namespace cbef::detail {

struct OpticalSequencePoint {
    float x;
    float y;
    float weight;
};

constexpr int opticalSampleCount(int quality) noexcept
{
    return quality <= 0 ? 24 : quality == 1 ? 64 : 128;
}

inline float opticalRadicalInverse(std::size_t value) noexcept
{
    unsigned int bits = static_cast<unsigned int>(value);
    bits = (bits << 16U) | (bits >> 16U);
    bits = ((bits & 0x55555555U) << 1U) | ((bits & 0xAAAAAAAAU) >> 1U);
    bits = ((bits & 0x33333333U) << 2U) | ((bits & 0xCCCCCCCCU) >> 2U);
    bits = ((bits & 0x0F0F0F0FU) << 4U) | ((bits & 0xF0F0F0F0U) >> 4U);
    bits = ((bits & 0x00FF00FFU) << 8U) | ((bits & 0xFF00FF00U) >> 8U);
    return static_cast<float>(bits) * 0x1p-32F;
}

inline std::array<OpticalSequencePoint, 128> makeOpticalSequence(int blades, float curvature,
                                                                  float rotation_degrees)
{
    std::array<OpticalSequencePoint, 128> result{};
    constexpr float kPi = 3.14159265358979323846F;
    constexpr float kGoldenConjugate = 0.6180339887498948482F;
    const int clamped_blades = std::clamp(blades, 3, 16);
    const float sector = 2.0F * kPi / static_cast<float>(clamped_blades);
    const float curvature_mix = std::clamp(curvature / 100.0F, 0.0F, 1.0F);
    const float rotation = rotation_degrees * kPi / 180.0F;
    for (std::size_t pair = 0; pair < result.size() / 2U; ++pair) {
        const float radial = std::sqrt(opticalRadicalInverse(pair + 1U));
        const float unit = std::fmod((static_cast<float>(pair) + 0.5F) * kGoldenConjugate, 1.0F);
        const float angle = 2.0F * kPi * unit + rotation;
        const auto boundaryAt = [&](float sample_angle) {
            float polygon_angle = std::fmod(sample_angle - rotation, sector);
            if (polygon_angle < 0.0F) polygon_angle += sector;
            polygon_angle = std::abs(polygon_angle - 0.5F * sector);
            const float polygon_radius =
                std::cos(0.5F * sector) / std::max(std::cos(polygon_angle), 1.0e-6F);
            return polygon_radius * (1.0F - curvature_mix) + curvature_mix;
        };
        const float first_boundary = boundaryAt(angle);
        const float opposite_boundary = boundaryAt(angle + kPi);
        const float boundary = std::sqrt(0.5F * (first_boundary * first_boundary +
                                                 opposite_boundary * opposite_boundary));
        const float x = radial * boundary * std::cos(angle);
        const float y = radial * boundary * std::sin(angle);
        const float weight = boundary * boundary;
        result[2U * pair] = {x, y, weight};
        result[2U * pair + 1U] = {-x, -y, weight};
    }
    return result;
}

inline float opticalPyramidBlend(float radius, int* lower_level, int* upper_level) noexcept
{
    const float safe_radius = std::max(radius, 0.0F);
    if (safe_radius <= 4.0F) {
        *lower_level = 0;
        *upper_level = 0;
        return 0.0F;
    }
    if (safe_radius < 8.0F) {
        const float t = (safe_radius - 4.0F) * 0.25F;
        *lower_level = 0;
        *upper_level = 1;
        return t * t * (3.0F - 2.0F * t);
    }
    if (safe_radius < 16.0F) {
        *lower_level = 1;
        *upper_level = 1;
        return 0.0F;
    }
    if (safe_radius < 24.0F) {
        const float t = (safe_radius - 16.0F) * 0.125F;
        *lower_level = 1;
        *upper_level = 2;
        return t * t * (3.0F - 2.0F * t);
    }
    if (safe_radius < 48.0F) {
        *lower_level = 2;
        *upper_level = 2;
        return 0.0F;
    }
    if (safe_radius < 64.0F) {
        const float t = (safe_radius - 48.0F) * 0.0625F;
        *lower_level = 2;
        *upper_level = 3;
        return t * t * (3.0F - 2.0F * t);
    }
    *lower_level = 3;
    *upper_level = 3;
    return 0.0F;
}

}
