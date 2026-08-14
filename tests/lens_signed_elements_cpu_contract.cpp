#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <numeric>
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

    Frame(int width, int height, int x = 0, int y = 0)
        : bounds{x, y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + 20U)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , destination(row_bytes * static_cast<std::size_t>(height), 0xA5U) {}
};

float* pixel(std::vector<std::uint8_t>& bytes, const Frame& frame, int x, int y)
{
    return reinterpret_cast<float*>(bytes.data() + static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                    static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes);
}

const float* pixel(const std::vector<std::uint8_t>& bytes, const Frame& frame, int x, int y)
{
    return reinterpret_cast<const float*>(bytes.data() +
                                          static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                          static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes);
}

void fill(Frame& frame, float value, float alpha = 1.0F)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* p = pixel(frame.source, frame, x, y);
            p[0] = p[1] = p[2] = value;
            p[3] = alpha;
        }
    }
}

Settings lensSettings(int model = 0)
{
    Settings settings = defaultSettings(EffectId::LensReflections);
    setSetting(settings, "working_mode", 1);
    setSetting(settings, "lens_model", model);
    setSetting(settings, "source_mode", 1);
    setSetting(settings, "manual_x", 60.0);
    setSetting(settings, "manual_y", 0.0);
    setSetting(settings, "manual_size", 2.0);
    setSetting(settings, "manual_intensity", 100.0);
    setSetting(settings, "amount", 100.0);
    setSetting(settings, "spread", 65.0);
    setSetting(settings, "blur", 0.0);
    setSetting(settings, "chroma", 0.0);
    setSetting(settings, "background_adaptation", 0.0);
    setSetting(settings, "veil", 0.0);
    setSetting(settings, "output_view", 6);
    return settings;
}

bool render(Frame& frame, const Settings& settings, RectI window = {})
{
    if (window.x2 == 0 && window.y2 == 0) {
        window = {frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                  frame.bounds.y + frame.bounds.height};
    }
    const FrameSurface source{MemoryKind::Cpu, PixelFormat::RgbaFloat32, frame.source.data(), 0U, frame.row_bytes,
                              frame.bounds};
    const FrameSurface destination{MemoryKind::Cpu, PixelFormat::RgbaFloat32, frame.destination.data(), 0U,
                                   frame.row_bytes, frame.bounds};
    RenderRequest request{EffectId::LensReflections, source, destination, window, 0.0, {1.0, 1.0},
                          AlphaAssociation::Straight, settings};
    CpuRenderBackend backend;
    return cbef::render(request, backend).kind == SubmissionKind::Completed;
}

double luma(const float* value)
{
    return std::max(0.0, 0.27411851 * value[0] + 0.87363190 * value[1] - 0.14775041 * value[2]);
}

double energy(const Frame& frame)
{
    double total = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            total += luma(pixel(frame.destination, frame, x, y));
        }
    }
    return total;
}

std::array<double, 2> centroid(const Frame& frame)
{
    double total = 0.0;
    double x_sum = 0.0;
    double y_sum = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const double weight = luma(pixel(frame.destination, frame, x, y));
            total += weight;
            x_sum += weight * x;
            y_sum += weight * y;
        }
    }
    return {x_sum / std::max(total, 1.0e-12), y_sum / std::max(total, 1.0e-12)};
}

