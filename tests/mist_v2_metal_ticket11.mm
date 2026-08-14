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
constexpr std::size_t kPixelBytes = sizeof(float) * 4U;
constexpr std::uint8_t kSentinel = 0xA5U;

int fail(const char* message) { std::fprintf(stderr, "mist_v2_metal_ticket11: %s\n", message); return 1; }
#define CHECK(condition, message) do { if (!(condition)) return fail(message); } while (false)

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> destination;
    Frame(int width, int height, int x, int y)
        : bounds{x, y, width, height}, row_bytes(static_cast<std::size_t>(width) * kPixelBytes + 32U),
          source(row_bytes * static_cast<std::size_t>(height), 0U), destination(source.size(), kSentinel) {
        for (int yy = bounds.y; yy < bounds.y + bounds.height; ++yy) {
            for (int xx = bounds.x; xx < bounds.x + bounds.width; ++xx) {
                float* p = pixel(source, xx, yy);
                const float value = 0.025F + 0.002F * static_cast<float>((xx - x) % 11) +
                                    0.003F * static_cast<float>((yy - y) % 7);
                p[0] = value;
                p[1] = value * 0.82F;
                p[2] = value * 0.61F;
                p[3] = 0.35F + 0.02F * static_cast<float>((xx + yy) % 17);
            }
        }
        float* highlight = pixel(source, bounds.x + width / 2, bounds.y + height / 2);
        highlight[0] = 3.2F; highlight[1] = 1.8F; highlight[2] = 0.7F;
        float* transparent = pixel(source, bounds.x + 2, bounds.y + 3);
        transparent[0] = 100.0F; transparent[1] = -20.0F; transparent[2] = 8.0F; transparent[3] = 0.0F;
    }
    float* pixel(std::vector<std::uint8_t>& storage, int x, int y) const {
        return reinterpret_cast<float*>(storage.data() + static_cast<std::size_t>(y - bounds.y) * row_bytes +
                                        static_cast<std::size_t>(x - bounds.x) * kPixelBytes);
    }
    const float* pixel(const std::vector<std::uint8_t>& storage, int x, int y) const {
        return reinterpret_cast<const float*>(storage.data() + static_cast<std::size_t>(y - bounds.y) * row_bytes +
                                              static_cast<std::size_t>(x - bounds.x) * kPixelBytes);
    }
};

FrameSurface surface(MemoryKind kind, void* data, const Frame& frame) {
    return FrameSurface{kind, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, frame.bounds};
}

RenderRequest requestFor(Frame& frame) {
    return RenderRequest{EffectId::MistDiffusion, surface(MemoryKind::Cpu, frame.source.data(), frame),
                         surface(MemoryKind::Cpu, frame.destination.data(), frame),
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height}, 0.0, RenderScale{1.0, 1.0},
                         AlphaAssociation::Premultiplied, defaultSettings(EffectId::MistDiffusion)};
}

bool wait(id<MTLCommandQueue> queue) {
    id<MTLCommandBuffer> sentinel = [queue commandBuffer];
    if (sentinel == nil) return false;
    [sentinel commit]; [sentinel waitUntilCompleted];
    return sentinel.status == MTLCommandBufferStatusCompleted;
}

bool setDouble(Settings& settings, const char* id, double value) {
    return setSetting(settings, id, value);
}

int parity(id<MTLDevice> device, id<MTLCommandQueue> queue) {
    for (const int mode : {0, 1}) {
        for (const int grade : {0, 2, 4}) {
            for (const int view : {0, 1, 2, 3, 4, 5, 6}) {
                Frame frame(37, 23, -5, 7);
                RenderRequest cpu = requestFor(frame);
                CHECK(setSetting(cpu.settings, "working_mode", 1) && setSetting(cpu.settings, "mode", mode) &&
                          setSetting(cpu.settings, "density", grade) && setSetting(cpu.settings, "output_view", view) &&
                          setDouble(cpu.settings, "diffusion", 68.0) && setDouble(cpu.settings, "bloom", 57.0) &&
                          setDouble(cpu.settings, "contrast", 36.0) && setDouble(cpu.settings, "texture", 43.0),
                      "Mist v2 settings must be accepted");
                cpu.render_window = RectI{-3, 9, 27, 27};
                CpuRenderBackend cpu_backend;
                const RenderSubmission cpu_submission = render(cpu, cpu_backend);
                if (cpu_submission.kind != SubmissionKind::Completed) {
                    std::fprintf(stderr, "cpu submit failed mode=%d grade=%d view=%d error=%d\n", mode, grade, view,
                                 static_cast<int>(cpu_submission.error));
                    return fail("CPU Mist v2 must complete");
                }
                const std::vector<std::uint8_t> expected = frame.destination;
                id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
                id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
                CHECK(source != nil && destination != nil, "Mist v2 Metal buffers must allocate");
                std::memcpy(source.contents, frame.source.data(), frame.source.size());
                std::memset(destination.contents, kSentinel, frame.destination.size());
                RenderRequest metal = cpu;
                metal.source = surface(MemoryKind::Metal, (__bridge void*)source, frame);
                metal.destination = surface(MemoryKind::Metal, (__bridge void*)destination, frame);
                MetalRenderBackend backend((__bridge void*)queue);
                CHECK(render(metal, backend).kind == SubmissionKind::Enqueued && wait(queue),
                      "Metal Mist v2 must enqueue and complete");
                std::vector<std::uint8_t> actual(frame.destination.size(), 0U);
                std::memcpy(actual.data(), destination.contents, actual.size());
                float max_error = 0.0F;
                for (int y = cpu.render_window.y1; y < cpu.render_window.y2; ++y) {
                    for (int x = cpu.render_window.x1; x < cpu.render_window.x2; ++x) {
                        const float* e = frame.pixel(expected, x, y);
                        const float* a = frame.pixel(actual, x, y);
                        for (int c = 0; c < 3; ++c) max_error = std::max(max_error, std::abs(e[c] - a[c]));
                        std::uint32_t ea = 0U, aa = 0U;
                        std::memcpy(&ea, e + 3, sizeof(ea)); std::memcpy(&aa, a + 3, sizeof(aa));
                        CHECK(ea == aa, "Mist v2 Metal must preserve alpha bits");
                    }
                }
                CHECK(max_error <= 2.0e-4F, "Mist v2 CPU/Metal parity exceeded 2e-4");
                CHECK(static_cast<const std::uint8_t*>(destination.contents)[0] == kSentinel,
                      "Mist v2 Metal must preserve crop-outside bytes");
                [source release]; [destination release];
            }
        }
    }
    return 0;
}

