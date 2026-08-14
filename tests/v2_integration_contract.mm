#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

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

#define CHECK(condition, message) do { if (!(condition)) { std::fprintf(stderr, "v2_integration_contract: %s\n", message); return 1; } } while (false)

struct Frame {
    DataWindow bounds;
    std::size_t row_bytes;
    std::vector<std::uint8_t> source;
    std::vector<std::uint8_t> cpu;
    id<MTLBuffer> metal_source = nil;
    id<MTLBuffer> metal_destination = nil;

    Frame(id<MTLDevice> device, int width, int height, int x, int y)
        : bounds{x, y, width, height}
        , row_bytes(static_cast<std::size_t>(width) * kPixelBytes + 32U)
        , source(row_bytes * static_cast<std::size_t>(height), 0U)
        , cpu(source.size(), 0xA5U)
        , metal_source([device newBufferWithLength:source.size() options:MTLResourceStorageModeShared])
        , metal_destination([device newBufferWithLength:source.size() options:MTLResourceStorageModeShared])
    {
        for (int row = 0; row < height; ++row) {
            for (int column = 0; column < width; ++column) {
                auto* value = reinterpret_cast<float*>(source.data() + static_cast<std::size_t>(row) * row_bytes +
                                                       static_cast<std::size_t>(column) * kPixelBytes);
                value[0] = 0.03F + 0.002F * static_cast<float>((column + row) % 17);
                value[1] = 0.05F + 0.003F * static_cast<float>((2 * column + row) % 13);
                value[2] = 0.07F + 0.002F * static_cast<float>((column + 3 * row) % 11);
                value[3] = (column % 19 == 0) ? 0.5F : 1.0F;
            }
        }
        std::memcpy(metal_source.contents, source.data(), source.size());
        std::memset(metal_destination.contents, 0xA5, source.size());
    }

    ~Frame() { [metal_source release]; [metal_destination release]; }
};

FrameSurface cpuSurface(void* bytes, const Frame& frame)
{
    return {MemoryKind::Cpu, PixelFormat::RgbaFloat32, bytes, 0U, frame.row_bytes, frame.bounds};
}

FrameSurface metalSurface(id<MTLBuffer> buffer, const Frame& frame)
{
    return {MemoryKind::Metal, PixelFormat::RgbaFloat32, (__bridge void*)buffer, 0U, frame.row_bytes, frame.bounds};
}

bool validWindowBytes(const std::uint8_t* bytes, const Frame& frame, RectI window)
{
    for (int y = window.y1; y < window.y2; ++y) {
        for (int x = window.x1; x < window.x2; ++x) {
            const std::size_t offset = static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                       static_cast<std::size_t>(x - frame.bounds.x) * kPixelBytes;
            const auto* source = reinterpret_cast<const float*>(frame.source.data() + offset);
            const auto* output = reinterpret_cast<const float*>(bytes + offset);
            if (!std::isfinite(output[0]) || !std::isfinite(output[1]) || !std::isfinite(output[2]) ||
                std::memcmp(&source[3], &output[3], sizeof(float)) != 0) return false;
        }
    }
    return true;
}

int runCase(id<MTLDevice> device, id<MTLCommandQueue> queue, EffectId effect, int width, int height)
{
    Frame frame(device, width, height, -7, 11);
    const int center_x = frame.bounds.x + width / 2;
    const int center_y = frame.bounds.y + height / 2;
    const RectI window{std::max(frame.bounds.x, center_x - 4), std::max(frame.bounds.y, center_y - 4),
                       std::min(frame.bounds.x + width, center_x + 4), std::min(frame.bounds.y + height, center_y + 4)};
    Settings settings = defaultSettings(effect);

    CpuRenderBackend cpu_backend;
    RenderRequest cpu_request{effect, cpuSurface(frame.source.data(), frame), cpuSurface(frame.cpu.data(), frame),
                              window, 19.0, {1.0, 1.0}, AlphaAssociation::Straight, settings};
    const RenderSubmission cpu_submission = render(cpu_request, cpu_backend);
    if (cpu_submission.kind != SubmissionKind::Completed || !validWindowBytes(frame.cpu.data(), frame, window)) return 1;

    MetalRenderBackend metal_backend((__bridge void*)queue);
    RenderRequest metal_request{effect, metalSurface(frame.metal_source, frame), metalSurface(frame.metal_destination, frame),
                                window, 19.0, {1.0, 1.0}, AlphaAssociation::Straight, settings};
    const RenderSubmission metal_submission = render(metal_request, metal_backend);
    if (metal_submission.kind != SubmissionKind::Enqueued) return 1;
    id<MTLCommandBuffer> sentinel = [queue commandBuffer];
    if (sentinel == nil) return 1;
    [sentinel commit];
    [sentinel waitUntilCompleted];
    if (sentinel.status != MTLCommandBufferStatusCompleted ||
        !validWindowBytes(static_cast<const std::uint8_t*>(frame.metal_destination.contents), frame, window)) return 1;

    CHECK(setSetting(settings, "mix", 0.0), "Mix identity setup failed");
    std::fill(frame.cpu.begin(), frame.cpu.end(), 0xA5U);
    std::memset(frame.metal_destination.contents, 0xA5, frame.source.size());
    cpu_request.settings = settings;
    metal_request.settings = settings;
    CHECK(render(cpu_request, cpu_backend).kind == SubmissionKind::Completed, "CPU identity render failed");
    CHECK(render(metal_request, metal_backend).kind == SubmissionKind::Enqueued, "Metal identity render failed");
    sentinel = [queue commandBuffer];
    CHECK(sentinel != nil, "Metal identity sentinel creation failed");
    [sentinel commit];
    [sentinel waitUntilCompleted];
    for (int y = window.y1; y < window.y2; ++y) {
        const std::size_t offset = static_cast<std::size_t>(y - frame.bounds.y) * frame.row_bytes +
                                   static_cast<std::size_t>(window.x1 - frame.bounds.x) * kPixelBytes;
        const std::size_t length = static_cast<std::size_t>(window.x2 - window.x1) * kPixelBytes;
        CHECK(std::memcmp(frame.source.data() + offset, frame.cpu.data() + offset, length) == 0,
              "CPU identity is not bit exact");
        CHECK(std::memcmp(frame.source.data() + offset,
                          static_cast<const std::uint8_t*>(frame.metal_destination.contents) + offset, length) == 0,
              "Metal identity is not bit exact");
    }
    return 0;
}

} // namespace

int main()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        CHECK(device != nil, "Metal device unavailable");
        id<MTLCommandQueue> queue = [device newCommandQueue];
        CHECK(queue != nil, "Metal queue unavailable");
        constexpr std::array<EffectId, 5> effects = {EffectId::Halation, EffectId::FilmGrain, EffectId::OpticalBlur,
                                                     EffectId::LensReflections, EffectId::MistDiffusion};
        for (const EffectId effect : effects) {
            CHECK(runCase(device, queue, effect, 8192, 8) == 0, "8K-wide public render seam failed");
            CHECK(runCase(device, queue, effect, 8, 8192) == 0, "8K-tall public render seam failed");
            CHECK(runCase(device, queue, effect, 12288, 8) == 0, "12K-wide public render seam failed");
            CHECK(runCase(device, queue, effect, 8, 12288) == 0, "12K-tall public render seam failed");
        }
        [queue release];
        [device release];
    }
    std::puts("v2_integration_contract: PASS (five effects, CPU+Metal, 8K/12K, alpha, bit-exact identity)");
    return 0;
}