int fail(const char* message)
{
    std::fprintf(stderr, "lens_signed_elements_cpu_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do {                           \
        if (!(condition)) return fail(message); \
    } while (false)

int testSignedAxisProfilesAndEnergy()
{
    constexpr std::array<std::array<float, 5>, 3> kAxis = {{{-0.34F, -0.79F, 0.23F, -1.16F, 0.70F},
                                                            {-0.22F, -0.58F, 0.31F, -1.08F, 0.84F},
                                                            {-0.30F, -0.74F, 0.19F, -1.32F, 0.96F}}};
    for (int model = 0; model < 3; ++model) {
        double solo_sum = 0.0;
        bool found_positive = false;
        bool found_negative = false;
        for (int element = 1; element <= 5; ++element) {
            Frame frame(257, 129);
            fill(frame, 0.0F);
            Settings settings = lensSettings(model);
            setSetting(settings, "element_solo", element);
            CHECK(render(frame, settings), "element solo render must complete");
            const double element_energy = energy(frame);
            CHECK(element_energy > 0.0, "every generic profile element must contribute energy");
            solo_sum += element_energy;
            const std::array<double, 2> center = centroid(frame);
            const double optical_x = frame.bounds.x + frame.bounds.width / 2.0;
            const double optical_y = frame.bounds.y + frame.bounds.height / 2.0;
            const double source_x = frame.bounds.x + 0.8 * frame.bounds.width + 0.5;
            const double source_y = optical_y + 0.5;
            const double expected_x = optical_x + 0.65 * kAxis[static_cast<std::size_t>(model)]
                                                            [static_cast<std::size_t>(element - 1)] *
                                                         (source_x - optical_x);
            CHECK(std::abs(center[0] - expected_x) <= 1.5,
                  "element centroid must follow its compiled signed axis position");
            CHECK(std::abs(center[1] - source_y) <= 1.5, "element centroid must remain on the source-center axis");
            found_positive |= center[0] > optical_x + 1.0;
            found_negative |= center[0] < optical_x - 1.0;
        }
        CHECK(found_positive && found_negative, "each profile must contain both signed sides of the optical center");

        Frame all(257, 129);
        fill(all, 0.0F);
        Settings all_settings = lensSettings(model);
        setSetting(all_settings, "element_solo", 0);
        CHECK(render(all, all_settings), "all-elements render must complete");
        CHECK(std::abs(energy(all) - solo_sum) / std::max(solo_sum, 1.0e-9) <= 0.03,
              "profile and solo element energy must reconstruct within three percent");
    }
    return 0;
}

int testSoloPixelReconstructionAndDiagnostics()
{
    Frame all(129, 97, -7, 11);
    fill(all, 0.02F);
    Settings settings = lensSettings(1);
    setSetting(settings, "element_solo", 0);
    CHECK(render(all, settings), "all-elements diagnostic must render");
    std::array<std::vector<float>, 3> sum;
    const std::size_t pixels = static_cast<std::size_t>(all.bounds.width * all.bounds.height);
    for (auto& channel : sum) channel.assign(pixels, 0.0F);
    for (int element = 1; element <= 5; ++element) {
        Frame solo = all;
        std::fill(solo.destination.begin(), solo.destination.end(), 0xA5U);
        Settings solo_settings = settings;
        setSetting(solo_settings, "element_solo", element);
        CHECK(render(solo, solo_settings), "element solo diagnostic must render");
        for (int y = all.bounds.y; y < all.bounds.y + all.bounds.height; ++y) {
            for (int x = all.bounds.x; x < all.bounds.x + all.bounds.width; ++x) {
                const std::size_t index = static_cast<std::size_t>(y - all.bounds.y) * all.bounds.width +
                                          static_cast<std::size_t>(x - all.bounds.x);
                const float* value = pixel(solo.destination, solo, x, y);
                for (int channel = 0; channel < 3; ++channel) sum[static_cast<std::size_t>(channel)][index] += value[channel];
            }
        }
    }
    for (int y = all.bounds.y; y < all.bounds.y + all.bounds.height; ++y) {
        for (int x = all.bounds.x; x < all.bounds.x + all.bounds.width; ++x) {
            const std::size_t index = static_cast<std::size_t>(y - all.bounds.y) * all.bounds.width +
                                      static_cast<std::size_t>(x - all.bounds.x);
            const float* expected = pixel(all.destination, all, x, y);
            for (int channel = 0; channel < 3; ++channel) {
                CHECK(std::abs(expected[channel] - sum[static_cast<std::size_t>(channel)][index]) <= 2.0e-4F,
                      "element solo planes must reconstruct Elements Only within 2e-4");
            }
        }
    }
    Frame paths = all;
    std::fill(paths.destination.begin(), paths.destination.end(), 0U);
    setSetting(settings, "output_view", 4);
    CHECK(render(paths, settings) && energy(paths) > 0.0, "Ghost Paths must expose non-empty axis geometry");
    return 0;
}

int testFocusedPatternRetention()
{
    Frame frame(129, 97);
    fill(frame, 0.02F);
    constexpr int source_x = 68;
    constexpr int source_y = 52;
    for (int dy = -2; dy <= 2; ++dy) {
        for (int dx = -2; dx <= 2; ++dx) {
            float* p = pixel(frame.source, frame, source_x + dx, source_y + dy);
            const float pattern = ((dx + dy) & 1) == 0 ? 5.0F : 0.35F;
            p[0] = p[1] = p[2] = pattern;
        }
    }
    Settings settings = lensSettings(0);
    const double manual_x = (2.0 * (static_cast<double>(source_x) + 0.5) / frame.bounds.width - 1.0) * 100.0;
    const double manual_y = (2.0 * (static_cast<double>(source_y) + 0.5) / frame.bounds.height - 1.0) * 100.0;
    setSetting(settings, "manual_x", manual_x);
    setSetting(settings, "manual_y", manual_y);
    setSetting(settings, "manual_size", 6.0);
    setSetting(settings, "element_solo", 1);
    CHECK(render(frame, settings), "focused element pattern fixture must render");

    const double manual_center_x = (manual_x / 100.0 + 1.0) * 0.5 * frame.bounds.width + 0.5;
    const double manual_center_y = (manual_y / 100.0 + 1.0) * 0.5 * frame.bounds.height + 0.5;
    const double radius = frame.bounds.height * 6.0 / 200.0;
    double detected_weight = 0.0;
    double detected_x = 0.0;
    double detected_y = 0.0;
    for (int y = 48; y <= 55; ++y) {
        for (int x = 64; x <= 71; ++x) {
            const double dx = (x + 0.5 - manual_center_x) / radius;
            const double dy = (y + 0.5 - manual_center_y) / radius;
            const double distance = std::sqrt(dx * dx + dy * dy);
            const double t = std::clamp((distance - 0.65) / 0.35, 0.0, 1.0);
            const double matte = 1.0 - t * t * (3.0 - 2.0 * t);
            const double weight = matte * luma(pixel(frame.source, frame, x, y));
            detected_weight += weight;
            detected_x += x * weight;
            detected_y += y * weight;
        }
    }
    detected_x /= detected_weight;
    detected_y /= detected_weight;
    const double optical_x = frame.bounds.width / 2.0;
    const double optical_y = frame.bounds.height / 2.0;
    const double ghost_x = optical_x - 0.34 * 0.65 * (detected_x - optical_x);
    const double ghost_y = optical_y - 0.34 * 0.65 * (detected_y - optical_y);
    const std::size_t count = static_cast<std::size_t>(frame.bounds.width * frame.bounds.height);
    std::vector<double> expected(count, 0.0);
    std::vector<double> actual(count, 0.0);
    auto splat_expected = [&](double x, double y, double value) {
        const int x0 = static_cast<int>(std::floor(x));
        const int y0 = static_cast<int>(std::floor(y));
        const double fx = x - x0;
        const double fy = y - y0;
        for (int oy = 0; oy <= 1; ++oy) {
            for (int ox = 0; ox <= 1; ++ox) {
                const int px = x0 + ox;
                const int py = y0 + oy;
                if (px < 0 || px >= frame.bounds.width || py < 0 || py >= frame.bounds.height) continue;
                expected[static_cast<std::size_t>(py * frame.bounds.width + px)] +=
                    value * (ox == 0 ? 1.0 - fx : fx) * (oy == 0 ? 1.0 - fy : fy);
            }
        }
    };
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            const double dx = (x + 0.5 - manual_center_x) / radius;
            const double dy = (y + 0.5 - manual_center_y) / radius;
            const double distance = std::sqrt(dx * dx + dy * dy);
            const double t = std::clamp((distance - 0.65) / 0.35, 0.0, 1.0);
            const double matte = 1.0 - t * t * (3.0 - 2.0 * t);
            if (matte <= 0.0) continue;
            splat_expected(ghost_x + 0.74 * (x - detected_x), ghost_y + 0.74 * (y - detected_y),
                           matte * luma(pixel(frame.source, frame, x, y)));
        }
    }
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            actual[static_cast<std::size_t>(y * frame.bounds.width + x)] =
                luma(pixel(frame.destination, frame, x, y));
        }
    }
    const double expected_mean = std::accumulate(expected.begin(), expected.end(), 0.0) / expected.size();
    const double actual_mean = std::accumulate(actual.begin(), actual.end(), 0.0) / actual.size();
    double numerator = 0.0;
    double expected_norm = 0.0;
    double actual_norm = 0.0;
    for (std::size_t index = 0; index < expected.size(); ++index) {
        const double a = expected[index] - expected_mean;
        const double b = actual[index] - actual_mean;
        numerator += a * b;
        expected_norm += a * a;
        actual_norm += b * b;
    }
    const double ncc = numerator / std::sqrt(std::max(expected_norm * actual_norm, 1.0e-18));
    CHECK(ncc >= 0.75, "focused element must retain source-local pattern with NCC >= 0.75");
    return 0;
}

