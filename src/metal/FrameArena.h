#pragma once

#import <Metal/Metal.h>

#include <cstddef>
#include <memory>

namespace cbef::detail {

class FrameArena {
private:
    struct Slot;
    struct BatchState;

public:
    class Scope {
    public:
        Scope() noexcept;
        Scope(Scope&& other) noexcept;
        Scope& operator=(Scope&& other) noexcept;
        Scope(const Scope&) = delete;
        Scope& operator=(const Scope&) = delete;
        ~Scope();

        id<MTLBuffer> acquire(id<MTLDevice> device, std::size_t length);
        id<MTLBuffer> acquireBytes(id<MTLDevice> device, const void* bytes, std::size_t length);
        bool commit(id<MTLCommandBuffer> command_buffer);

    private:
        friend class FrameArena;
        Scope(FrameArena* owner, std::shared_ptr<BatchState> state) noexcept;

        FrameArena* owner_;
        std::shared_ptr<BatchState> state_;
        bool committed_;
    };

    explicit FrameArena(id<MTLDevice> device);
    ~FrameArena();

    FrameArena(const FrameArena&) = delete;
    FrameArena& operator=(const FrameArena&) = delete;

    Scope begin();

private:
    friend class Scope;

    id<MTLBuffer> acquireBuffer(const std::shared_ptr<BatchState>& state, id<MTLDevice> device,
                                 std::size_t length);
    void cancel(const std::shared_ptr<BatchState>& state);
    void complete(const std::shared_ptr<BatchState>& state);

    struct Impl;
    std::unique_ptr<Impl> impl_;
};

FrameArena* sharedFrameArenaFor(id<MTLCommandQueue> queue);

}
