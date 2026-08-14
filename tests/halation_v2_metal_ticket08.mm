#import <Metal/Metal.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

#include "cbef/RenderCore.h"

namespace {
using namespace cbef;
constexpr std::uint8_t kSentinel = 0xA5U;
constexpr std::size_t kPixelBytes = sizeof(float) * 4U;

int fail(const char* message)
{
    std::fprintf(stderr, "halation_v2_metal_ticket08: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) return fail(message); \
    } while (false)

struct Frame {
    int width;
    int height;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;

    Frame(int frame_width, int frame_height)
        : width(frame_width)
        , height(frame_height)
        , row_bytes(static_cast<std::size_t>(frame_width) * kPixelBytes + 32U)
        , source(row_bytes * static_cast<std::size_t>(frame_height), 0U)
        , destination(source.size(), kSentinel)
    {
        for (int y = 0; y < height; ++y) {
            for (int x = 0; x < width; ++x) {
                float* value = pixel(source, x, y);
                const float highlight = (x == width / 2 && y == height / 2) ? 3.0F : 0.04F;
                value[0] = highlight;
                value[1] = highlight * 0.72F;
                value[2] = highlight * 0.32F;
                value[3] = 1.0F;
            }
        }
        float* transparent = pixel(source, width / 3, height / 3);
        transparent[0] = 100.0F;
        transparent[1] = 50.0F;
        transparent[2] = 25.0F;
        transparent[3] = 0.0F;
    }

    float* pixel(std::vector<std::uint8_t>& storage, int x, int y) const
    {
        return reinterpret_cast<float*>(storage.data() + static_cast<std::size_t>(y) * row_bytes +
                                        static_cast<std::size_t>(x) * kPixelBytes);
    }
};

FrameSurface surface(MemoryKind kind, void* data, const Frame& frame)
{
    return FrameSurface{kind, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, DataWindow{0, 0, frame.width, frame.height}};
}

RenderRequest requestFor(Frame& frame)
{
    return RenderRequest{EffectId::Halation,
                         surface(MemoryKind::Cpu, frame.source.data(), frame),
                         surface(MemoryKind::Cpu, frame.destination.data(), frame),
                         RectI{0, 0, frame.width, frame.height}, 0.0, RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight, defaultSettings(EffectId::Halation)};
}

bool wait(id<MTLCommandQueue> queue)
{
    id<MTLCommandBuffer> sentinel = [queue commandBuffer];
    if (sentinel == nil) return false;
    [sentinel commit];
    [sentinel waitUntilCompleted];
    return sentinel.status == MTLCommandBufferStatusCompleted;
}

int runSmallParity(id<MTLDevice> device, id<MTLCommandQueue> queue)
{
    Frame frame(97, 61);
    RenderRequest cpu_request = requestFor(frame);
    CHECK(setSetting(cpu_request.settings, "working_mode", 1), "linear Working Mode must be accepted");
    CHECK(setSetting(cpu_request.settings, "amount", 100.0) && setSetting(cpu_request.settings, "radius", 1.0) &&
              setSetting(cpu_request.settings, "global_diffusion", 35.0) && setSetting(cpu_request.settings, "threshold", -1.0),
          "v2 parity settings must be accepted");
    CpuRenderBackend cpu_backend;
    CHECK(render(cpu_request, cpu_backend).kind == SubmissionKind::Completed, "CPU reference must complete");
    const std::vector<std::uint8_t> expected = frame.destination;
    id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
    id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
    CHECK(source != nil && destination != nil, "Metal buffers must allocate");
    std::memcpy(source.contents, frame.source.data(), frame.source.size());
    std::memset(destination.contents, kSentinel, frame.destination.size());
    RenderRequest metal_request = cpu_request;
    metal_request.source = surface(MemoryKind::Metal, (__bridge void*)source, frame);
    metal_request.destination = surface(MemoryKind::Metal, (__bridge void*)destination, frame);
    MetalRenderBackend metal_backend((__bridge void*)queue);
    CHECK(render(metal_request, metal_backend).kind == SubmissionKind::Enqueued, "Metal v2 must enqueue");
    CHECK(wait(queue), "same queue completion must succeed");
    std::vector<std::uint8_t> actual(frame.destination.size());
    std::memcpy(actual.data(), destination.contents, actual.size());
    Frame expected_frame = frame;
    expected_frame.destination = expected;
    float maximum_error = 0.0F;
    int error_x = 0;
    int error_y = 0;
    for (int y = 0; y < frame.height; ++y) {
        for (int x = 0; x < frame.width; ++x) {
            const float* expected_pixel = expected_frame.pixel(expected_frame.destination, x, y);
            const float* actual_pixel = expected_frame.pixel(actual, x, y);
            for (int channel = 0; channel < 3; ++channel) {
                const float error = std::abs(expected_pixel[channel] - actual_pixel[channel]);
                if (error > maximum_error) {
                    maximum_error = error;
                    error_x = x;
                    error_y = y;
                }
            }
            std::uint32_t ea = 0U, aa = 0U;
            std::memcpy(&ea, expected_pixel + 3, sizeof(ea));
            std::memcpy(&aa, actual_pixel + 3, sizeof(aa));
            CHECK(ea == aa, "alpha bits must be preserved");
        }
    }
    if (maximum_error > 2.0e-4F) {
        const float* expected_pixel = expected_frame.pixel(expected_frame.destination, error_x, error_y);
        const float* actual_pixel = expected_frame.pixel(actual, error_x, error_y);
        std::fprintf(stderr, "halation_v2_metal_ticket08: maximum_error=%g at %d,%d expected=(%g,%g,%g) actual=(%g,%g,%g)\n",
                     maximum_error, error_x, error_y, expected_pixel[0], expected_pixel[1], expected_pixel[2],
                     actual_pixel[0], actual_pixel[1], actual_pixel[2]);
        return fail("CPU/Metal v2 parity exceeded 2e-4");
    }
    [source release];
    [destination release];
    return 0;
}

int runColorEmphasisParity(id<MTLDevice> device, id<MTLCommandQueue> queue)
{
    constexpr std::array<std::array<float, 3>, 4> auto_colors = {{{1.0F, 1.0F, 1.0F},
                                                                    {1.0F, 0.58F, 0.22F},
                                                                    {0.08F, 0.18F, 1.0F},
                                                                    {0.08F, 1.0F, 0.14F}}};
    for (int scenario = 0; scenario < 8; ++scenario) {
        const int mode = scenario < 3 ? scenario + 1 : 4;
        Frame frame(97, 61);
        if (mode == 4) {
            if (scenario < 7) {
                const std::array<float, 3>& color = auto_colors[static_cast<std::size_t>(scenario - 3)];
                float* source = frame.pixel(frame.source, frame.width / 2, frame.height / 2);
                source[0] = color[0] * 3.0F;
                source[1] = color[1] * 3.0F;
                source[2] = color[2] * 3.0F;
            } else {
                for (int y = 0; y < frame.height; ++y) {
                    for (int x = 0; x < frame.width; ++x) {
                        float* value = frame.pixel(frame.source, x, y);
                        value[0] = -0.20F;
                        value[1] = 0.05F;
                        value[2] = 0.10F;
                        value[3] = 0.50F;
                    }
                }
                float* source = frame.pixel(frame.source, frame.width / 2, frame.height / 2);
                source[0] = 2.0F;
                source[1] = 0.60F;
                source[2] = 0.15F;
                source[3] = 0.50F;
                float* hidden = frame.pixel(frame.source, frame.width / 2 + 1, frame.height / 2);
                hidden[0] = 100.0F;
                hidden[1] = 50.0F;
                hidden[2] = 25.0F;
                hidden[3] = 0.0F;
            }
        }
        RenderRequest cpu_request = requestFor(frame);
        CHECK(setSetting(cpu_request.settings, "working_mode", 1) &&
                  setSetting(cpu_request.settings, "amount", 200.0) &&
                  setSetting(cpu_request.settings, "radius", 1.5) &&
                  setSetting(cpu_request.settings, "global_diffusion", 35.0) &&
                  setSetting(cpu_request.settings, "threshold", -2.0) &&
                  setSetting(cpu_request.settings, "color_emphasis", mode) &&
                  setSetting(cpu_request.settings, "color_strength", 100.0),
              "strong Color Emphasis parity settings must be accepted");
        if (scenario == 7) cpu_request.alpha_association = AlphaAssociation::Premultiplied;
        CpuRenderBackend cpu_backend;
        CHECK(render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
              "Color Emphasis CPU reference must complete");
        const std::vector<std::uint8_t> expected = frame.destination;
        id<MTLBuffer> source = [device newBufferWithLength:frame.source.size()
                                                  options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size()
                                                       options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "Color Emphasis Metal buffers must allocate");
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, kSentinel, frame.destination.size());
        RenderRequest metal_request = cpu_request;
        metal_request.source = surface(MemoryKind::Metal, (__bridge void*)source, frame);
        metal_request.destination = surface(MemoryKind::Metal, (__bridge void*)destination, frame);
        MetalRenderBackend metal_backend((__bridge void*)queue);
        CHECK(render(metal_request, metal_backend).kind == SubmissionKind::Enqueued && wait(queue),
              "Color Emphasis Metal render must complete");
        std::vector<std::uint8_t> actual(frame.destination.size());
        std::memcpy(actual.data(), destination.contents, actual.size());
        Frame comparison = frame;
        comparison.destination = expected;
        float maximum_error = 0.0F;
        for (int y = 0; y < frame.height; ++y) {
            for (int x = 0; x < frame.width; ++x) {
                const float* expected_pixel = comparison.pixel(comparison.destination, x, y);
                const float* actual_pixel = comparison.pixel(actual, x, y);
                for (int channel = 0; channel < 3; ++channel) {
                    maximum_error = std::max(maximum_error,
                                             std::abs(expected_pixel[channel] - actual_pixel[channel]));
                }
                std::uint32_t expected_alpha = 0U;
                std::uint32_t actual_alpha = 0U;
                std::memcpy(&expected_alpha, expected_pixel + 3, sizeof(expected_alpha));
                std::memcpy(&actual_alpha, actual_pixel + 3, sizeof(actual_alpha));
                CHECK(expected_alpha == actual_alpha, "Color Emphasis must preserve alpha bits on Metal");
            }
        }
        CHECK(maximum_error <= 2.0e-4F, "Color Emphasis CPU/Metal parity exceeded 2e-4");
        std::fprintf(stderr, "Color Emphasis mode=%d scenario=%d maximum_error=%g\n", mode, scenario,
                     maximum_error);
        [source release];
        [destination release];
    }
    return 0;
}

int runPyramidSafety(id<MTLDevice> device, id<MTLCommandQueue> queue)
{
    Frame frame(1024, 576);
    RenderRequest request = requestFor(frame);
    CHECK(setSetting(request.settings, "working_mode", 1) && setSetting(request.settings, "amount", 200.0) &&
              setSetting(request.settings, "radius", 2.5) && setSetting(request.settings, "global_diffusion", 100.0) &&
              setSetting(request.settings, "color_emphasis", 4) &&
              setSetting(request.settings, "color_strength", 100.0),
          "strong pyramid settings must be accepted");
    request.render_window = RectI{16, 8, frame.width - 16, frame.height - 8};
    id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
    id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
    CHECK(source != nil && destination != nil, "pyramid buffers must allocate");
    std::memcpy(source.contents, frame.source.data(), frame.source.size());
    std::memset(destination.contents, kSentinel, frame.destination.size());
    request.source = surface(MemoryKind::Metal, (__bridge void*)source, frame);
    request.destination = surface(MemoryKind::Metal, (__bridge void*)destination, frame);
    MetalRenderBackend backend((__bridge void*)queue);
    CHECK(render(request, backend).kind == SubmissionKind::Enqueued && wait(queue), "pyramid render must complete");
    const auto* bytes = static_cast<const std::uint8_t*>(destination.contents);
    for (int y = request.render_window.y1; y < request.render_window.y2; ++y) {
        for (int x = request.render_window.x1; x < request.render_window.x2; ++x) {
            const float* value = reinterpret_cast<const float*>(bytes + static_cast<std::size_t>(y) * frame.row_bytes +
                                                                 static_cast<std::size_t>(x) * kPixelBytes);
            CHECK(std::isfinite(value[0]) && std::isfinite(value[1]) && std::isfinite(value[2]), "pyramid output must be finite");
        }
    }
    CHECK(static_cast<const std::uint8_t*>(destination.contents)[0] == kSentinel,
          "pyramid render must preserve bytes outside the crop");
    const float* transparent = reinterpret_cast<const float*>(static_cast<const std::uint8_t*>(destination.contents) +
                                                              static_cast<std::size_t>(frame.height / 3) * frame.row_bytes +
                                                              static_cast<std::size_t>(frame.width / 3) * kPixelBytes);
    CHECK(std::abs(transparent[0]) <= 1.0e-6F && std::abs(transparent[1]) <= 1.0e-6F &&
              std::abs(transparent[2]) <= 1.0e-6F && transparent[3] == 0.0F,
          "transparent HDR source must not emit pyramid halo");
    [source release];
    [destination release];
    return 0;
}

int runPyramidOddStrideAndDiagnostics(id<MTLDevice> device, id<MTLCommandQueue> queue)
{
    for (const auto dimensions : std::array<std::pair<int, int>, 2>{{{1025, 577}, {1024, 576}}}) {
        Frame frame(dimensions.first, dimensions.second);
        id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
        id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
        CHECK(source != nil && destination != nil, "odd-stride pyramid buffers must allocate");
        std::memcpy(source.contents, frame.source.data(), frame.source.size());
        std::memset(destination.contents, kSentinel, frame.destination.size());
        for (std::uint32_t mode = 0U; mode < 3U; ++mode) {
            for (const std::uint32_t diagnostic : std::array<std::uint32_t, 5>{{0U, 1U, 2U, 3U, 4U}}) {
                RenderRequest request = requestFor(frame);
                CHECK(setSetting(request.settings, "working_mode", static_cast<int>(mode)) &&
                          setSetting(request.settings, "output_view", static_cast<int>(diagnostic)) &&
                          setSetting(request.settings, "amount", 200.0) && setSetting(request.settings, "radius", 2.5) &&
                          setSetting(request.settings, "global_diffusion", 100.0) &&
                          setSetting(request.settings, "color_emphasis", 4) &&
                          setSetting(request.settings, "color_strength", 100.0),
                      "wide mode and diagnostic settings must be accepted");
                request.render_window = RectI{1, 3, frame.width - 1, frame.height - 2};
                request.source = surface(MemoryKind::Metal, (__bridge void*)source, frame);
                request.destination = surface(MemoryKind::Metal, (__bridge void*)destination, frame);
                std::memset(destination.contents, kSentinel, frame.destination.size());
                MetalRenderBackend backend((__bridge void*)queue);
                CHECK(render(request, backend).kind == SubmissionKind::Enqueued && wait(queue),
                      "wide diagnostic render must complete");
                const auto* bytes = static_cast<const std::uint8_t*>(destination.contents);
                for (int y = request.render_window.y1; y < request.render_window.y2; y += 41) {
                    for (int x = request.render_window.x1; x < request.render_window.x2; x += 43) {
                        const float* value = reinterpret_cast<const float*>(bytes + static_cast<std::size_t>(y) * frame.row_bytes +
                                                                             static_cast<std::size_t>(x) * kPixelBytes);
                        CHECK(std::isfinite(value[0]) && std::isfinite(value[1]) && std::isfinite(value[2]) &&
                                  std::isfinite(value[3]), "wide diagnostic output must be finite");
                    }
                }
                CHECK(static_cast<const std::uint8_t*>(destination.contents)[0] == kSentinel,
                      "wide odd-stride crop must preserve outside bytes");
            }
        }
        [source release];
        [destination release];
    }
    return 0;
}

struct HaloMetrics {
    double energy[3]{};
    double centroid_x[3]{};
    double centroid_y[3]{};
};

HaloMetrics metrics(const Frame& frame, const std::vector<std::uint8_t>& output)
{
    HaloMetrics result;
    double moments_x[3]{};
    double moments_y[3]{};
    for (int y = 0; y < frame.height; ++y) {
        for (int x = 0; x < frame.width; ++x) {
            const float* source = frame.pixel(const_cast<std::vector<std::uint8_t>&>(frame.source), x, y);
            const float* value = frame.pixel(const_cast<std::vector<std::uint8_t>&>(output), x, y);
            for (int channel = 0; channel < 3; ++channel) {
                const double delta = std::abs(static_cast<double>(value[channel]) - source[channel]);
                result.energy[channel] += delta;
                moments_x[channel] += delta * static_cast<double>(x);
                moments_y[channel] += delta * static_cast<double>(y);
            }
        }
    }
    for (int channel = 0; channel < 3; ++channel) {
        result.centroid_x[channel] = moments_x[channel] / std::max(result.energy[channel], 1.0e-12);
        result.centroid_y[channel] = moments_y[channel] / std::max(result.energy[channel], 1.0e-12);
    }
    return result;
}

int runWideAggregateParity(id<MTLDevice> device, id<MTLCommandQueue> queue)
{
    Frame cpu_frame(1024, 576);
    RenderRequest cpu_request = requestFor(cpu_frame);
    CHECK(setSetting(cpu_request.settings, "working_mode", 1) && setSetting(cpu_request.settings, "amount", 200.0) &&
              setSetting(cpu_request.settings, "radius", 2.5) && setSetting(cpu_request.settings, "global_diffusion", 100.0) &&
              setSetting(cpu_request.settings, "color_emphasis", 4) &&
              setSetting(cpu_request.settings, "color_strength", 100.0),
          "wide parity settings must be accepted");
    CpuRenderBackend cpu_backend;
    CHECK(render(cpu_request, cpu_backend).kind == SubmissionKind::Completed,
          "wide CPU reference must complete");
    const std::vector<std::uint8_t> expected = cpu_frame.destination;
    id<MTLBuffer> source = [device newBufferWithLength:cpu_frame.source.size() options:MTLResourceStorageModeShared];
    id<MTLBuffer> destination = [device newBufferWithLength:cpu_frame.destination.size() options:MTLResourceStorageModeShared];
    CHECK(source != nil && destination != nil, "wide parity Metal buffers must allocate");
    std::memcpy(source.contents, cpu_frame.source.data(), cpu_frame.source.size());
    std::memset(destination.contents, kSentinel, cpu_frame.destination.size());
    RenderRequest metal_request = cpu_request;
    metal_request.source = surface(MemoryKind::Metal, (__bridge void*)source, cpu_frame);
    metal_request.destination = surface(MemoryKind::Metal, (__bridge void*)destination, cpu_frame);
    MetalRenderBackend metal_backend((__bridge void*)queue);
    CHECK(render(metal_request, metal_backend).kind == SubmissionKind::Enqueued && wait(queue),
          "wide Metal reference must complete");
    std::vector<std::uint8_t> actual(cpu_frame.destination.size());
    std::memcpy(actual.data(), destination.contents, actual.size());
    const HaloMetrics expected_metrics = metrics(cpu_frame, expected);
    const HaloMetrics actual_metrics = metrics(cpu_frame, actual);
    for (int channel = 0; channel < 3; ++channel) {
        CHECK(expected_metrics.energy[channel] > 1.0e-4 && actual_metrics.energy[channel] > 1.0e-4,
              "wide parity halo energy must be nonzero");
        const double ratio = actual_metrics.energy[channel] / expected_metrics.energy[channel];
        CHECK(ratio > 0.20 && ratio < 5.0 &&
                  std::abs(actual_metrics.centroid_x[channel] - expected_metrics.centroid_x[channel]) < 120.0 &&
                  std::abs(actual_metrics.centroid_y[channel] - expected_metrics.centroid_y[channel]) < 120.0,
              "wide parity energy or centroid gate exceeded");
        std::fprintf(stderr, "wide parity channel %d energy cpu=%g metal=%g centroid cpu=(%g,%g) metal=(%g,%g)\n",
                     channel, expected_metrics.energy[channel], actual_metrics.energy[channel],
                     expected_metrics.centroid_x[channel], expected_metrics.centroid_y[channel],
                     actual_metrics.centroid_x[channel], actual_metrics.centroid_y[channel]);
    }
    [source release];
    [destination release];
    return 0;
}

} // namespace

int main()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) return fail("Metal device unavailable");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        if (queue == nil) return fail("Metal queue unavailable");
        if (const int result = runSmallParity(device, queue); result != 0) return result;
        if (const int result = runColorEmphasisParity(device, queue); result != 0) return result;
        if (const int result = runPyramidSafety(device, queue); result != 0) return result;
        if (const int result = runPyramidOddStrideAndDiagnostics(device, queue); result != 0) return result;
        if (const int result = runWideAggregateParity(device, queue); result != 0) return result;
        [queue release];
        [device release];
    }
    std::puts("halation_v2_metal_ticket08: PASS");
    return 0;
}
