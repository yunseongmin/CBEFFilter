#include <algorithm>
#include <cstddef>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "cbef/RenderCore.h"
#include "ofxsImageEffect.h"
#include "ofxsMultiThread.h"

namespace {

constexpr const char* kVendor = "CBEF";
constexpr const char* kGroup = "CBEF Film Effects";
constexpr const char* kMatteClip = "Matte";
constexpr unsigned int kVersionMajor = 2;
constexpr unsigned int kVersionMinor = 0;

using cbef::AlphaAssociation;
using cbef::BackendKind;
using cbef::DataWindow;
using cbef::EffectDefinition;
using cbef::EffectId;
using cbef::Error;
using cbef::ExternalMatteInput;
using cbef::FrameSurface;
using cbef::MemoryKind;
using cbef::ParameterDefinition;
using cbef::ParameterType;
using cbef::PixelFormat;
using cbef::RectI;
using cbef::RenderRequest;
using cbef::RenderScale;
using cbef::RenderSubmission;
using cbef::Settings;
using cbef::SettingValue;
using cbef::SubmissionKind;

bool isEmpty(const OfxRectI& rectangle)
{
    return rectangle.x1 >= rectangle.x2 || rectangle.y1 >= rectangle.y2;
}

bool isPresetControlled(const char* id)
{
    return std::string(id) != "working_mode" && std::string(id) != "output_view" &&
           std::string(id) != "mix" && std::string(id) != "preset";
}

DataWindow dataWindow(const OfxRectI& bounds)
{
    return DataWindow{bounds.x1, bounds.y1, bounds.x2 - bounds.x1, bounds.y2 - bounds.y1};
}

FrameSurface frameSurface(OFX::Image& image, MemoryKind memory_kind)
{
    return FrameSurface{memory_kind,
                        PixelFormat::RgbaFloat32,
                        image.getPixelData(),
                        0U,
                        static_cast<std::size_t>(image.getRowBytes()),
                        dataWindow(image.getBounds())};
}

FrameSurface matteFrameSurface(OFX::Image& image, MemoryKind memory_kind)
{
    const PixelFormat format = image.getPixelComponents() == OFX::ePixelComponentAlpha
                                   ? PixelFormat::AlphaFloat32
                                   : PixelFormat::RgbaFloat32;
    return FrameSurface{memory_kind,
                        format,
                        image.getPixelData(),
                        0U,
                        static_cast<std::size_t>(image.getRowBytes()),
                        dataWindow(image.getBounds())};
}

void throwForRenderError(Error error)
{
    switch (error) {
    case Error::UnsupportedPixelFormat:
        OFX::throwSuiteStatusException(kOfxStatErrFormat);
    case Error::TemporaryAllocationFailed:
        OFX::throwSuiteStatusException(kOfxStatErrMemory);
    case Error::BackendUnavailable:
    case Error::PipelineCreationFailed:
        OFX::throwSuiteStatusException(kOfxStatErrUnsupported);
    case Error::UnsupportedEffectId:
    case Error::InvalidDimensions:
    case Error::InvalidStride:
    case Error::MismatchedSurfaceBounds:
    case Error::InvalidRenderWindow:
    case Error::InvalidFrameTime:
    case Error::UnsupportedWorkingMode:
    case Error::SettingsTypeMismatch:
    case Error::SettingOutOfRange:
    case Error::NonFiniteSetting:
    case Error::AliasedSurfaces:
        OFX::throwSuiteStatusException(kOfxStatErrValue);
    case Error::CommandEncodingFailed:
    case Error::None:
        OFX::throwSuiteStatusException(kOfxStatFailed);
    }
}

void setDescriptorMetadata(OFX::ParamDescriptor& descriptor, const ParameterDefinition& parameter)
{
    descriptor.setLabels(parameter.label, parameter.label, parameter.label);
    descriptor.setHint(std::string(parameter.hint) + " (" + parameter.unit + ")");
    descriptor.setIsSecret(parameter.secret);
    descriptor.setEnabled(parameter.enabled_when_parameter == nullptr);
}

struct InspectorGroups {
    OFX::PageParamDescriptor* page;
    OFX::GroupParamDescriptor* basic;
    OFX::GroupParamDescriptor* advanced;
    OFX::GroupParamDescriptor* diagnostics;
};

InspectorGroups defineInspectorGroups(OFX::ImageEffectDescriptor& descriptor)
{
    OFX::PageParamDescriptor* page = descriptor.definePageParam("inspector");
    page->setLabels("Inspector", "Inspector", "Inspector");
    page->setHint("CBEF controls: start with Basic, tune in Advanced, and verify the isolated result in Diagnostics.");

    OFX::GroupParamDescriptor* basic = descriptor.defineGroupParam("basic");
    basic->setLabels("Basic", "Basic", "Basic");
    basic->setHint("Natural starting controls for the current effect.");
    basic->setOpen(true);

    OFX::GroupParamDescriptor* advanced = descriptor.defineGroupParam("advanced");
    advanced->setLabels("Advanced", "Advanced", "Advanced");
    advanced->setHint("Profile, source, shape, spectrum, lens, and quality controls.");
    advanced->setOpen(false);

    OFX::GroupParamDescriptor* diagnostics = descriptor.defineGroupParam("diagnostics");
    diagnostics->setLabels("Diagnostics", "Diagnostics", "Diagnostics");
    diagnostics->setHint("Inspect the selected source or effect-only component without changing the final mix.");
    diagnostics->setOpen(false);

    page->addChild(*basic);
    page->addChild(*advanced);
    page->addChild(*diagnostics);
    return InspectorGroups{page, basic, advanced, diagnostics};
}

OFX::GroupParamDescriptor& groupFor(InspectorGroups& groups, cbef::ParameterGroup group)
{
    switch (group) {
    case cbef::ParameterGroup::Basic:
        return *groups.basic;
    case cbef::ParameterGroup::Advanced:
        return *groups.advanced;
    case cbef::ParameterGroup::Diagnostics:
        return *groups.diagnostics;
    }
    return *groups.advanced;
}

OFX::ParamDescriptor& defineParameter(OFX::ImageEffectDescriptor& descriptor, const ParameterDefinition& parameter,
                                      const SettingValue& default_value, InspectorGroups& groups)
{
    OFX::ParamDescriptor* defined = nullptr;
    switch (parameter.type) {
    case ParameterType::Double: {
        OFX::DoubleParamDescriptor* result = descriptor.defineDoubleParam(parameter.id);
        setDescriptorMetadata(*result, parameter);
        result->setRange(parameter.minimum, parameter.maximum);
        result->setDisplayRange(parameter.minimum, parameter.maximum);
        result->setIncrement(parameter.increment);
        result->setDefault(std::get<double>(default_value));
        result->setAnimates(parameter.animatable);
        defined = result;
        break;
    }
    case ParameterType::Integer: {
        OFX::IntParamDescriptor* result = descriptor.defineIntParam(parameter.id);
        setDescriptorMetadata(*result, parameter);
        result->setRange(static_cast<int>(parameter.minimum), static_cast<int>(parameter.maximum));
        result->setDisplayRange(static_cast<int>(parameter.minimum), static_cast<int>(parameter.maximum));
        result->setDefault(static_cast<int>(std::get<std::int64_t>(default_value)));
        result->setAnimates(parameter.animatable);
        defined = result;
        break;
    }
    case ParameterType::Boolean: {
        OFX::BooleanParamDescriptor* result = descriptor.defineBooleanParam(parameter.id);
        setDescriptorMetadata(*result, parameter);
        result->setDefault(std::get<bool>(default_value));
        result->setAnimates(parameter.animatable);
        defined = result;
        break;
    }
    case ParameterType::Choice: {
        OFX::ChoiceParamDescriptor* result = descriptor.defineChoiceParam(parameter.id);
        setDescriptorMetadata(*result, parameter);
        for (const char* choice : parameter.choices) {
            result->appendOption(choice);
        }
        result->setDefault(std::get<int>(default_value));
        result->setAnimates(parameter.animatable);
        defined = result;
        break;
    }
    }
    defined->setParent(groupFor(groups, parameter.group));
    return *defined;
}

void defineParameters(OFX::ImageEffectDescriptor& descriptor, const EffectDefinition& definition)
{
    const Settings defaults = cbef::defaultSettings(definition.effect);
    InspectorGroups groups = defineInspectorGroups(descriptor);
    std::vector<std::size_t> order(definition.parameters.size());
    for (std::size_t index = 0; index < order.size(); ++index) {
        order[index] = index;
    }
    std::stable_sort(order.begin(), order.end(), [&definition](std::size_t left, std::size_t right) {
        const ParameterDefinition& left_parameter = definition.parameters[left];
        const ParameterDefinition& right_parameter = definition.parameters[right];
        if (left_parameter.group != right_parameter.group) {
            return static_cast<int>(left_parameter.group) < static_cast<int>(right_parameter.group);
        }
        return left_parameter.display_order < right_parameter.display_order;
    });
    for (const std::size_t index : order) {
        defineParameter(descriptor, definition.parameters[index], defaults.values[index], groups);
    }
}

class CbefEffect final : public OFX::ImageEffect {
public:
    CbefEffect(OfxImageEffectHandle handle, EffectId effect)
        : OFX::ImageEffect(handle)
        , effect_(effect)
        , destination_(fetchClip(kOfxImageEffectOutputClipName))
        , source_(fetchClip(kOfxImageEffectSimpleSourceClipName))
        , matte_(effect == EffectId::LensReflections ? fetchClip(kMatteClip) : nullptr)
    {
        syncParameterState(0.0);
    }

