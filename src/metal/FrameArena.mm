#import "FrameArena.h"

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <mutex>
#include <new>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace cbef::detail {
namespace {

std::mutex trace_mutex;

void traceLine(const std::string& line)
{
    const char* path = std::getenv("CBEF_FRAME_ARENA_TRACE_PATH");
    if (path == nullptr || path[0] == '\0') return;
    std::lock_guard<std::mutex> lock(trace_mutex);
    std::ofstream output(path, std::ios::app);
    if (output) output << line << '\n';
}

}

struct ArenaSlot {
    id<MTLBuffer> buffer = nil;
    std::size_t capacity = 0U;
    bool in_flight = false;
};

struct FrameArena::BatchState {
    FrameArena* owner = nullptr;
    std::uint64_t id = 0U;
    std::vector<std::size_t> slots;
    bool released = false;
};

struct FrameArena::Impl {
    explicit Impl(id<MTLDevice> input_device)
        : device([input_device retain])
    {
    }

    ~Impl()
    {
        for (ArenaSlot& slot : slots) [slot.buffer release];
        [device release];
    }

    id<MTLDevice> device = nil;
    std::mutex mutex;
    std::vector<ArenaSlot> slots;
    std::uint64_t next_batch_id = 1U;
    std::uint64_t allocation_count = 0U;
    std::uint64_t reuse_count = 0U;
    std::size_t in_flight_bytes = 0U;
    std::size_t peak_in_flight_bytes = 0U;
};

FrameArena::Scope::Scope() noexcept
    : owner_(nullptr)
    , state_()
    , committed_(true)
{
}

FrameArena::Scope::Scope(FrameArena* owner, std::shared_ptr<BatchState> state) noexcept
    : owner_(owner)
    , state_(std::move(state))
    , committed_(false)
{
}

FrameArena::Scope::Scope(Scope&& other) noexcept
    : owner_(other.owner_)
    , state_(std::move(other.state_))
    , committed_(other.committed_)
{
    other.owner_ = nullptr;
    other.committed_ = true;
}

FrameArena::Scope& FrameArena::Scope::operator=(Scope&& other) noexcept
{
    if (this == &other) return *this;
    if (!committed_ && owner_ != nullptr && state_) owner_->cancel(state_);
    owner_ = other.owner_;
    state_ = std::move(other.state_);
    committed_ = other.committed_;
    other.owner_ = nullptr;
    other.committed_ = true;
    return *this;
}

FrameArena::Scope::~Scope()
{
    if (!committed_ && owner_ != nullptr && state_) owner_->cancel(state_);
}

id<MTLBuffer> FrameArena::Scope::acquire(id<MTLDevice> device, std::size_t length)
{
    if (owner_ == nullptr || !state_ || committed_) return nil;
    return owner_->acquireBuffer(state_, device, length);
}

id<MTLBuffer> FrameArena::Scope::acquireBytes(id<MTLDevice> device, const void* bytes, std::size_t length)
{
    if (bytes == nullptr || length == 0U) return nil;
    id<MTLBuffer> buffer = acquire(device, length);
    if (buffer == nil) return nil;
    std::memcpy(buffer.contents, bytes, length);
    return buffer;
}

bool FrameArena::Scope::commit(id<MTLCommandBuffer> command_buffer)
{
    if (committed_ || command_buffer == nil) return false;
    committed_ = true;
    if (owner_ == nullptr || !state_ || state_->slots.empty()) return true;

    const std::shared_ptr<BatchState> state = state_;
    [command_buffer addCompletedHandler:^(id<MTLCommandBuffer>) {
        state->owner->complete(state);
    }];
    return true;
}

FrameArena::FrameArena(id<MTLDevice> device)
    : impl_(device != nil ? std::make_unique<Impl>(device) : nullptr)
{
}

FrameArena::~FrameArena() = default;

FrameArena::Scope FrameArena::begin()
{
    if (!impl_) return Scope();
    try {
        auto state = std::make_shared<BatchState>();
        {
            std::lock_guard<std::mutex> lock(impl_->mutex);
            state->owner = this;
            state->id = impl_->next_batch_id++;
        }
        return Scope(this, std::move(state));
    } catch (const std::bad_alloc&) {
        return Scope(this, nullptr);
    }
}

