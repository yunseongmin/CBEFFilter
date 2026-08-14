#import <Metal/Metal.h>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include "cbef/RenderCore.h"

namespace {

using namespace cbef;
constexpr std::size_t kPixelBytes = sizeof(float) * 4U;

struct MetalFrame {
    int width;
    int height;
    std::size_t row_bytes;
    std::size_t byte_length;
    id<MTLBuffer> source;
    id<MTLBuffer> destination;

    MetalFrame(id<MTLDevice> device, int frame_width, int frame_height)
        : width(frame_width)
        , height(frame_height)
        , row_bytes(static_cast<std::size_t>(frame_width) * kPixelBytes)
        , byte_length(row_bytes * static_cast<std::size_t>(frame_height))
        , source([device newBufferWithLength:byte_length options:MTLResourceStorageModeShared])
        , destination([device newBufferWithLength:byte_length options:MTLResourceStorageModeShared])
    {
    }

    ~MetalFrame()
    {
        [source release];
        [destination release];
    }

    MetalFrame(const MetalFrame&) = delete;
    MetalFrame& operator=(const MetalFrame&) = delete;
};

float* pixel(id<MTLBuffer> buffer, const MetalFrame& frame, int x, int y)
{
    auto* bytes = static_cast<std::uint8_t*>(buffer.contents);
    return reinterpret_cast<float*>(bytes + static_cast<std::size_t>(y) * frame.row_bytes +
                                    static_cast<std::size_t>(x) * kPixelBytes);
}

void fillFrame(MetalFrame& frame, float bias)
{
    for (int y = 0; y < frame.height; ++y) {
        for (int x = 0; x < frame.width; ++x) {
            float* value = pixel(frame.source, frame, x, y);
            const float signal = 0.05F + 0.9F * static_cast<float>((x + y) % 97) / 96.0F + bias;
            value[0] = signal;
            value[1] = signal * 0.82F;
            value[2] = signal * 0.64F;
            value[3] = 1.0F;
        }
    }
    std::memset(frame.destination.contents, 0xA5, frame.byte_length);
}

FrameSurface surface(id<MTLBuffer> buffer, const MetalFrame& frame)
{
    return FrameSurface{MemoryKind::Metal,
                        PixelFormat::RgbaFloat32,
                        (__bridge void*)buffer,
                        0U,
                        frame.row_bytes,
                        DataWindow{0, 0, frame.width, frame.height}};
}

RenderRequest requestFor(MetalFrame& frame)
{
    RenderRequest request{EffectId::LensReflections,
                          surface(frame.source, frame),
                          surface(frame.destination, frame),
                          RectI{0, 0, frame.width, frame.height},
                          0.0,
                          RenderScale{1.0, 1.0},
                          AlphaAssociation::Straight,
                          defaultSettings(EffectId::LensReflections)};
    setSetting(request.settings, "amount", 100.0);
    setSetting(request.settings, "spread", 110.0);
    setSetting(request.settings, "blur", 0.85);
    setSetting(request.settings, "chroma", 35.0);
    return request;
}

bool waitOnQueue(id<MTLCommandQueue> queue)
{
    id<MTLCommandBuffer> sentinel = [queue commandBuffer];
    if (sentinel == nil) return false;
    [sentinel commit];
    [sentinel waitUntilCompleted];
    return sentinel.status == MTLCommandBufferStatusCompleted;
}

std::uint64_t numberAfter(const std::string& line, const std::string& key)
{
    const std::string token = "\"" + key + "\":";
    const std::size_t position = line.find(token);
    if (position == std::string::npos) return 0U;
    const std::size_t start = position + token.size();
    return static_cast<std::uint64_t>(std::strtoull(line.c_str() + start, nullptr, 10));
}

bool hasTrue(const std::string& line, const std::string& key)
{
    return line.find("\"" + key + "\":true") != std::string::npos;
}

struct TraceResult {
    std::size_t acquire_count = 0U;
    std::size_t complete_count = 0U;
    std::size_t cancel_count = 0U;
    std::size_t reused_count = 0U;
    std::size_t max_active = 0U;
    std::uint64_t allocations_total = 0U;
    std::uint64_t peak_bytes = 0U;
    bool reused_slot_while_active = false;
    bool cancellation_clean = false;
};

TraceResult readTrace(const std::string& path)
{
    TraceResult result;
    std::ifstream input(path);
    std::map<std::uint64_t, std::vector<std::size_t>> batches;
    std::set<std::size_t> active;
    std::string line;
    while (std::getline(input, line)) {
        const std::uint64_t batch = numberAfter(line, "batch");
        const std::string event = line.find("\"event\":\"") == std::string::npos ? "" :
            line.substr(line.find("\"event\":\"") + 9U, line.find('"', line.find("\"event\":\"") + 9U) -
                                                        (line.find("\"event\":\"") + 9U));
        if (event == "acquire") {
            ++result.acquire_count;
            const std::size_t slot = static_cast<std::size_t>(numberAfter(line, "slot"));
            if (active.find(slot) != active.end()) result.reused_slot_while_active = true;
            active.insert(slot);
            batches[batch].push_back(slot);
            result.max_active = std::max(result.max_active, active.size());
            if (hasTrue(line, "reused")) ++result.reused_count;
            result.allocations_total = std::max(result.allocations_total, numberAfter(line, "allocations_total"));
            result.peak_bytes = std::max(result.peak_bytes, numberAfter(line, "peak_in_flight_bytes"));
        } else if (event == "complete" || event == "cancel") {
            if (event == "complete") ++result.complete_count;
            else ++result.cancel_count;
            const auto found = batches.find(batch);
            if (found != batches.end()) {
                for (const std::size_t slot : found->second) active.erase(slot);
                batches.erase(found);
            }
            result.allocations_total = std::max(result.allocations_total, numberAfter(line, "allocations_total"));
            result.peak_bytes = std::max(result.peak_bytes, numberAfter(line, "peak_in_flight_bytes"));
            if (event == "cancel" && numberAfter(line, "in_flight_bytes") == 0U) result.cancellation_clean = true;
        }
    }
    return result;
}

TraceResult waitForCompletedTrace(const std::string& path, std::size_t expected_completions)
{
    TraceResult trace;
    for (int attempt = 0; attempt < 1000; ++attempt) {
        trace = readTrace(path);
        if (trace.complete_count >= expected_completions) return trace;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    return trace;
}

bool renderOne(MetalRenderBackend& backend, MetalFrame& frame)
{
    const RenderSubmission submission = render(requestFor(frame), backend);
    return submission.kind == SubmissionKind::Enqueued && submission.error == Error::None;
}

bool writeReport(const std::string& path, const TraceResult& trace, bool failure_cleanup, const std::string& failure)
{
    std::ofstream output(path);
    if (!output) return false;
    output << "{\n"
           << "  \"schema_version\": 1,\n"
           << "  \"acquire_count\": " << trace.acquire_count << ",\n"
           << "  \"complete_count\": " << trace.complete_count << ",\n"
           << "  \"cancel_count\": " << trace.cancel_count << ",\n"
           << "  \"reused_after_completion\": " << (trace.reused_count > 0U ? "true" : "false") << ",\n"
           << "  \"max_active_slots\": " << trace.max_active << ",\n"
           << "  \"reused_slot_while_active\": " << (trace.reused_slot_while_active ? "true" : "false") << ",\n"
           << "  \"allocations_total\": " << trace.allocations_total << ",\n"
           << "  \"peak_in_flight_bytes\": " << trace.peak_bytes << ",\n"
           << "  \"failure_cleanup\": " << (failure_cleanup ? "true" : "false") << ",\n"
           << "  \"failure\": \"" << failure << "\"\n"
           << "}\n";
    return true;
}

} 

int main()
{
    const std::string trace_path = std::getenv("CBEF_FRAME_ARENA_TRACE_PATH") != nullptr
        ? std::getenv("CBEF_FRAME_ARENA_TRACE_PATH") : ".omo/evidence/ticket-05-frame-arena.jsonl";
    const std::string report_path = std::getenv("CBEF_FRAME_ARENA_REPORT_PATH") != nullptr
        ? std::getenv("CBEF_FRAME_ARENA_REPORT_PATH") : ".omo/evidence/ticket-05-frame-arena.json";
    std::filesystem::create_directories(std::filesystem::path(trace_path).parent_path());
    std::remove(trace_path.c_str());
    setenv("CBEF_FRAME_ARENA_TRACE_PATH", trace_path.c_str(), 1);
    unsetenv("CBEF_FRAME_ARENA_FAIL_AFTER");

    bool success = true;
    std::string failure;
    TraceResult trace;
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        id<MTLCommandQueue> queue = device == nil ? nil : [device newCommandQueue];
        if (device == nil || queue == nil) {
            success = false;
            failure = "Metal device or queue unavailable";
        } else {
            id<MTLSharedEvent> gate_event = [device newSharedEvent];
            id<MTLCommandBuffer> gate = [queue commandBuffer];
            if (gate_event == nil || gate == nil) {
                success = false;
                failure = "shared-event gate unavailable";
            } else {
                [gate encodeWaitForEvent:gate_event value:1U];
                [gate commit];
                std::vector<std::unique_ptr<MetalFrame>> frames;
                for (int index = 0; index < 3; ++index) {
                    frames.push_back(std::make_unique<MetalFrame>(device, 1024, 1024));
                    fillFrame(*frames.back(), static_cast<float>(index) * 0.01F);
                }
                MetalRenderBackend backend((__bridge void*)queue);
                success = renderOne(backend, *frames[0]) && renderOne(backend, *frames[1]);
                gate_event.signaledValue = 1U;
                success = success && waitOnQueue(queue);
                success = success && renderOne(backend, *frames[2]) && waitOnQueue(queue);
                [gate_event release];
            }
            [queue release];
        }
        [device release];
    }

