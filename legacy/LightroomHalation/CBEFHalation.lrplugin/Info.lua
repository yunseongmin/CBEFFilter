local ExportFilter = require "ExportFilter"
local PluginInfoProvider = require "PluginInfoProvider"

return {
    LrSdkVersion = 15.5,
    LrSdkMinimumVersion = 5.0,
    LrToolkitIdentifier = "com.cbef.lightroom.halation",
    LrPluginName = "CBEF Halation",
    VERSION = {
        major = 1,
        minor = 0,
        revision = 0,
        build = 1,
    },

    LrExportFilterProvider = {
        title = "CBEF Halation (Export Post-Process)",
        id = "com.cbef.lightroom.halation.export-filter",
        supportsVideo = false,
        sectionForFilterInDialog = ExportFilter.sectionForFilterInDialog,
        postProcessRenderedPhotos = ExportFilter.postProcessRenderedPhotos,
        exportPresetFields = ExportFilter.exportPresetFields,
    },

    LrPluginInfoProvider = {
        sectionsForTopOfDialog = PluginInfoProvider.sectionsForTopOfDialog,
    },
}