    void render(const OFX::RenderArguments& arguments) override
    {
        if (source_ == nullptr || destination_ == nullptr || !source_->isConnected()) {
            OFX::throwSuiteStatusException(kOfxStatErrBadHandle);
        }
        std::unique_ptr<OFX::Image> destination_image(destination_->fetchImage(arguments.time));
        std::unique_ptr<OFX::Image> source_image(source_->fetchImage(arguments.time));
        if (source_image == nullptr || destination_image == nullptr) {
            OFX::throwSuiteStatusException(kOfxStatErrBadHandle);
        }
        if (source_image->getPixelDepth() != OFX::eBitDepthFloat ||
            destination_image->getPixelDepth() != OFX::eBitDepthFloat ||
            source_image->getPixelComponents() != OFX::ePixelComponentRGBA ||
            destination_image->getPixelComponents() != OFX::ePixelComponentRGBA) {
            OFX::throwSuiteStatusException(kOfxStatErrFormat);
        }
        if (isEmpty(arguments.renderWindow)) {
            return;
        }
        if (source_image->getPixelData() == nullptr || destination_image->getPixelData() == nullptr ||
            source_image->getRowBytes() <= 0 || destination_image->getRowBytes() <= 0) {
            OFX::throwSuiteStatusException(kOfxStatErrValue);
        }

        const MemoryKind memory_kind = arguments.isEnabledMetalRender ? MemoryKind::Metal : MemoryKind::Cpu;
        if (arguments.isEnabledMetalRender && arguments.pMetalCmdQ == nullptr) {
            OFX::throwSuiteStatusException(kOfxStatErrUnsupported);
        }
        std::unique_ptr<OFX::Image> matte_image;
        std::unique_ptr<ExternalMatteInput> external_matte;
        if (matte_ != nullptr && matte_->isConnected()) {
            matte_image.reset(matte_->fetchImage(arguments.time));
            if (matte_image == nullptr) {
                OFX::throwSuiteStatusException(kOfxStatErrBadHandle);
            }
            if (matte_image->getPixelDepth() != OFX::eBitDepthFloat ||
                (matte_image->getPixelComponents() != OFX::ePixelComponentAlpha &&
                 matte_image->getPixelComponents() != OFX::ePixelComponentRGBA)) {
                OFX::throwSuiteStatusException(kOfxStatErrFormat);
            }
            if (matte_image->getPixelData() == nullptr || matte_image->getRowBytes() <= 0) {
                OFX::throwSuiteStatusException(kOfxStatErrValue);
            }
            external_matte = std::make_unique<ExternalMatteInput>(ExternalMatteInput{
                matteFrameSurface(*matte_image, memory_kind),
                matte_image->getPreMultiplication() == OFX::eImagePreMultiplied
                    ? AlphaAssociation::Premultiplied
                    : AlphaAssociation::Straight});
        }
        RenderRequest request{effect_,
                              frameSurface(*source_image, memory_kind),
                              frameSurface(*destination_image, memory_kind),
                              RectI{arguments.renderWindow.x1, arguments.renderWindow.y1,
                                    arguments.renderWindow.x2, arguments.renderWindow.y2},
                              arguments.time,
                              RenderScale{arguments.renderScale.x, arguments.renderScale.y},
                              source_image->getPreMultiplication() == OFX::eImagePreMultiplied
                                  ? AlphaAssociation::Premultiplied
                                  : AlphaAssociation::Straight,
                              settingsAt(arguments.time),
                              external_matte.get()};
        if (arguments.isEnabledMetalRender) {
            cbef::MetalRenderBackend backend(arguments.pMetalCmdQ);
            submit(request, backend, SubmissionKind::Enqueued);
            return;
        }
        cbef::CpuRenderBackend backend;
        submit(request, backend, SubmissionKind::Completed);
    }

