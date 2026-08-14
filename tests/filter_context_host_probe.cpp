#include <algorithm>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "ofxCore.h"
#include "ofxImageEffect.h"
#include "ofxMemory.h"
#include "ofxMessage.h"
#include "ofxMultiThread.h"
#include "ofxParam.h"
#include "ofxProperty.h"

namespace {

struct Properties {
    std::map<std::string, std::vector<void*>> pointers;
    std::map<std::string, std::vector<std::string>> strings;
    std::map<std::string, std::vector<double>> doubles;
    std::map<std::string, std::vector<int>> integers;
};

struct Parameter {
    Properties properties;
    std::string type;
};

struct ParameterSet {
    Properties properties;
    std::map<std::string, std::unique_ptr<Parameter>> parameters;
};

struct Clip {
    Properties properties;
};

struct Effect {
    Properties properties;
    ParameterSet parameter_set;
    std::map<std::string, std::unique_ptr<Clip>> clips;
};

int page_order_queries = 0;

template <class T>
void setValue(std::map<std::string, std::vector<T>>& values, const char* property, int index, T value)
{
    auto& slots = values[property];
    if (index >= static_cast<int>(slots.size())) {
        slots.resize(static_cast<std::size_t>(index + 1));
    }
    slots[static_cast<std::size_t>(index)] = std::move(value);
}

Properties* props(OfxPropertySetHandle handle)
{
    return reinterpret_cast<Properties*>(handle);
}

OfxPropertySetHandle propertyHandle(Properties* value)
{
    return reinterpret_cast<OfxPropertySetHandle>(value);
}

OfxStatus setPointer(OfxPropertySetHandle handle, const char* name, int index, void* value)
{
    setValue(props(handle)->pointers, name, index, value);
    return kOfxStatOK;
}

OfxStatus setString(OfxPropertySetHandle handle, const char* name, int index, const char* value)
{
    setValue(props(handle)->strings, name, index, std::string(value == nullptr ? "" : value));
    return kOfxStatOK;
}

OfxStatus setDouble(OfxPropertySetHandle handle, const char* name, int index, double value)
{
    setValue(props(handle)->doubles, name, index, value);
    return kOfxStatOK;
}

OfxStatus setInt(OfxPropertySetHandle handle, const char* name, int index, int value)
{
    setValue(props(handle)->integers, name, index, value);
    return kOfxStatOK;
}

OfxStatus setPointerN(OfxPropertySetHandle h, const char* n, int count, void* const* values)
{
    for (int i = 0; i < count; ++i) setPointer(h, n, i, values[i]);
    return kOfxStatOK;
}

OfxStatus setStringN(OfxPropertySetHandle h, const char* n, int count, const char* const* values)
{
    for (int i = 0; i < count; ++i) setString(h, n, i, values[i]);
    return kOfxStatOK;
}

OfxStatus setDoubleN(OfxPropertySetHandle h, const char* n, int count, const double* values)
{
    for (int i = 0; i < count; ++i) setDouble(h, n, i, values[i]);
    return kOfxStatOK;
}

OfxStatus setIntN(OfxPropertySetHandle h, const char* n, int count, const int* values)
{
    for (int i = 0; i < count; ++i) setInt(h, n, i, values[i]);
    return kOfxStatOK;
}

template <class T>
T valueAt(const std::map<std::string, std::vector<T>>& values, const char* name, int index)
{
    const auto found = values.find(name);
    if (found == values.end() || index < 0 || index >= static_cast<int>(found->second.size())) {
        return T{};
    }
    return found->second[static_cast<std::size_t>(index)];
}

OfxStatus getPointer(OfxPropertySetHandle h, const char* n, int i, void** value)
{
    *value = valueAt(props(h)->pointers, n, i);
    return kOfxStatOK;
}

OfxStatus getString(OfxPropertySetHandle h, const char* n, int i, char** value)
{
    static std::string empty;
    auto found = props(h)->strings.find(n);
    if (found == props(h)->strings.end() || i < 0 || i >= static_cast<int>(found->second.size())) {
        *value = empty.data();
    } else {
        *value = found->second[static_cast<std::size_t>(i)].data();
    }
    return kOfxStatOK;
}

OfxStatus getDouble(OfxPropertySetHandle h, const char* n, int i, double* value)
{
    *value = valueAt(props(h)->doubles, n, i);
    return kOfxStatOK;
}

OfxStatus getInt(OfxPropertySetHandle h, const char* n, int i, int* value)
{
    *value = valueAt(props(h)->integers, n, i);
    return kOfxStatOK;
}

OfxStatus getPointerN(OfxPropertySetHandle h, const char* n, int count, void** values)
{
    for (int i = 0; i < count; ++i) getPointer(h, n, i, &values[i]);
    return kOfxStatOK;
}

OfxStatus getStringN(OfxPropertySetHandle h, const char* n, int count, char** values)
{
    for (int i = 0; i < count; ++i) getString(h, n, i, &values[i]);
    return kOfxStatOK;
}

OfxStatus getDoubleN(OfxPropertySetHandle h, const char* n, int count, double* values)
{
    for (int i = 0; i < count; ++i) getDouble(h, n, i, &values[i]);
    return kOfxStatOK;
}

OfxStatus getIntN(OfxPropertySetHandle h, const char* n, int count, int* values)
{
    for (int i = 0; i < count; ++i) getInt(h, n, i, &values[i]);
    return kOfxStatOK;
}

OfxStatus resetProperty(OfxPropertySetHandle h, const char* n)
{
    props(h)->pointers.erase(n);
    props(h)->strings.erase(n);
    props(h)->doubles.erase(n);
    props(h)->integers.erase(n);
    return kOfxStatOK;
}

OfxStatus getDimension(OfxPropertySetHandle h, const char* n, int* count)
{
    if (std::strcmp(n, kOfxPluginPropParamPageOrder) == 0) {
        ++page_order_queries;
        return kOfxStatErrUnknown;
    }
    const Properties* p = props(h);
    *count = static_cast<int>(std::max({p->pointers.count(n) == 0 ? std::size_t{0} : p->pointers.at(n).size(),
                                       p->strings.count(n) == 0 ? std::size_t{0} : p->strings.at(n).size(),
                                       p->doubles.count(n) == 0 ? std::size_t{0} : p->doubles.at(n).size(),
                                       p->integers.count(n) == 0 ? std::size_t{0} : p->integers.at(n).size()}));
    return kOfxStatOK;
}

OfxStatus effectProperties(OfxImageEffectHandle effect, OfxPropertySetHandle* handle)
{
    *handle = propertyHandle(&reinterpret_cast<Effect*>(effect)->properties);
    return kOfxStatOK;
}

OfxStatus effectParams(OfxImageEffectHandle effect, OfxParamSetHandle* handle)
{
    *handle = reinterpret_cast<OfxParamSetHandle>(&reinterpret_cast<Effect*>(effect)->parameter_set);
    return kOfxStatOK;
}

OfxStatus defineClip(OfxImageEffectHandle effect, const char* name, OfxPropertySetHandle* handle)
{
    auto& clip = reinterpret_cast<Effect*>(effect)->clips[name];
    if (!clip) clip = std::make_unique<Clip>();
    *handle = propertyHandle(&clip->properties);
    return kOfxStatOK;
}

OfxStatus getClip(OfxImageEffectHandle effect, const char* name, OfxImageClipHandle* handle,
                  OfxPropertySetHandle* property_set)
{
    auto& clip = reinterpret_cast<Effect*>(effect)->clips[name];
    if (!clip) clip = std::make_unique<Clip>();
    *handle = reinterpret_cast<OfxImageClipHandle>(clip.get());
    if (property_set) *property_set = propertyHandle(&clip->properties);
    return kOfxStatOK;
}

OfxStatus clipProperties(OfxImageClipHandle clip, OfxPropertySetHandle* handle)
{
    *handle = propertyHandle(&reinterpret_cast<Clip*>(clip)->properties);
    return kOfxStatOK;
}

OfxStatus defineParam(OfxParamSetHandle set_handle, const char* type, const char* name,
                      OfxPropertySetHandle* property_set)
{
    auto* set = reinterpret_cast<ParameterSet*>(set_handle);
    auto parameter = std::make_unique<Parameter>();
    parameter->type = type;
    setString(propertyHandle(&parameter->properties), kOfxParamPropType, 0, type);
    setString(propertyHandle(&parameter->properties), kOfxPropName, 0, name);
    *property_set = propertyHandle(&parameter->properties);
    set->parameters[name] = std::move(parameter);
    return kOfxStatOK;
}

OfxStatus getParam(OfxParamSetHandle set_handle, const char* name, OfxParamHandle* handle,
                   OfxPropertySetHandle* property_set)
{
    auto* set = reinterpret_cast<ParameterSet*>(set_handle);
    const auto found = set->parameters.find(name);
    if (found == set->parameters.end()) return kOfxStatErrUnknown;
    *handle = reinterpret_cast<OfxParamHandle>(found->second.get());
    if (property_set) *property_set = propertyHandle(&found->second->properties);
    return kOfxStatOK;
}

OfxStatus paramSetProperties(OfxParamSetHandle set_handle, OfxPropertySetHandle* handle)
{
    *handle = propertyHandle(&reinterpret_cast<ParameterSet*>(set_handle)->properties);
    return kOfxStatOK;
}

OfxStatus paramProperties(OfxParamHandle param, OfxPropertySetHandle* handle)
{
    *handle = propertyHandle(&reinterpret_cast<Parameter*>(param)->properties);
    return kOfxStatOK;
}

OfxStatus getParamValueAtTime(OfxParamHandle handle, OfxTime time, ...)
{
    auto* parameter = reinterpret_cast<Parameter*>(handle);
    va_list args;
    va_start(args, time);
    if (parameter->type == kOfxParamTypeDouble) {
        *va_arg(args, double*) = valueAt(parameter->properties.doubles, kOfxParamPropDefault, 0);
    } else if (parameter->type == kOfxParamTypeBoolean) {
        *va_arg(args, bool*) = valueAt(parameter->properties.integers, kOfxParamPropDefault, 0) != 0;
    } else {
        *va_arg(args, int*) = valueAt(parameter->properties.integers, kOfxParamPropDefault, 0);
    }
    va_end(args);
    return kOfxStatOK;
}

OfxStatus allocateMemory(void*, std::size_t bytes, void** data)
{
    *data = std::malloc(bytes);
    return *data == nullptr ? kOfxStatErrMemory : kOfxStatOK;
}

OfxStatus freeMemory(void* data) { std::free(data); return kOfxStatOK; }
OfxStatus runThreads(OfxThreadFunctionV1 fn, unsigned int count, void* arg)
{
    for (unsigned int i = 0; i < count; ++i) fn(i, count, arg);
    return kOfxStatOK;
}
OfxStatus cpuCount(unsigned int* count) { *count = 1; return kOfxStatOK; }
OfxStatus threadIndex(unsigned int* index) { *index = 0; return kOfxStatOK; }
int isSpawnedThread() { return 0; }
OfxStatus message(void*, const char*, const char*, const char*, ...) { return kOfxStatOK; }

OfxPropertySuiteV1 property_suite = {setPointer, setString, setDouble, setInt,
                                     setPointerN, setStringN, setDoubleN, setIntN,
                                     getPointer, getString, getDouble, getInt,
                                     getPointerN, getStringN, getDoubleN, getIntN,
                                     resetProperty, getDimension};
OfxImageEffectSuiteV1 effect_suite = {effectProperties, effectParams, defineClip, getClip,
                                      clipProperties, nullptr, nullptr, nullptr, nullptr,
                                      nullptr, nullptr, nullptr, nullptr};
OfxParameterSuiteV1 parameter_suite = {defineParam, getParam, paramSetProperties, paramProperties,
                                       nullptr, getParamValueAtTime, nullptr, nullptr, nullptr, nullptr,
                                       nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr};
OfxMemorySuiteV1 memory_suite = {allocateMemory, freeMemory};
OfxMultiThreadSuiteV1 thread_suite = {runThreads, cpuCount, threadIndex, isSpawnedThread,
                                      nullptr, nullptr, nullptr, nullptr, nullptr};
OfxMessageSuiteV1 message_suite = {message};

const void* fetchSuite(OfxPropertySetHandle, const char* name, int version)
{
    if (version != 1) return nullptr;
    if (std::strcmp(name, kOfxPropertySuite) == 0) return &property_suite;
    if (std::strcmp(name, kOfxImageEffectSuite) == 0) return &effect_suite;
    if (std::strcmp(name, kOfxParameterSuite) == 0) return &parameter_suite;
    if (std::strcmp(name, kOfxMemorySuite) == 0) return &memory_suite;
    if (std::strcmp(name, kOfxMultiThreadSuite) == 0) return &thread_suite;
    if (std::strcmp(name, kOfxMessageSuite) == 0) return &message_suite;
    return nullptr;
}

void setContext(Effect& effect, const char* context)
{
    setString(propertyHandle(&effect.properties), kOfxImageEffectPropContext, 0, context);
}

int requireStatus(const char* operation, OfxStatus actual, OfxStatus expected)
{
    if (actual == expected) return 0;
    std::fprintf(stderr, "filter_context_host_probe: %s returned %d, expected %d\n",
                 operation, actual, expected);
    return 1;
}

int verifyLensOutputViewContract(OfxPlugin* plugin, Effect& descriptor)
{
    if (std::strcmp(plugin->pluginIdentifier, "com.cbef.filmeffects.lensreflections") != 0) return 0;
    const auto output_view = descriptor.parameter_set.parameters.find("output_view");
    if (output_view == descriptor.parameter_set.parameters.end()) {
        std::fprintf(stderr, "filter_context_host_probe: Lens Output View parameter is missing\n");
        return 1;
    }
    const std::vector<std::string>& options = output_view->second->properties.strings[kOfxParamPropChoiceOption];
    if (options.size() != 8U || options[5] != "Elements Only") {
        std::fprintf(stderr, "filter_context_host_probe: Lens Elements Only is not stable choice ordinal 5\n");
        return 1;
    }
    setInt(propertyHandle(&output_view->second->properties), kOfxParamPropDefault, 0, 5);
    const auto source = descriptor.clips.find(kOfxImageEffectSimpleSourceClipName);
    if (source == descriptor.clips.end()) {
        std::fprintf(stderr, "filter_context_host_probe: Lens Source clip is missing\n");
        return 1;
    }
    setInt(propertyHandle(&source->second->properties), kOfxImageClipPropConnected, 0, 1);
    const auto matte = descriptor.clips.find("Matte");
    if (matte == descriptor.clips.end() ||
        valueAt(matte->second->properties.integers, kOfxImageClipPropOptional, 0) != 1) {
        std::fprintf(stderr, "filter_context_host_probe: Lens Matte clip must be optional\n");
        return 1;
    }
    return 0;
}

}

