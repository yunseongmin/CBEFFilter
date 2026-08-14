#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

#include "cbef/RenderCore.h"

namespace {
using namespace cbef;
constexpr std::size_t kRgbaBytes = sizeof(float) * 4U;

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> bytes;

    Frame(DataWindow window, std::size_t pixel_bytes, std::size_t padding = 12U)
        : bounds(window)
        , row_bytes(static_cast<std::size_t>(window.width) * pixel_bytes + padding)
        , bytes(row_bytes * static_cast<std::size_t>(window.height), 0U)
    {
    }
};

float* value(Frame& frame, int x, int y)
{
    return reinterpret_cast<float*>(frame.bytes.data() + static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                    static_cast<std::size_t>(x - frame.bounds.x) * kRgbaBytes);
}

float* alpha(Frame& frame, int x, int y)
{
    return reinterpret_cast<float*>(frame.bytes.data() + static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                    static_cast<std::size_t>(x - frame.bounds.x) * sizeof(float));
}

FrameSurface rgbaSurface(Frame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, frame.bytes.data(), 0U, frame.row_bytes,
                        frame.bounds};
}

FrameSurface alphaSurface(Frame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::AlphaFloat32, frame.bytes.data(), 0U, frame.row_bytes,
                        frame.bounds};
}

int fail(const char* message)
{
    std::fprintf(stderr, "lens_external_matte_cpu_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) return fail(message); \
    } while (false)

RenderRequest requestFor(Frame& source, Frame& destination)
{
    return RenderRequest{EffectId::LensReflections,
                         rgbaSurface(source),
                         rgbaSurface(destination),
                         RectI{source.bounds.x, source.bounds.y, source.bounds.x + source.bounds.width,
                               source.bounds.y + source.bounds.height},
                         0.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         defaultSettings(EffectId::LensReflections)};
}

void fillScene(Frame& frame)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            float* pixel = value(frame, x, y);
            pixel[0] = 4.0F;
            pixel[1] = 2.0F;
            pixel[2] = 1.0F;
            pixel[3] = 1.0F;
        }
    }
}

void fillAlpha(Frame& frame, float amount)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            *alpha(frame, x, y) = amount;
        }
    }
}

double sumRgb(const Frame& frame)
{
    double total = 0.0;
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float* pixel = reinterpret_cast<const float*>(frame.bytes.data() +
                static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                static_cast<std::size_t>(x - frame.bounds.x) * kRgbaBytes);
            total += std::max(0.0F, pixel[0]) + std::max(0.0F, pixel[1]) + std::max(0.0F, pixel[2]);
        }
    }
    return total;
}

int testSourceMapBeforeAfter()
{
    Frame source(DataWindow{3, -2, 6, 4}, kRgbaBytes);
    Frame destination(source.bounds, kRgbaBytes, 20U);
    Frame matte(DataWindow{10, 8, 3, 2}, sizeof(float), 8U);
    fillScene(source);
    fillAlpha(matte, 0.0F);
    Settings settings = defaultSettings(EffectId::LensReflections);
    CHECK(setSetting(settings, "working_mode", 1) && setSetting(settings, "threshold", -2.0) &&
              setSetting(settings, "source_smoothness", 40.0) && setSetting(settings, "mix", 0.0) &&
              setSetting(settings, "output_view", 3),
          "Source Map settings must be accepted");
    RenderRequest request = requestFor(source, destination);
    ExternalMatteInput external{alphaSurface(matte), AlphaAssociation::Straight};
    request.external_matte = &external;
    CpuRenderBackend backend;
    CHECK(render(request, backend).kind == SubmissionKind::Completed, "pre-matte Source Map must render");
    CHECK(sumRgb(destination) > 0.0, "Source Map must preserve the pre-matte diagnostic");
    std::fill(destination.bytes.begin(), destination.bytes.end(), 0xA5U);
    CHECK(setSetting(request.settings, "output_view", 7), "Matte Limited setting must be accepted");
    CHECK(render(request, backend).kind == SubmissionKind::Completed, "post-matte Source Map must render");
    CHECK(sumRgb(destination) == 0.0, "zero external matte must suppress the limited map");
    return 0;
}