    bool isIdentity(const OFX::IsIdentityArguments& arguments, OFX::Clip*& identity_clip,
                    double& identity_time) override
    {
        if (source_ == nullptr || !source_->isConnected() || !settingsAreIdentity(settingsAt(arguments.time))) {
            return false;
        }
        identity_clip = source_;
        identity_time = arguments.time;
        return true;
    }

    void changedParam(const OFX::InstanceChangedArgs& arguments, const std::string& parameter_name) override
    {
        if (suppress_preset_tracking_ || arguments.reason != OFX::eChangeUserEdit) {
            return;
        }
        const EffectDefinition& definition = cbef::effectDefinition(effect_);
        if (parameter_name == "preset") {
            int preset = 0;
            fetchChoiceParam("preset")->getValueAtTime(arguments.time, preset);
            if (preset >= 0 && preset < static_cast<int>(definition.presets.size())) {
                suppress_preset_tracking_ = true;
                writePreset(cbef::settingsForPreset(effect_, static_cast<std::size_t>(preset)), arguments.time);
                suppress_preset_tracking_ = false;
            }
            syncParameterState(arguments.time);
            return;
        }
        if (isPresetControlled(parameter_name.c_str())) {
            fetchChoiceParam("preset")->setValueAtTime(arguments.time,
                                                        static_cast<int>(definition.presets.size()));
        }
        syncParameterState(arguments.time);
    }

private:
    void setParameterEnabled(const ParameterDefinition& parameter, bool enabled)
    {
        switch (parameter.type) {
        case ParameterType::Double:
            fetchDoubleParam(parameter.id)->setEnabled(enabled);
            return;
        case ParameterType::Integer:
            fetchIntParam(parameter.id)->setEnabled(enabled);
            return;
        case ParameterType::Boolean:
            fetchBooleanParam(parameter.id)->setEnabled(enabled);
            return;
        case ParameterType::Choice:
            fetchChoiceParam(parameter.id)->setEnabled(enabled);
            return;
        }
    }