int main()
{
    Properties host_properties;
    setString(propertyHandle(&host_properties), kOfxPropName, 0, "com.blackmagicdesign.resolve.Fusion");
    setString(propertyHandle(&host_properties), kOfxPropLabel, 0, "Resolve 21 Fusion");
    setInt(propertyHandle(&host_properties), kOfxPropAPIVersion, 0, 1);
    setInt(propertyHandle(&host_properties), kOfxPropAPIVersion, 1, 4);
    setInt(propertyHandle(&host_properties), kOfxParamHostPropMaxParameters, 0, 4096);
    setInt(propertyHandle(&host_properties), kOfxParamHostPropMaxPages, 0, 16);
    setInt(propertyHandle(&host_properties), kOfxParamHostPropPageRowColumnCount, 0, 64);
    setInt(propertyHandle(&host_properties), kOfxParamHostPropPageRowColumnCount, 1, 8);
    OfxHost host{propertyHandle(&host_properties), fetchSuite};

    const int plugin_count = OfxGetNumberOfPlugins();
    if (plugin_count != 5) return 1;
    for (int index = 0; index < plugin_count; ++index) {
        OfxPlugin* plugin = OfxGetPlugin(index);
        plugin->setHost(&host);
        if (requireStatus("load", plugin->mainEntry(kOfxActionLoad, nullptr, nullptr, nullptr), kOfxStatOK)) return 1;

        Effect descriptor;
        if (requireStatus("describe", plugin->mainEntry(kOfxActionDescribe, &descriptor, nullptr, nullptr), kOfxStatOK)) return 1;
        Properties filter_args;
        setString(propertyHandle(&filter_args), kOfxImageEffectPropContext, 0, kOfxImageEffectContextFilter);
        setContext(descriptor, kOfxImageEffectContextFilter);
        page_order_queries = 0;
        if (requireStatus("describeInContext(Filter)",
                          plugin->mainEntry(kOfxImageEffectActionDescribeInContext, &descriptor,
                                            propertyHandle(&filter_args), nullptr),
                          kOfxStatOK)) return 1;
        if (page_order_queries != 0) {
            std::fprintf(stderr, "filter_context_host_probe: queried unsupported OfxPluginPropParamPageOrder\n");
            return 1;
        }
        if (verifyLensOutputViewContract(plugin, descriptor) != 0) return 1;

        if (requireStatus("createInstance(Filter)",
                          plugin->mainEntry(kOfxActionCreateInstance, &descriptor, nullptr, nullptr), kOfxStatOK)) return 1;
        if (std::strcmp(plugin->pluginIdentifier, "com.cbef.filmeffects.lensreflections") == 0) {
            Properties identity_args;
            Properties identity_result;
            setDouble(propertyHandle(&identity_args), kOfxPropTime, 0, 0.0);
            setDouble(propertyHandle(&identity_args), kOfxImageEffectPropRenderScale, 0, 1.0);
            setDouble(propertyHandle(&identity_args), kOfxImageEffectPropRenderScale, 1, 1.0);
            setInt(propertyHandle(&identity_args), kOfxImageEffectPropRenderWindow, 0, 0);
            setInt(propertyHandle(&identity_args), kOfxImageEffectPropRenderWindow, 1, 0);
            setInt(propertyHandle(&identity_args), kOfxImageEffectPropRenderWindow, 2, 16);
            setInt(propertyHandle(&identity_args), kOfxImageEffectPropRenderWindow, 3, 16);
            setString(propertyHandle(&identity_args), kOfxImageEffectPropFieldToRender, 0, kOfxImageFieldNone);
            if (requireStatus("isIdentity(Elements Only)",
                              plugin->mainEntry(kOfxImageEffectActionIsIdentity, &descriptor,
                                                propertyHandle(&identity_args), propertyHandle(&identity_result)),
                              kOfxStatReplyDefault)) return 1;
        }
        if (requireStatus("destroyInstance(Filter)",
                          plugin->mainEntry(kOfxActionDestroyInstance, &descriptor, nullptr, nullptr), kOfxStatOK)) return 1;

        Effect general_instance;
        setContext(general_instance, kOfxImageEffectContextGeneral);
        if (requireStatus("createInstance(General)",
                          plugin->mainEntry(kOfxActionCreateInstance, &general_instance, nullptr, nullptr),
                          kOfxStatErrUnsupported)) return 1;

        if (requireStatus("unload", plugin->mainEntry(kOfxActionUnload, nullptr, nullptr, nullptr), kOfxStatOK)) return 1;
    }
    std::puts("filter_context_host_probe: PASS (all five Filter instances create; Fusion General is intentionally unsupported)");
    return 0;
}