int testIdentityAndCoverage()
{
    Frame source(DataWindow{-1, 5, 8, 5}, kRgbaBytes);
    Frame baseline(source.bounds, kRgbaBytes, 16U);
    Frame all_one(source.bounds, kRgbaBytes, 16U);
    Frame partial(source.bounds, kRgbaBytes, 16U);
    Frame matte(DataWindow{4, -3, 4, 3}, sizeof(float), 12U);
    fillScene(source);
    fillAlpha(matte, 1.0F);
    Settings settings = defaultSettings(EffectId::LensReflections);
    CHECK(setSetting(settings, "working_mode", 1) && setSetting(settings, "threshold", -2.0) &&
              setSetting(settings, "source_smoothness", 20.0) && setSetting(settings, "amount", 60.0) &&
              setSetting(settings, "mix", 100.0),
          "coverage settings must be accepted");
    RenderRequest request = requestFor(source, baseline);
    request.settings = settings;
    CpuRenderBackend backend;
    CHECK(render(request, backend).kind == SubmissionKind::Completed, "absent matte render must complete");
    request.destination = rgbaSurface(all_one);
    ExternalMatteInput one{alphaSurface(matte), AlphaAssociation::Straight};
    request.external_matte = &one;
    CHECK(render(request, backend).kind == SubmissionKind::Completed, "all-one matte render must complete");
    CHECK(all_one.bytes == baseline.bytes, "all-one matte must be bit-identical to absent matte");
    for (const double scale : {0.5, 1.0, 2.0}) {
        std::fill(all_one.bytes.begin(), all_one.bytes.end(), 0U);
        request.render_scale = RenderScale{scale, scale};
        request.destination = rgbaSurface(all_one);
        CHECK(render(request, backend).kind == SubmissionKind::Completed, "scaled all-one matte render must complete");
        CHECK(all_one.bytes == baseline.bytes, "all-one matte must stay identical across render scales");
    }

    fillAlpha(matte, 0.5F);
    request.render_scale = RenderScale{1.0, 1.0};
    request.destination = rgbaSurface(partial);
    CHECK(render(request, backend).kind == SubmissionKind::Completed, "partial matte render must complete");
    CHECK(sumRgb(partial) < sumRgb(baseline) && sumRgb(partial) > 0.0,
          "partial matte must reduce but retain positive element energy");

    std::fill(partial.bytes.begin(), partial.bytes.end(), 0xA5U);
    request.render_window = RectI{source.bounds.x + 2, source.bounds.y + 1, source.bounds.x + 5, source.bounds.y + 4};
    CHECK(render(request, backend).kind == SubmissionKind::Completed, "cropped matte render must complete");
    for (int y = source.bounds.y; y < source.bounds.y + source.bounds.height; ++y) {
        for (int x = source.bounds.x; x < source.bounds.x + source.bounds.width; ++x) {
            if (x < request.render_window.x1 || x >= request.render_window.x2 || y < request.render_window.y1 ||
                y >= request.render_window.y2) {
                const std::uint8_t* address = partial.bytes.data() +
                    static_cast<std::size_t>(y - source.bounds.y) * partial.row_bytes +
                    static_cast<std::size_t>(x - source.bounds.x) * kRgbaBytes;
                CHECK(address[0] == 0xA5U && address[15] == 0xA5U, "crop outside bytes must remain sentinel");
            }
        }
    }
    return 0;
}

int testRgbaAndValidation()
{
    Frame source(DataWindow{0, 0, 4, 4}, kRgbaBytes);
    Frame destination(source.bounds, kRgbaBytes);
    Frame matte(DataWindow{0, 0, 4, 4}, kRgbaBytes, 16U);
    fillScene(source);
    for (int y = 0; y < 4; ++y) {
        for (int x = 0; x < 4; ++x) {
            float* pixel = value(matte, x, y);
            pixel[0] = pixel[1] = pixel[2] = 1.0F;
            pixel[3] = 0.5F;
        }
    }
    RenderRequest request = requestFor(source, destination);
    CHECK(setSetting(request.settings, "output_view", 7) && setSetting(request.settings, "threshold", -2.0),
          "RGBA diagnostic settings must be accepted");
    ExternalMatteInput rgba{rgbaSurface(matte), AlphaAssociation::Straight};
    request.external_matte = &rgba;
    CpuRenderBackend backend;
    CHECK(render(request, backend).kind == SubmissionKind::Completed, "RGBA matte must render");
    CHECK(sumRgb(destination) > 0.0 && sumRgb(destination) < 4.0 * 4.0 * 3.0,
          "RGBA alpha coverage must scale positive luminance*alpha");
    rgba.alpha_association = AlphaAssociation::Premultiplied;
    for (int y = 0; y < 4; ++y) {
        for (int x = 0; x < 4; ++x) {
            float* pixel = value(matte, x, y);
            pixel[0] = pixel[1] = pixel[2] = 0.5F;
        }
    }
    std::fill(destination.bytes.begin(), destination.bytes.end(), 0U);
    CHECK(render(request, backend).kind == SubmissionKind::Completed && sumRgb(destination) > 0.0,
          "premultiplied RGBA matte must preserve alpha coverage");
    Frame bad(DataWindow{0, 0, 4, 4}, sizeof(float));
    ExternalMatteInput invalid{alphaSurface(bad), AlphaAssociation::Straight};
    invalid.surface.row_bytes = 4U;
    request.external_matte = &invalid;
    CHECK(render(request, backend).error == Error::InvalidStride, "invalid matte stride must fail explicitly");
    return 0;
}
}

int main()
{
    if (testSourceMapBeforeAfter() != 0 || testIdentityAndCoverage() != 0 || testRgbaAndValidation() != 0) {
        return 1;
    }
    std::puts("lens_external_matte_cpu_contract: PASS (optional matte, canonical sampling, diagnostics, validation)");
    return 0;
}