id<MTLBuffer> FrameArena::acquireBuffer(const std::shared_ptr<BatchState>& state, id<MTLDevice> device,
                                        std::size_t length)
{
    if (!impl_ || !state || state->released || device == nil || length == 0U ||
        length > static_cast<std::size_t>(NSUIntegerMax)) {
        return nil;
    }

    std::lock_guard<std::mutex> lock(impl_->mutex);
    if (state->released) return nil;
    const char* failure_after_value = std::getenv("CBEF_FRAME_ARENA_FAIL_AFTER");
    if (failure_after_value != nullptr && failure_after_value[0] != '\0' &&
        impl_->allocation_count >= std::strtoull(failure_after_value, nullptr, 10)) {
        std::ostringstream event;
        event << "{\"event\":\"allocation_failed\",\"batch\":" << state->id
              << ",\"in_flight_bytes\":" << impl_->in_flight_bytes << ",\"allocations_total\":"
              << impl_->allocation_count << ",\"peak_in_flight_bytes\":" << impl_->peak_in_flight_bytes << "}";
        traceLine(event.str());
        return nil;
    }

    std::size_t selected = impl_->slots.size();
    std::size_t selected_capacity = 0U;
    for (std::size_t index = 0U; index < impl_->slots.size(); ++index) {
        const ArenaSlot& slot = impl_->slots[index];
        if (slot.in_flight || slot.capacity < length) continue;
        if (selected == impl_->slots.size() || slot.capacity < selected_capacity) {
            selected = index;
            selected_capacity = slot.capacity;
        }
    }

    bool reused = selected != impl_->slots.size();
    if (!reused) {
        id<MTLBuffer> buffer = [device newBufferWithLength:static_cast<NSUInteger>(length)
                                                   options:MTLResourceStorageModeShared];
        if (buffer == nil) return nil;
        try {
            impl_->slots.push_back(ArenaSlot{buffer, length, false});
        } catch (const std::bad_alloc&) {
            [buffer release];
            return nil;
        }
        selected = impl_->slots.size() - 1U;
        selected_capacity = length;
        ++impl_->allocation_count;
    } else {
        ++impl_->reuse_count;
    }

    ArenaSlot& slot = impl_->slots[selected];
    slot.in_flight = true;
    try {
        state->slots.push_back(selected);
    } catch (const std::bad_alloc&) {
        slot.in_flight = false;
        return nil;
    }
    impl_->in_flight_bytes += selected_capacity;
    impl_->peak_in_flight_bytes = std::max(impl_->peak_in_flight_bytes, impl_->in_flight_bytes);

    std::ostringstream event;
    event << "{\"event\":\"acquire\",\"batch\":" << state->id << ",\"slot\":" << selected
          << ",\"capacity\":" << selected_capacity << ",\"reused\":" << (reused ? "true" : "false")
          << ",\"in_flight_bytes\":" << impl_->in_flight_bytes << ",\"allocations_total\":"
          << impl_->allocation_count << ",\"peak_in_flight_bytes\":" << impl_->peak_in_flight_bytes << "}";
    traceLine(event.str());
    return slot.buffer;
}

void FrameArena::cancel(const std::shared_ptr<BatchState>& state)
{
    if (!impl_ || !state) return;
    std::lock_guard<std::mutex> lock(impl_->mutex);
    if (state->released) return;
    state->released = true;
    for (const std::size_t index : state->slots) {
        if (index >= impl_->slots.size()) continue;
        ArenaSlot& slot = impl_->slots[index];
        if (slot.in_flight) {
            slot.in_flight = false;
            impl_->in_flight_bytes -= std::min(impl_->in_flight_bytes, slot.capacity);
        }
    }
    std::ostringstream event;
    event << "{\"event\":\"cancel\",\"batch\":" << state->id << ",\"slots\":" << state->slots.size()
          << ",\"in_flight_bytes\":" << impl_->in_flight_bytes << ",\"allocations_total\":"
          << impl_->allocation_count << ",\"peak_in_flight_bytes\":" << impl_->peak_in_flight_bytes << "}";
    traceLine(event.str());
}

void FrameArena::complete(const std::shared_ptr<BatchState>& state)
{
    if (!impl_ || !state) return;
    std::lock_guard<std::mutex> lock(impl_->mutex);
    if (state->released) return;
    state->released = true;
    for (const std::size_t index : state->slots) {
        if (index >= impl_->slots.size()) continue;
        ArenaSlot& slot = impl_->slots[index];
        if (slot.in_flight) {
            slot.in_flight = false;
            impl_->in_flight_bytes -= std::min(impl_->in_flight_bytes, slot.capacity);
        }
    }
    std::ostringstream event;
    event << "{\"event\":\"complete\",\"batch\":" << state->id << ",\"slots\":" << state->slots.size()
          << ",\"in_flight_bytes\":" << impl_->in_flight_bytes << ",\"allocations_total\":"
          << impl_->allocation_count << ",\"peak_in_flight_bytes\":" << impl_->peak_in_flight_bytes << "}";
    traceLine(event.str());
}

namespace {
std::mutex shared_arenas_mutex;
std::map<void*, std::unique_ptr<FrameArena>> shared_arenas;
}

FrameArena* sharedFrameArenaFor(id<MTLCommandQueue> queue)
{
    if (queue == nil || queue.device == nil) return nullptr;
    const void* key = (__bridge const void*)queue;
    std::lock_guard<std::mutex> lock(shared_arenas_mutex);
    const auto existing = shared_arenas.find(const_cast<void*>(key));
    if (existing != shared_arenas.end()) return existing->second.get();
    try {
        auto arena = std::make_unique<FrameArena>(queue.device);
        FrameArena* result = arena.get();
        shared_arenas.emplace(const_cast<void*>(key), std::move(arena));
        return result;
    } catch (const std::bad_alloc&) {
        return nullptr;
    }
}

}
