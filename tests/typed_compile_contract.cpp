#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <limits>
#include <vector>

#include "cbef/RenderCore.h"

namespace {

using cbef::AlphaAssociation;
using cbef::CpuRenderBackend;
using cbef::DataWindow;
using cbef::EffectId;
using cbef::Error;
using cbef::FrameSurface;
using cbef::MemoryKind;
using cbef::PixelFormat;
using cbef::RectI;
using cbef::RenderRequest;
using cbef::RenderScale;
using cbef::Settings;
using cbef::SubmissionKind;

constexpr std::size_t kRgbaBytes = sizeof(float) * 4U;

int fail(const char* message)
{
    std::fprintf(stderr, "typed_compile_contract: %s\n", message);
    return 1;
}

#define CHECK(condition, message) \
    do { \
        if (!(condition)) { \
            return fail(message); \
        } \
    } while (false)

struct Frame {
    DataWindow bounds{3, -2, 3, 2};
    std::size_t row_bytes = 64U;
    std::vector<std::uint8_t> source = std::vector<std::uint8_t>(row_bytes * 2U, 0U);
    std::vector<std::uint8_t> destination = std::vector<std::uint8_t>(row_bytes * 2U, 0xA5U);
};

FrameSurface surface(void* data, const Frame& frame)
{
    return FrameSurface{MemoryKind::Cpu, PixelFormat::RgbaFloat32, data, 0U, frame.row_bytes, frame.bounds};
}

float* pixel(std::vector<std::uint8_t>& storage, const Frame& frame, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - frame.bounds.y);
    const std::size_t column = static_cast<std::size_t>(x - frame.bounds.x);
    return reinterpret_cast<float*>(storage.data() + row * frame.row_bytes + column * kRgbaBytes);
}

const float* pixel(const std::vector<std::uint8_t>& storage, const Frame& frame, int x, int y)
{
    const std::size_t row = static_cast<std::size_t>(y - frame.bounds.y);
    const std::size_t column = static_cast<std::size_t>(x - frame.bounds.x);
    return reinterpret_cast<const float*>(storage.data() + row * frame.row_bytes + column * kRgbaBytes);
}

RenderRequest requestFor(Frame& frame, EffectId effect)
{
    return RenderRequest{effect,
                         surface(frame.source.data(), frame),
                         surface(frame.destination.data(), frame),
                         RectI{frame.bounds.x, frame.bounds.y, frame.bounds.x + frame.bounds.width,
                               frame.bounds.y + frame.bounds.height},
                         12.0,
                         RenderScale{1.0, 1.0},
                         AlphaAssociation::Straight,
                         cbef::defaultSettings(effect)};
}

const char* firstDoubleParameter(EffectId effect)
{
    switch (effect) {
    case EffectId::Halation:
        return "amount";
    case EffectId::FilmGrain:
        return "amount";
    case EffectId::OpticalBlur:
        return "blur";
    case EffectId::LensReflections:
        return "amount";
    case EffectId::MistDiffusion:
        return "diffusion";
    }
    return "amount";
}

bool finiteFrame(const Frame& frame)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float* value = pixel(frame.destination, frame, x, y);
            for (int channel = 0; channel < 4; ++channel) {
                if (!std::isfinite(value[channel])) {
                    return false;
                }
            }
        }
    }
    return true;
}

bool pixelsEqual(const Frame& frame)
{
    for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
        for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
            const float* source = pixel(frame.source, frame, x, y);
            const float* destination = pixel(frame.destination, frame, x, y);
            if (std::memcmp(source, destination, kRgbaBytes) != 0) {
                return false;
            }
        }
    }
    return true;
}

int run()
{
    constexpr std::array<EffectId, 5> effects = {
        EffectId::Halation,
        EffectId::FilmGrain,
        EffectId::OpticalBlur,
        EffectId::LensReflections,
        EffectId::MistDiffusion,
    };
    CpuRenderBackend backend;

    for (EffectId effect : effects) {
        Frame frame;
        for (int y = frame.bounds.y; y < frame.bounds.y + frame.bounds.height; ++y) {
            for (int x = frame.bounds.x; x < frame.bounds.x + frame.bounds.width; ++x) {
                float* value = pixel(frame.source, frame, x, y);
                value[0] = 0.18F + static_cast<float>(x - frame.bounds.x) * 0.05F;
                value[1] = 0.24F + static_cast<float>(y - frame.bounds.y) * 0.04F;
                value[2] = 0.31F;
                value[3] = 1.0F;
            }
        }
        RenderRequest request = requestFor(frame, effect);
        if (effect == EffectId::Halation) {
            CHECK(cbef::setSetting(request.settings, "color_emphasis", 4) &&
                      cbef::setSetting(request.settings, "color_strength", 100.0),
                  "Halation Auto color mode must compile from typed settings");
        }
        CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
              "each typed effect plan must render through the CPU contract");
        CHECK(finiteFrame(frame), "compiled effect output must remain finite");

        request = requestFor(frame, effect);
        const std::vector<std::uint8_t> source = frame.source;
        CHECK(cbef::setSetting(request.settings, "mix", 0.0), "Mix must be mutable for every effect");
        CHECK(cbef::render(request, backend).kind == SubmissionKind::Completed,
              "Mix zero must remain an identity render");
        CHECK(pixelsEqual(frame),
              "Mix zero must preserve the source bytes");
        CHECK(frame.source == source, "identity render must not mutate the source");

        request = requestFor(frame, effect);
        CHECK(cbef::setSetting(request.settings, firstDoubleParameter(effect),
                               std::numeric_limits<double>::quiet_NaN()),
              "effect-specific setting must accept the non-finite test value");
        const cbef::RenderSubmission rejected = cbef::render(request, backend);
        CHECK(rejected.kind == SubmissionKind::Failed && rejected.error == Error::NonFiniteSetting,
              "non-finite values must be rejected before compilation");
    }

    Frame mismatch_frame;
    RenderRequest mismatch = requestFor(mismatch_frame, EffectId::Halation);
    mismatch.settings = cbef::defaultSettings(EffectId::FilmGrain);
    const cbef::RenderSubmission mismatch_result = cbef::render(mismatch, backend);
    CHECK(mismatch_result.kind == SubmissionKind::Failed && mismatch_result.error == Error::SettingsTypeMismatch,
          "a typed plan must reject settings belonging to another effect");
    return 0;
}

}

int main()
{
    return run();
}