int testContinuityBackgroundReachAndSurfaceContracts()
{
    Frame left(161, 101);
    Frame right(161, 101);
    fill(left, 0.0F);
    fill(right, 0.0F);
    Settings left_settings = lensSettings(0);
    Settings right_settings = left_settings;
    setSetting(left_settings, "element_solo", 1);
    setSetting(right_settings, "element_solo", 1);
    setSetting(left_settings, "manual_x", 40.0);
    setSetting(right_settings, "manual_x", 40.0 + 200.0 / left.bounds.width);
    CHECK(render(left, left_settings) && render(right, right_settings), "one-pixel source sweep must render");
    CHECK(std::abs((centroid(right)[0] - centroid(left)[0]) - (-0.34 * 0.65)) <= 0.15,
          "one-pixel source motion must produce continuous signed-k motion");
    CHECK(std::abs(energy(right) - energy(left)) / std::max(energy(left), 1.0e-9) <= 0.03,
          "one-pixel source motion must preserve element energy");

    Frame dark(161, 101);
    Frame bright(161, 101);
    fill(dark, 0.01F);
    fill(bright, 1.0F);
    for (Frame* frame : {&dark, &bright}) {
        float* p = pixel(frame->source, *frame, 128, 50);
        p[0] = p[1] = p[2] = 8.0F;
    }
    Settings adaptive = defaultSettings(EffectId::LensReflections);
    setSetting(adaptive, "working_mode", 1);
    setSetting(adaptive, "threshold", 3.5);
    setSetting(adaptive, "amount", 100.0);
    setSetting(adaptive, "spread", 65.0);
    setSetting(adaptive, "blur", 0.0);
    setSetting(adaptive, "chroma", 0.0);
    setSetting(adaptive, "background_adaptation", 100.0);
    setSetting(adaptive, "veil", 0.0);
    setSetting(adaptive, "output_view", 5);
    CHECK(render(dark, adaptive) && render(bright, adaptive), "background fixtures must render");
    CHECK(energy(bright) < energy(dark) * 0.75, "bright backgrounds must reduce visible element impact");

    Frame near(161, 101);
    fill(near, 0.0F);
    Settings near_settings = lensSettings(0);
    setSetting(near_settings, "manual_x", 130.0);
    setSetting(near_settings, "element_solo", 4);
    CHECK(render(near, near_settings) && energy(near) > 0.0,
          "off-screen source inside the documented reach must contribute");
    Frame far(161, 101);
    fill(far, 0.0F);
    Settings far_settings = lensSettings(0);
    setSetting(far_settings, "manual_x", 400.0);
    setSetting(far_settings, "element_solo", 4);
    CHECK(render(far, far_settings) && energy(far) <= 1.0e-8,
          "source beyond the reach must not wrap or create opposite-edge flare");

    Frame surface(65, 47, -5, 9);
    fill(surface, 0.1F);
    float* hdr = pixel(surface.source, surface, 42, 27);
    hdr[0] = -1.0F;
    hdr[1] = 8.0F;
    hdr[2] = 2.0F;
    hdr[3] = 0.65F;
    Settings final = lensSettings(2);
    setSetting(final, "output_view", 0);
    setSetting(final, "source_mode", 0);
    setSetting(final, "threshold", -2.0);
    const RectI crop{-1, 12, 55, 50};
    CHECK(render(surface, final, crop), "signed HDR non-zero-origin crop must render");
    CHECK(std::isfinite(pixel(surface.destination, surface, 42, 27)[0]), "active signed HDR output must stay finite");
    CHECK(std::memcmp(&pixel(surface.destination, surface, 42, 27)[3], &hdr[3], sizeof(float)) == 0,
          "alpha bits must be preserved");
    CHECK(surface.destination[0] == 0xA5U, "destination bytes outside the crop must remain untouched");
    return 0;
}

}

int main()
{
    if (testSignedAxisProfilesAndEnergy() != 0 || testSoloPixelReconstructionAndDiagnostics() != 0 ||
        testFocusedPatternRetention() != 0 ||
        testContinuityBackgroundReachAndSurfaceContracts() != 0) {
        return 1;
    }
    std::puts("lens_signed_elements_cpu_contract: PASS (signed axis + five element profiles + diagnostics)");
    return 0;
}