    void syncParameterState(double time)
    {
        const EffectDefinition& definition = cbef::effectDefinition(effect_);
        for (const ParameterDefinition& parameter : definition.parameters) {
            if (parameter.enabled_when_parameter == nullptr) {
                continue;
            }
            const int selected = cbef::settingChoice(settingsAt(time), parameter.enabled_when_parameter);
            setParameterEnabled(parameter, selected == parameter.enabled_when_choice);
        }
    }

    Settings settingsAt(double time) const
    {
        const EffectDefinition& definition = cbef::effectDefinition(effect_);
        Settings settings = cbef::defaultSettings(effect_);
        for (std::size_t index = 0; index < definition.parameters.size(); ++index) {
            const ParameterDefinition& parameter = definition.parameters[index];
            switch (parameter.type) {
            case ParameterType::Double:
                settings.values[index] = fetchDoubleParam(parameter.id)->getValueAtTime(time);
                break;
            case ParameterType::Integer:
                settings.values[index] = static_cast<std::int64_t>(fetchIntParam(parameter.id)->getValueAtTime(time));
                break;
            case ParameterType::Boolean:
                settings.values[index] = fetchBooleanParam(parameter.id)->getValueAtTime(time);
                break;
            case ParameterType::Choice:
                int choice = 0;
                fetchChoiceParam(parameter.id)->getValueAtTime(time, choice);
                settings.values[index] = choice;
                break;
            }
        }
        return settings;
    }