    setenv("CBEF_FRAME_ARENA_FAIL_AFTER", "0", 1);
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        id<MTLCommandQueue> queue = device == nil ? nil : [device newCommandQueue];
        if (device == nil || queue == nil) {
            success = false;
            failure = "Metal device or queue unavailable for failure case";
        } else {
            MetalFrame frame(device, 256, 256);
            fillFrame(frame, 0.0F);
            MetalRenderBackend backend((__bridge void*)queue);
            const RenderSubmission submission = render(requestFor(frame), backend);
            if (submission.kind != SubmissionKind::Failed || submission.error != Error::TemporaryAllocationFailed) {
                success = false;
                failure = "arena allocation failure did not map to TemporaryAllocationFailed";
            }
            [queue release];
        }
        [device release];
    }
    unsetenv("CBEF_FRAME_ARENA_FAIL_AFTER");

    trace = waitForCompletedTrace(trace_path, 3U);
    const bool behavior = trace.acquire_count > 0U && trace.complete_count >= 3U && trace.max_active >= 2U &&
                          trace.reused_count > 0U && !trace.reused_slot_while_active && trace.peak_bytes > 0U;
    const bool cleanup = trace.cancel_count > 0U && trace.cancellation_clean;
    const bool report_written = writeReport(report_path, trace, cleanup, failure);
    if (!success || !behavior || !cleanup || !report_written) {
        std::fprintf(stderr,
                     "frame_arena_contract: phases=%d behavior=%d cleanup=%d report=%d acquire=%zu complete=%zu "
                     "reuse=%zu active=%zu overlap=%d peak=%llu cancel=%zu clean=%d\n",
                     success, behavior, cleanup, report_written, trace.acquire_count, trace.complete_count,
                     trace.reused_count, trace.max_active, trace.reused_slot_while_active,
                     static_cast<unsigned long long>(trace.peak_bytes), trace.cancel_count,
                     trace.cancellation_clean);
    }
    success = success && behavior && cleanup && report_written;
    std::printf("frame_arena_contract: %s\nREPORT: %s\nTRACE: %s\n",
                success ? "PASS" : "FAIL", report_path.c_str(), trace_path.c_str());
    return success ? 0 : 1;
}
