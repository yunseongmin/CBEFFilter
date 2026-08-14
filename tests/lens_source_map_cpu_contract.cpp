#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
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
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + 16U)
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
    return reinterpret_cast<const float*>(bytes.data() + static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                          static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes);
}

RenderRequest requestFor(Frame& frame)
{
    const FrameSurface source{MemoryKind::Cpu, PixelFormat::RgbaFloat32, frame.source.data(), 0U, frame.row_bytes,
                              frame.bounds};
    const FrameSurface destination{MemoryKind::Cpu, PixelFormat::RgbaFloat32, frame.destination.data(), 0U,
                                   frame.row_bytes, frame.bounds};
    return RenderRequest{EffectId::LensReflections,
                         source,
                         destination,
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height},
                         0.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         defaultSettings(EffectId::LensReflections)};
}

bool setDouble(Settings& settings, const char* id, double value)
{
    return setSetting(settings, id, value);
}

bool setChoice(Settings& settings, const char* id, int value)
{
    return setSetting(settings, id, value);
}

bool render(Frame& frame, Settings settings)
{
    RenderRequest request = requestFor(frame);
    request.settings = std::move(settings);
    CpuRenderBackend backend;
    return render(request, backend).kind == SubmissionKind::Completed;
}

void fill(Frame& frame, float value)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* p = pixel(frame.source, frame, x, y);
            p[0] = value;
            p[1] = value;
            p[2] = value;
            p[3] = 1.0F;
        }
    }
}

void light(Frame& frame, int center_x, int center_y, float r, float g, float b)
{
    for (int y = center_y - 1; y <= center_y + 1; ++y) {
        for (int x = center_x - 1; x <= center_x + 1; ++x) {
            if (x < frame.bounds.x || y < frame.bounds.y || x >= frame.bounds.x + frame.bounds.width ||
                y >= frame.bounds.y + frame.bounds.height) {
                continue;
            }
            float* p = pixel(frame.source, frame, x, y);
            p[0] = r;
            p[1] = g;
            p[2] = b;
        }
    }
}

double mapValue(const Frame& frame, int x, int y)
{
    return std::max(0.0, static_cast<double>(pixel(frame.destination, frame, x, y)[0]));
}

double mapEnergy(const Frame& frame)
{
    double total = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            total += mapValue(frame, x, y);
        }
    }
    return total;
}

double mapCentroidX(const Frame& frame)
{
    double total = 0.0;
    double weighted = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const double value = mapValue(frame, x, y);
            total += value;
            weighted += static_cast<double>(x) * value;
        }
    }
    return total > 0.0 ? weighted / total : 0.0;
}

double regionCentroid(const Frame& frame, int center_x, int center_y)
{
    double total = 0.0;
    double weighted_x = 0.0;
    for (int y = std::max(frame.bounds.y, center_y - 3); y <= std::min(frame.bounds.y + frame.bounds.height - 1, center_y + 3);
         ++y) {
        for (int x = std::max(frame.bounds.x, center_x - 3);
             x <= std::min(frame.bounds.x + frame.bounds.width - 1, center_x + 3); ++x) {
            const double value = mapValue(frame, x, y);
            total += value;
            weighted_x += static_cast<double>(x) * value;
        }
    }
    return total > 0.0 ? weighted_x / total : 0.0;
}