    void writePreset(const Settings& settings, double time)
    {
        const EffectDefinition& definition = cbef::effectDefinition(effect_);
        for (std::size_t index = 0; index < definition.parameters.size(); ++index) {
            const ParameterDefinition& parameter = definition.parameters[index];
            if (!isPresetControlled(parameter.id)) {
                continue;
            }
            const SettingValue& value = settings.values[index];
            switch (parameter.type) {
            case ParameterType::Double:
                fetchDoubleParam(parameter.id)->setValueAtTime(time, std::get<double>(value));
                break;
            case ParameterType::Integer:
                fetchIntParam(parameter.id)->setValueAtTime(time, static_cast<int>(std::get<std::int64_t>(value)));
                break;
            case ParameterType::Boolean:
                fetchBooleanParam(parameter.id)->setValueAtTime(time, std::get<bool>(value));
                break;
            case ParameterType::Choice:
                fetchChoiceParam(parameter.id)->setValueAtTime(time, std::get<int>(value));
                break;
            }
        }
    }

    bool settingsAreIdentity(const Settings& settings) const
    {
        if (cbef::settingChoice(settings, "output_view") != 0 ||
            std::get<double>(cbef::settingValue(settings, "mix")) == 0.0) {
            return cbef::settingChoice(settings, "output_view") == 0;
        }
        switch (effect_) {
        case EffectId::Halation:
        case EffectId::FilmGrain:
        case EffectId::LensReflections:
            return std::get<double>(cbef::settingValue(settings, "amount")) == 0.0;
        case EffectId::OpticalBlur:
            return std::get<double>(cbef::settingValue(settings, "blur")) == 0.0;
        case EffectId::MistDiffusion:
            return std::get<double>(cbef::settingValue(settings, "diffusion")) == 0.0 &&
                   std::get<double>(cbef::settingValue(settings, "bloom")) == 0.0 &&
                   std::get<double>(cbef::settingValue(settings, "contrast")) == 0.0;
        }
        return false;
    }

    static void submit(const RenderRequest& request, cbef::RenderBackend& backend, SubmissionKind expected)
    {
        const RenderSubmission submission = cbef::render(request, backend);
        if (submission.kind == SubmissionKind::Failed) {
            throwForRenderError(submission.error);
        }
        if (submission.kind != expected) {
            OFX::throwSuiteStatusException(kOfxStatFailed);
        }
    }

    EffectId effect_;
    OFX::Clip* destination_;
    OFX::Clip* source_;
    OFX::Clip* matte_;
    bool suppress_preset_tracking_ = false;
};

class CbefEffectFactoryBase {
protected:
    explicit CbefEffectFactoryBase(EffectId effect)
        : effect_(effect)
    {
    }

    const EffectDefinition& definition() const
    {
        return cbef::effectDefinition(effect_);
    }

    void describeCommon(OFX::ImageEffectDescriptor& descriptor) const
    {
        const EffectDefinition& effect = definition();
        descriptor.setLabels(effect.label, effect.label, effect.label);
        descriptor.setPluginGrouping(kGroup);
        descriptor.setPluginDescription(std::string(kVendor) + " | " + effect.description);
        descriptor.addSupportedContext(OFX::eContextFilter);
        descriptor.addSupportedBitDepth(OFX::eBitDepthFloat);
        descriptor.setSingleInstance(false);
        descriptor.setHostFrameThreading(false);
        descriptor.setRenderThreadSafety(OFX::eRenderFullySafe);
        descriptor.setSupportsMultiResolution(true);
        descriptor.setSupportsTiles(false);
        descriptor.setTemporalClipAccess(false);
        descriptor.setRenderTwiceAlways(false);
        descriptor.setSupportsMultipleClipDepths(false);
        descriptor.setSupportsMultipleClipPARs(false);
        descriptor.setSupportsMetalRender(true);
        descriptor.setNoSpatialAwareness(false);
    }

