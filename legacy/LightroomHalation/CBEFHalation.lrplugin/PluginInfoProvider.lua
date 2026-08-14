local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrView = import "LrView"

local Provider = {}
local f = LrView.osFactory()

local function pluginVersion()
    local version = _PLUGIN and _PLUGIN.version
    if type(version) == "table" then
        return string.format("%d.%d.%d", version.major or 0, version.minor or 0, version.revision or 0)
    end
    return "1.0.0"
end

local function engineLocation()
    local root = LrPathUtils.parent(_PLUGIN.path)
    return LrPathUtils.child(LrPathUtils.child(root, "bin"), "halation-engine")
end

function Provider.sectionsForTopOfDialog(viewFactory, propertyTable)
    local path = engineLocation()
    local status = LrFileUtils.exists(path) and "Ready / 준비됨" or "Missing / 없음"
    return {
        {
            title = "CBEF Halation",
            view = viewFactory:column {
                spacing = f:control_spacing(),
                f:static_text { title = "Version / 버전: " .. pluginVersion() },
                f:static_text { title = "Engine / 엔진: " .. status },
                f:static_text { title = "Path / 경로: " .. path, width = 480 },
                f:static_text {
                    title = "Lightroom SDK는 Develop 모듈에 실시간 픽셀 효과를 추가할 수 없습니다. CBEF Halation은 Export > Post-Process Actions에서 렌더링 후처리로 동작합니다.",
                    width = 480,
                    height = 44,
                },
                f:static_text {
                    title = "Engine contract: bin/halation-engine --input PATH --output PATH --halation-amount N --halation-radius N --threshold N --softness N --warmth N --bloom-amount N --bloom-radius N --grain-amount N --grain-size N --vignette N --chromatic-aberration N --fade N --contrast N --saturation N --mode final|halo|matte",
                    width = 480,
                    height = 64,
                },
            },
        },
    }
end

return Provider