int fail(const char* message)
{
    std::fprintf(stderr, "lens_source_map_cpu_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do {                             \
        if (!(condition)) return fail(message); \
    } while (false)

int testAutoMapAndContinuity()
{
    Frame frame(64, 48, -5, 7);
    fill(frame, 0.01F);
    light(frame, 5, 15, 4.0F, 3.2F, 2.4F);
    light(frame, 31, 29, 6.0F, 1.0F, 0.5F);
    light(frame, 53, 18, 2.0F, 2.0F, 2.0F);
    Settings settings = defaultSettings(EffectId::LensReflections);
    CHECK(setChoice(settings, "working_mode", 1) && setChoice(settings, "output_view", 3) &&
              setDouble(settings, "threshold", 0.0) && setDouble(settings, "source_smoothness", 50.0) &&
              setDouble(settings, "amount", 0.0) && setDouble(settings, "mix", 0.0) && render(frame, settings),
          "auto Source Map must render independently of Mix");
    CHECK(mapValue(frame, 5, 15) > 0.5 && mapValue(frame, 31, 29) > 0.5 && mapValue(frame, 53, 18) > 0.5,
          "auto source detector must retain all independent lights");
    CHECK(mapValue(frame, frame.bounds.x, frame.bounds.y) < 0.1, "auto source map must reject dark background");
    CHECK(std::abs(regionCentroid(frame, 5, 15) - 5.0) < 1.0 &&
              std::abs(regionCentroid(frame, 31, 29) - 31.0) < 1.0 &&
              std::abs(regionCentroid(frame, 53, 18) - 53.0) < 1.0,
          "auto source centroids must remain within one pixel");

    Frame low(32, 24);
    Frame high(32, 24);
    fill(low, 0.0F);
    fill(high, 0.0F);
    light(low, 16, 12, static_cast<float>(0.18 * std::exp2(0.0 - 0.02)),
          static_cast<float>(0.18 * std::exp2(0.0 - 0.02)), static_cast<float>(0.18 * std::exp2(0.0 - 0.02)));
    light(high, 16, 12, static_cast<float>(0.18 * std::exp2(0.0 + 0.02)),
          static_cast<float>(0.18 * std::exp2(0.0 + 0.02)), static_cast<float>(0.18 * std::exp2(0.0 + 0.02)));
    Settings low_settings = settingsForPreset(EffectId::LensReflections, 0U);
    Settings high_settings = low_settings;
    CHECK(setChoice(low_settings, "working_mode", 1) && setChoice(high_settings, "working_mode", 1) &&
              setChoice(low_settings, "output_view", 3) && setChoice(high_settings, "output_view", 3) &&
              setDouble(low_settings, "threshold", 0.0) && setDouble(high_settings, "threshold", 0.0) &&
              setDouble(low_settings, "source_smoothness", 70.0) && setDouble(high_settings, "source_smoothness", 70.0) &&
              render(low, low_settings) && render(high, high_settings),
          "threshold continuity fixtures must render");
    CHECK(std::abs(mapEnergy(high) - mapEnergy(low)) < 2.0, "threshold sweep must remain continuous");
    return 0;
}

int testManualAndDeterminism()
{
    Frame frame(80, 60, 11, -9);
    fill(frame, 0.0F);
    Settings settings = defaultSettings(EffectId::LensReflections);
    CHECK(setChoice(settings, "working_mode", 1) && setChoice(settings, "source_mode", 1) &&
              setChoice(settings, "output_view", 3) && setDouble(settings, "manual_x", 50.0) &&
              setDouble(settings, "manual_y", -50.0) && setDouble(settings, "manual_size", 8.0) &&
              setDouble(settings, "manual_intensity", 125.0) && setDouble(settings, "amount", 0.0) &&
              setDouble(settings, "mix", 0.0) && render(frame, settings),
          "manual Source Map must render");
    const double expected_x = frame.bounds.x + frame.bounds.width * 0.75;
    CHECK(std::abs(mapCentroidX(frame) - expected_x) <= 0.25, "manual centroid must match the analytic source position");
    const double first_energy = mapEnergy(frame);
    std::vector<std::uint8_t> first = frame.destination;
    CHECK(render(frame, settings) && frame.destination == first, "same-frame source map must be seek deterministic");
    CHECK(setDouble(settings, "manual_intensity", 50.0) && render(frame, settings) && mapEnergy(frame) < first_energy,
          "manual source intensity must be monotonic");

    CHECK(setDouble(settings, "manual_x", 200.0) && render(frame, settings) && mapEnergy(frame) <= 1.0e-6,
          "off-screen manual source must not wrap into the frame");
    return 0;
}

}

int main()
{
    if (testAutoMapAndContinuity() != 0 || testManualAndDeterminism() != 0) {
        return 1;
    }
    std::puts("lens_source_map_cpu_contract: PASS (v2 CPU source map + manual source)");
    return 0;
}