int identity(id<MTLDevice> device, id<MTLCommandQueue> queue) {
    Frame frame(19, 13, 4, -2);
    RenderRequest request = requestFor(frame);
    CHECK(setSetting(request.settings, "mix", 0.0), "Mist identity mix must be accepted");
    id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
    id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
    CHECK(source != nil && destination != nil, "identity buffers must allocate");
    std::memcpy(source.contents, frame.source.data(), frame.source.size());
    std::memset(destination.contents, kSentinel, frame.destination.size());
    request.source = surface(MemoryKind::Metal, (__bridge void*)source, frame);
    request.destination = surface(MemoryKind::Metal, (__bridge void*)destination, frame);
    MetalRenderBackend backend((__bridge void*)queue);
    CHECK(render(request, backend).kind == SubmissionKind::Enqueued && wait(queue), "identity must complete");
    std::vector<std::uint8_t> actual(frame.destination.size());
    std::memcpy(actual.data(), destination.contents, actual.size());
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            CHECK(std::memcmp(frame.pixel(frame.source, x, y), frame.pixel(actual, x, y), kPixelBytes) == 0,
                  "identity must preserve source bits");
        }
    }
    [source release]; [destination release];
    return 0;
}

int strongWhitePolarity(id<MTLDevice> device, id<MTLCommandQueue> queue) {
    Frame frame(257, 129, 0, 0);
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            float* value = frame.pixel(frame.source, x, y);
            const float level = x >= 96 && x < 161 && y >= 16 && y < 113 ? 0.78F : 0.08F;
            value[0] = value[1] = value[2] = level;
            value[3] = 1.0F;
        }
    }
    RenderRequest cpu = requestFor(frame);
    cpu.settings = settingsForPreset(EffectId::MistDiffusion, 9U);
    CHECK(setSetting(cpu.settings, "working_mode", 0) && setSetting(cpu.settings, "output_view", 0) &&
              setDouble(cpu.settings, "mix", 100.0),
          "Generic White 2 polarity settings must be accepted");
    CpuRenderBackend cpu_backend;
    CHECK(render(cpu, cpu_backend).kind == SubmissionKind::Completed,
          "Generic White 2 CPU polarity reference must complete");
    const std::vector<std::uint8_t> expected = frame.destination;

    id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
    id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
    CHECK(source != nil && destination != nil, "Generic White 2 polarity buffers must allocate");
    std::memcpy(source.contents, frame.source.data(), frame.source.size());
    std::memset(destination.contents, kSentinel, frame.destination.size());
    RenderRequest metal = cpu;
    metal.source = surface(MemoryKind::Metal, (__bridge void*)source, frame);
    metal.destination = surface(MemoryKind::Metal, (__bridge void*)destination, frame);
    MetalRenderBackend backend((__bridge void*)queue);
    CHECK(render(metal, backend).kind == SubmissionKind::Enqueued && wait(queue),
          "Generic White 2 Metal polarity render must complete");
    const std::uint8_t* actual = static_cast<const std::uint8_t*>(destination.contents);
    float maximum_error = 0.0F;
    float minimum = 1.0F;
    float maximum = 0.0F;
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            const float* expected_pixel = frame.pixel(expected, x, y);
            const float* actual_pixel = reinterpret_cast<const float*>(
                actual + static_cast<std::size_t>(y) * frame.row_bytes + static_cast<std::size_t>(x) * kPixelBytes);
            for (int channel = 0; channel < 3; ++channel) {
                maximum_error = std::max(maximum_error, std::abs(expected_pixel[channel] - actual_pixel[channel]));
                minimum = std::min(minimum, actual_pixel[channel]);
                maximum = std::max(maximum, actual_pixel[channel]);
            }
        }
    }
    CHECK(maximum_error <= 2.0e-4F, "Generic White 2 CPU/Metal polarity parity exceeded 2e-4");
    CHECK(minimum >= -1.0e-5F,
          "Generic White 2 Metal must not create negative-polarity outlines from non-negative input");
    CHECK(maximum <= 0.78001F,
          "Generic White 2 Metal must not overshoot the brightest source across a hard edge");
    const float* edge_outside = reinterpret_cast<const float*>(
        actual + static_cast<std::size_t>(64) * frame.row_bytes + static_cast<std::size_t>(95) * kPixelBytes);
    const float* edge_inside = reinterpret_cast<const float*>(
        actual + static_cast<std::size_t>(64) * frame.row_bytes + static_cast<std::size_t>(96) * kPixelBytes);
    CHECK(edge_outside[1] <= edge_inside[1] + 1.0e-5F,
          "Generic White 2 Metal must not reverse edge polarity into a bright exterior outline");
    [source release]; [destination release];
    return 0;
}