    void describeInFilterContext(OFX::ImageEffectDescriptor& descriptor) const
    {
        OFX::ClipDescriptor* source = descriptor.defineClip(kOfxImageEffectSimpleSourceClipName);
        source->addSupportedComponent(OFX::ePixelComponentRGBA);
        source->setTemporalClipAccess(false);
        source->setSupportsTiles(false);
        source->setIsMask(false);
        OFX::ClipDescriptor* destination = descriptor.defineClip(kOfxImageEffectOutputClipName);
        destination->addSupportedComponent(OFX::ePixelComponentRGBA);
        destination->setSupportsTiles(false);
        if (effect_ == EffectId::LensReflections) {
            OFX::ClipDescriptor* matte = descriptor.defineClip(kMatteClip);
            matte->addSupportedComponent(OFX::ePixelComponentAlpha);
            matte->addSupportedComponent(OFX::ePixelComponentRGBA);
            matte->setTemporalClipAccess(false);
            matte->setSupportsTiles(false);
            matte->setIsMask(true);
            matte->setOptional(true);
        }
        defineParameters(descriptor, definition());
    }

    OFX::ImageEffect* createInstance(OfxImageEffectHandle handle) const
    {
        return new CbefEffect(handle, effect_);
    }

private:
    EffectId effect_;
};

#define CBEF_DEFINE_FACTORY(factory_name, effect_id)                                            \
    class factory_name final : public OFX::PluginFactoryHelper<factory_name>,                   \
                               private CbefEffectFactoryBase {                                  \
    public:                                                                                      \
        factory_name()                                                                           \
            : OFX::PluginFactoryHelper<factory_name>(cbef::effectDefinition(effect_id).identifier, \
                                                      kVersionMajor, kVersionMinor)              \
            , CbefEffectFactoryBase(effect_id)                                                  \
        {                                                                                        \
        }                                                                                        \
                                                                                                 \
        void describe(OFX::ImageEffectDescriptor& descriptor) override                         \
        {                                                                                        \
            describeCommon(descriptor);                                                         \
        }                                                                                        \
                                                                                                 \
        void describeInContext(OFX::ImageEffectDescriptor& descriptor,                         \
                               OFX::ContextEnum context) override                               \
        {                                                                                        \
            if (context != OFX::eContextFilter) {                                               \
                OFX::throwSuiteStatusException(kOfxStatErrUnsupported);                        \
            }                                                                                    \
            describeInFilterContext(descriptor);                                                \
        }                                                                                        \
                                                                                                 \
        OFX::ImageEffect* createInstance(OfxImageEffectHandle handle,                          \
                                         OFX::ContextEnum context) override                      \
        {                                                                                        \
            if (context != OFX::eContextFilter) {                                               \
                OFX::throwSuiteStatusException(kOfxStatErrUnsupported);                        \
            }                                                                                    \
            return CbefEffectFactoryBase::createInstance(handle);                              \
        }                                                                                        \
    }

CBEF_DEFINE_FACTORY(HalationFactory, EffectId::Halation);
CBEF_DEFINE_FACTORY(FilmGrainFactory, EffectId::FilmGrain);
CBEF_DEFINE_FACTORY(OpticalBlurFactory, EffectId::OpticalBlur);
CBEF_DEFINE_FACTORY(LensReflectionsFactory, EffectId::LensReflections);
CBEF_DEFINE_FACTORY(MistDiffusionFactory, EffectId::MistDiffusion);

#undef CBEF_DEFINE_FACTORY

}

void OFX::Plugin::getPluginIDs(PluginFactoryArray& factories)
{
    static HalationFactory halation;
    static FilmGrainFactory film_grain;
    static OpticalBlurFactory optical_blur;
    static LensReflectionsFactory lens_reflections;
    static MistDiffusionFactory mist_diffusion;
    factories.push_back(&halation);
    factories.push_back(&film_grain);
    factories.push_back(&optical_blur);
    factories.push_back(&lens_reflections);
    factories.push_back(&mist_diffusion);
}
