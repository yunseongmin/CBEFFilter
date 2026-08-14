#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>
#include <variant>
#include <vector>

namespace cbef {

enum class EffectId : std::uint8_t {
    Halation,
    FilmGrain,
    OpticalBlur,
    LensReflections,
    MistDiffusion,
};

enum class WorkingMode : int {
    DwgIntermediate = 0,
    DwgLinear = 1,
    Rec709Gamma24 = 2,
};

enum class AlphaAssociation : std::uint8_t {
    Straight,
    Premultiplied,
};

enum class MemoryKind : std::uint8_t {
    Cpu,
    Metal,
};

enum class PixelFormat : std::uint8_t {
    RgbaFloat32,
    Unsupported,
    AlphaFloat32,
};

enum class ParameterType : std::size_t {
    Double = 0,
    Integer = 1,
    Boolean = 2,
    Choice = 3,
};

enum class ParameterGroup : std::uint8_t {
    Basic,
    Advanced,
    Diagnostics,
};

enum class ParameterRole : std::uint8_t {
    EffectControl,
    Preset,
    WorkingMode,
    OutputView,
    Mix,
    Quality,
};

using SettingValue = std::variant<double, std::int64_t, bool, int>;

struct ParameterDefinition {
    const char* id;
    const char* label;
    const char* hint;
    ParameterType type;
    const char* unit;
    double minimum;
    double maximum;
    double increment;
    bool animatable;
    SettingValue default_value;
    std::vector<const char*> choices;
    ParameterGroup group = ParameterGroup::Advanced;
    ParameterRole role = ParameterRole::EffectControl;
    int display_order = 0;
    const char* enabled_when_parameter = nullptr;
    int enabled_when_choice = 0;
    bool secret = false;
};

struct ParameterAssignment {
    const char* parameter_id;
    SettingValue value;
};

struct PresetDefinition {
    const char* id;
    const char* label;
    std::vector<ParameterAssignment> assignments;
};

struct EffectDefinition {
    EffectId effect;
    const char* identifier;
    const char* label;
    const char* description;
    std::vector<ParameterDefinition> parameters;
    std::vector<PresetDefinition> presets;
    std::size_t default_preset;
};

struct Settings {
    EffectId effect;
    std::vector<SettingValue> values;
};

const std::vector<EffectDefinition>& effectDefinitions();
const EffectDefinition& effectDefinition(EffectId effect);
Settings defaultSettings(EffectId effect);
Settings settingsForPreset(EffectId effect, std::size_t preset_index);
bool setSetting(Settings& settings, std::string_view parameter_id, SettingValue value);
const SettingValue& settingValue(const Settings& settings, std::string_view parameter_id);
int settingChoice(const Settings& settings, std::string_view parameter_id);
bool settingsUsePreset(const Settings& settings);

struct DataWindow {
    int x;
    int y;
    int width;
    int height;
};

struct RectI {
    int x1;
    int y1;
    int x2;
    int y2;
};

struct RenderScale {
    double x;
    double y;
};

struct FrameSurface {
    MemoryKind memory_kind;
    PixelFormat pixel_format;
    void* data;
    std::size_t byte_offset;
    std::size_t row_bytes;
    DataWindow data_window;
};

struct ExternalMatteInput {
    FrameSurface surface;
    AlphaAssociation alpha_association = AlphaAssociation::Straight;
};

struct RenderRequest {
    EffectId effect;
    FrameSurface source;
    FrameSurface destination;
    RectI render_window;
    double frame_time;
    RenderScale render_scale;
    AlphaAssociation alpha_association;
    Settings settings;
    const ExternalMatteInput* external_matte = nullptr;
};

enum class Error : std::uint8_t {
    None,
    UnsupportedEffectId,
    InvalidDimensions,
    InvalidStride,
    MismatchedSurfaceBounds,
    InvalidRenderWindow,
    InvalidFrameTime,
    UnsupportedPixelFormat,
    UnsupportedWorkingMode,
    SettingsTypeMismatch,
    SettingOutOfRange,
    NonFiniteSetting,
    AliasedSurfaces,
    BackendUnavailable,
    TemporaryAllocationFailed,
    PipelineCreationFailed,
    CommandEncodingFailed,
};

enum class SubmissionKind : std::uint8_t {
    Completed,
    Enqueued,
    Failed,
};

struct RenderSubmission {
    SubmissionKind kind;
    Error error;
};

enum class BackendKind : std::uint8_t {
    Cpu,
    Metal,
};

namespace detail {
struct CompiledEffectPlan;
}

class RenderBackend {
public:
    virtual ~RenderBackend() = default;
    virtual BackendKind kind() const = 0;

private:
    friend RenderSubmission render(const RenderRequest& request, RenderBackend& backend);
    virtual RenderSubmission submit(const RenderRequest& request, const detail::CompiledEffectPlan& plan) = 0;
};

class CpuRenderBackend final : public RenderBackend {
public:
    BackendKind kind() const override;

private:
    RenderSubmission submit(const RenderRequest& request, const detail::CompiledEffectPlan& plan) override;
};

class MetalRenderBackend final : public RenderBackend {
public:
    explicit MetalRenderBackend(void* command_queue);
    BackendKind kind() const override;

private:
    RenderSubmission submit(const RenderRequest& request, const detail::CompiledEffectPlan& plan) override;

    void* command_queue_;
};

RenderSubmission render(const RenderRequest& request, RenderBackend& backend);

}