int strongWhitePyramidPolarity(id<MTLDevice> device, id<MTLCommandQueue> queue) {
    Frame frame(1056, 576, 0, 0);
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            float* value = frame.pixel(frame.source, x, y);
            const float level = x >= 384 && x < 672 && y >= 96 && y < 480 ? 0.78F : 0.08F;
            value[0] = value[1] = value[2] = level;
            value[3] = 1.0F;
        }
    }
    RenderRequest request = requestFor(frame);
    request.settings = settingsForPreset(EffectId::MistDiffusion, 9U);
    CHECK(setSetting(request.settings, "working_mode", 0) && setSetting(request.settings, "output_view", 0) &&
              setDouble(request.settings, "mix", 100.0),
          "Generic White 2 pyramid polarity settings must be accepted");
    id<MTLBuffer> source = [device newBufferWithLength:frame.source.size() options:MTLResourceStorageModeShared];
    id<MTLBuffer> destination = [device newBufferWithLength:frame.destination.size() options:MTLResourceStorageModeShared];
    CHECK(source != nil && destination != nil, "Generic White 2 pyramid buffers must allocate");
    std::memcpy(source.contents, frame.source.data(), frame.source.size());
    std::memset(destination.contents, kSentinel, frame.destination.size());
    request.source = surface(MemoryKind::Metal, (__bridge void*)source, frame);
    request.destination = surface(MemoryKind::Metal, (__bridge void*)destination, frame);
    MetalRenderBackend backend((__bridge void*)queue);
    CHECK(render(request, backend).kind == SubmissionKind::Enqueued && wait(queue),
          "Generic White 2 Metal pyramid render must complete");
    const std::uint8_t* actual = static_cast<const std::uint8_t*>(destination.contents);
    float minimum = 1.0F;
    float maximum = 0.0F;
    for (int y = 0; y < frame.bounds.height; ++y) {
        for (int x = 0; x < frame.bounds.width; ++x) {
            const float* value = reinterpret_cast<const float*>(
                actual + static_cast<std::size_t>(y) * frame.row_bytes + static_cast<std::size_t>(x) * kPixelBytes);
            for (int channel = 0; channel < 3; ++channel) {
                CHECK(std::isfinite(value[channel]), "Generic White 2 pyramid output must remain finite");
                minimum = std::min(minimum, value[channel]);
                maximum = std::max(maximum, value[channel]);
            }
        }
    }
    CHECK(minimum >= -1.0e-5F,
          "Generic White 2 Metal pyramid must not create negative-polarity outlines");
    CHECK(maximum <= 0.78001F,
          "Generic White 2 Metal pyramid must not overshoot the brightest source");
    const float* edge_outside = reinterpret_cast<const float*>(
        actual + static_cast<std::size_t>(288) * frame.row_bytes + static_cast<std::size_t>(383) * kPixelBytes);
    const float* edge_inside = reinterpret_cast<const float*>(
        actual + static_cast<std::size_t>(288) * frame.row_bytes + static_cast<std::size_t>(384) * kPixelBytes);
    CHECK(edge_outside[1] <= edge_inside[1] + 1.0e-5F,
          "Generic White 2 Metal pyramid must not reverse edge polarity into an exterior outline");
    [source release]; [destination release];
    return 0;
}

} // namespace

int main() {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) return fail("Metal device unavailable");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        if (queue == nil) return fail("Metal queue unavailable");
        if (const int result = parity(device, queue); result != 0) return result;
        if (const int result = identity(device, queue); result != 0) return result;
        if (const int result = strongWhitePolarity(device, queue); result != 0) return result;
        if (const int result = strongWhitePyramidPolarity(device, queue); result != 0) return result;
        std::puts("mist_v2_metal_ticket11: PASS");
        [queue release];
    }
    return 0;
}
