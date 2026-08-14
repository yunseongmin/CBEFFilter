#include <array>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <filesystem>
#include <fstream>

#include "ofxCore.h"
#include "ofxImageEffect.h"

namespace {

using GetPluginCount = int (*)();
using GetPlugin = OfxPlugin* (*)(int);

constexpr std::array<const char*, 5> kExpectedIdentifiers = {
    "com.cbef.filmeffects.halation",
    "com.cbef.filmeffects.filmgrain",
    "com.cbef.filmeffects.opticalblur",
    "com.cbef.filmeffects.lensreflections",
    "com.cbef.filmeffects.mistdiffusion",
};

int fail(const char* message)
{
    std::fprintf(stderr, "plugin_abi_probe: %s\n", message);
    return 1;
}

}

int main(int argc, char* argv[])
{
    if (argc != 2) {
        return fail("expected exactly one OpenFX binary path");
    }

    void* plugin_handle = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!plugin_handle) {
        return fail(dlerror());
    }

    const auto getPluginCount = reinterpret_cast<GetPluginCount>(dlsym(plugin_handle, "OfxGetNumberOfPlugins"));
    const auto getPlugin = reinterpret_cast<GetPlugin>(dlsym(plugin_handle, "OfxGetPlugin"));
    if (!getPluginCount || !getPlugin) {
        dlclose(plugin_handle);
        return fail("missing mandatory OpenFX exports");
    }

    if (getPluginCount() != static_cast<int>(kExpectedIdentifiers.size())) {
        dlclose(plugin_handle);
        return fail("registered effect count is not five");
    }

    const std::filesystem::path binary_path(argv[1]);
    const std::filesystem::path library_path =
        binary_path.parent_path().parent_path() / "Resources" / "CBEFFilmEffects.metallib";
    std::ifstream metallib(library_path, std::ios::binary | std::ios::ate);
    if (!metallib || metallib.tellg() <= 0) {
        dlclose(plugin_handle);
        return fail("bundle is missing the precompiled CBEF Metal library");
    }

    for (std::size_t index = 0; index < kExpectedIdentifiers.size(); ++index) {
        const OfxPlugin* plugin = getPlugin(static_cast<int>(index));
        if (!plugin || !plugin->pluginApi || !plugin->pluginIdentifier || !plugin->setHost || !plugin->mainEntry) {
            dlclose(plugin_handle);
            return fail("registered effect has an incomplete OpenFX descriptor");
        }
        if (std::strcmp(plugin->pluginApi, kOfxImageEffectPluginApi) != 0 || plugin->apiVersion != 1 ||
            plugin->pluginVersionMajor != 2 || plugin->pluginVersionMinor != 0 ||
            std::strcmp(plugin->pluginIdentifier, kExpectedIdentifiers[index]) != 0) {
            dlclose(plugin_handle);
            return fail("registered effect metadata differs from the stable M0 contract");
        }
    }

    dlclose(plugin_handle);
    std::puts("plugin_abi_probe: PASS (v2 ABI, five stable OpenFX effect descriptors + bundled Metal library)");
    return 0;
}
