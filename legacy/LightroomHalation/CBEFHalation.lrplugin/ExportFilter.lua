local LrFileUtils = import "LrFileUtils"
local LrLogger = import "LrLogger"
local LrPathUtils = import "LrPathUtils"
local LrProgressScope = import "LrProgressScope"
local LrTasks = import "LrTasks"
local LrView = import "LrView"

local f = LrView.osFactory()
local bind = LrView.bind
local logger = LrLogger("CBEFHalation")
logger:enable("logfile")

local ExportFilter = {}

local FIELD_DEFS = {
    halationAmount = { default = 35, min = 0, max = 100, step = 1 },
    halationRadius = { default = 24, min = 0, max = 200, step = 1 },
    threshold = { default = 65, min = 0, max = 100, step = 1 },
    softness = { default = 55, min = 0, max = 100, step = 1 },
    warmth = { default = 20, min = -100, max = 100, step = 1 },
    bloomAmount = { default = 20, min = 0, max = 100, step = 1 },
    bloomRadius = { default = 16, min = 0, max = 200, step = 1 },
    grainAmount = { default = 8, min = 0, max = 100, step = 1 },
    grainSize = { default = 1.2, min = 0.1, max = 5, step = 0.1 },
    vignette = { default = 12, min = 0, max = 100, step = 1 },
    chromaticAberration = { default = 6, min = 0, max = 100, step = 1 },
    fade = { default = 0, min = 0, max = 100, step = 1 },
    contrast = { default = 0, min = -100, max = 100, step = 1 },
    saturation = { default = 4, min = -100, max = 100, step = 1 },
}

local PRESETS = {
    subtle = {
        halationAmount = 20, halationRadius = 16, threshold = 70, softness = 60,
        warmth = 12, bloomAmount = 12, bloomRadius = 12, grainAmount = 4,
        grainSize = 1.0, vignette = 8, chromaticAberration = 2, fade = 0,
        contrast = 0, saturation = 2,
    },
    cinematic = {
        halationAmount = 52, halationRadius = 32, threshold = 58, softness = 48,
        warmth = 28, bloomAmount = 30, bloomRadius = 22, grainAmount = 14,
        grainSize = 1.4, vignette = 22, chromaticAberration = 8, fade = 4,
        contrast = 8, saturation = 5,
    },
    dreamy = {
        halationAmount = 68, halationRadius = 58, threshold = 48, softness = 78,
        warmth = 38, bloomAmount = 44, bloomRadius = 42, grainAmount = 7,
        grainSize = 1.1, vignette = 10, chromaticAberration = 14, fade = 8,
        contrast = -8, saturation = 8,
    },
}

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function validNumber(value, definition)
    local number = tonumber(value)
    if not number or number ~= number then
        return definition.default
    end
    return clamp(number, definition.min, definition.max)
end

local function validatedValues(propertyTable)
    local values = {}
    for key, definition in pairs(FIELD_DEFS) do
        values[key] = validNumber(propertyTable[key], definition)
    end

    local mode = propertyTable.outputMode
    if mode ~= "final" and mode ~= "halo" and mode ~= "matte" then
        mode = "final"
    end
    values.outputMode = mode
    return values
end

local function shellQuote(value)
    local text = tostring(value)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function numberArgument(value)
    local text = string.format("%.4f", value)
    return text:gsub(",", ".")
end

local function enginePath()
    local root = LrPathUtils.parent(_PLUGIN.path)
    return LrPathUtils.child(LrPathUtils.child(root, "bin"), "halation-engine")
end

local function temporaryPath()
    local path = LrFileUtils.createTempFileName()
    if LrFileUtils.exists(path) then
        LrFileUtils.delete(path)
    end
    return path
end

local function removeFile(path)
    if path and LrFileUtils.exists(path) then
        pcall(function() LrFileUtils.delete(path) end)
    end
end

local function promoteOutput(inputPath, outputPath)
    local backupPath = outputPath .. ".cbef-original"
    removeFile(backupPath)

    local movedOriginal = false
    local moved, moveResult = pcall(function()
        return LrFileUtils.move(outputPath, backupPath)
    end)
    if not moved or moveResult == false then
        return false, "원본 백업 실패: " .. tostring(moveResult)
    end
    movedOriginal = true

    local promoted, promoteResult = pcall(function()
        return LrFileUtils.move(inputPath, outputPath)
    end)
    if not promoted or promoteResult == false then
        if movedOriginal then
            pcall(function() LrFileUtils.move(backupPath, outputPath) end)
        end
        return false, "처리 결과 승격 실패: " .. tostring(promoteResult)
    end

    removeFile(backupPath)
    return true
end

local function applyPreset(propertyTable, presetName)
    local preset = PRESETS[presetName]
    if not preset then return end
    for key, value in pairs(preset) do
        propertyTable[key] = value
    end
end

local function initializeProperties(propertyTable)
    if propertyTable.preset == nil then propertyTable.preset = "subtle" end
    if propertyTable.outputMode == nil then propertyTable.outputMode = "final" end
    for key, definition in pairs(FIELD_DEFS) do
        if propertyTable[key] == nil then
            propertyTable[key] = definition.default
        end
    end
end

local function sliderRow(label, key)
    local definition = FIELD_DEFS[key]
    return f:row {
        spacing = f:control_spacing(),
        f:static_text { title = label, width = 115 },
        f:slider {
            value = bind(key),
            min = definition.min,
            max = definition.max,
            width = 145,
        },
        f:edit_field {
            value = bind(key),
            min = definition.min,
            max = definition.max,
            precision = definition.step < 1 and 1 or 0,
            width = 55,
        },
    }
end

function ExportFilter.sectionForFilterInDialog(viewFactory, propertyTable)
    initializeProperties(propertyTable)
    propertyTable:addObserver("preset", function(_, _, value)
        applyPreset(propertyTable, value)
    end)

    return viewFactory:column {
        bind_to_object = propertyTable,
        spacing = viewFactory:control_spacing(),
        viewFactory:row {
            spacing = viewFactory:control_spacing(),
            viewFactory:static_text { title = "프리셋", width = 115 },
            viewFactory:popup_menu {
                value = bind("preset"),
                items = {
                    { title = "Subtle / 은은", value = "subtle" },
                    { title = "Cinematic / 시네마틱", value = "cinematic" },
                    { title = "Dreamy / 몽환", value = "dreamy" },
                    { title = "Custom / 사용자", value = "custom" },
                },
                width = 200,
            },
            viewFactory:static_text { title = "출력", width = 42 },
            viewFactory:popup_menu {
                value = bind("outputMode"),
                items = {
                    { title = "Final / 최종", value = "final" },
                    { title = "Halo / 광륜", value = "halo" },
                    { title = "Matte / 매트", value = "matte" },
                },
                width = 120,
            },
        },
        viewFactory:separator {},
        viewFactory:static_text {
            title = "Halation / 광륜",
            font = "system",
        },
        sliderRow("Amount / 양", "halationAmount"),
        sliderRow("Radius / 반경", "halationRadius"),
        sliderRow("Threshold / 임계값", "threshold"),
        sliderRow("Softness / 부드러움", "softness"),
        sliderRow("Warmth / 따뜻함", "warmth"),
        viewFactory:separator {},
        viewFactory:static_text { title = "Bloom · Grain · Lens", font = "system" },
        sliderRow("Bloom amount / 양", "bloomAmount"),
        sliderRow("Bloom radius / 반경", "bloomRadius"),
        sliderRow("Grain amount / 양", "grainAmount"),
        sliderRow("Grain size / 크기", "grainSize"),
        sliderRow("Vignette / 비네팅", "vignette"),
        sliderRow("Chromatic aberration / 색수차", "chromaticAberration"),
        viewFactory:separator {},
        sliderRow("Fade / 페이드", "fade"),
        sliderRow("Contrast / 대비", "contrast"),
        sliderRow("Saturation / 채도", "saturation"),
        viewFactory:static_text {
            title = "Lightroom SDK는 Develop 픽셀 효과를 실시간 추가하지 않습니다. 이 필터는 내보내기 후처리입니다.",
            width = 460,
            height = 32,
        },
    }
end

ExportFilter.exportPresetFields = {
    "preset", "outputMode",
    "halationAmount", "halationRadius", "threshold", "softness", "warmth",
    "bloomAmount", "bloomRadius", "grainAmount", "grainSize", "vignette",
    "chromaticAberration", "fade", "contrast", "saturation",
}

function ExportFilter.postProcessRenderedPhotos(functionContext, filterContext)
    local settings = validatedValues(filterContext.propertyTable)
    local pathToEngine = enginePath()
    local total = #(filterContext.renditionsToSatisfy or {})
    local progressScope = LrProgressScope {
        functionContext = functionContext,
        title = "CBEF Halation 내보내기",
    }
    local index = 0

    for sourceRendition, renditionToSatisfy in filterContext:renditions() do
        index = index + 1
        if progressScope:isCanceled() then
            renditionToSatisfy:renditionIsDone(false, "사용자가 취소했습니다.")
        else
            local rendered, renderedPath = sourceRendition:waitForRender()
            if not rendered or not renderedPath then
                logger:error("렌더링 실패: " .. tostring(renderedPath))
                renditionToSatisfy:renditionIsDone(false, "렌더링 실패")
            else
                local tempOutput = temporaryPath()
                local command = table.concat({
                    shellQuote(pathToEngine),
                    "--input", shellQuote(renderedPath),
                    "--output", shellQuote(tempOutput),
                    "--halation-amount", numberArgument(settings.halationAmount),
                    "--halation-radius", numberArgument(settings.halationRadius),
                    "--threshold", numberArgument(settings.threshold),
                    "--softness", numberArgument(settings.softness),
                    "--warmth", numberArgument(settings.warmth),
                    "--bloom-amount", numberArgument(settings.bloomAmount),
                    "--bloom-radius", numberArgument(settings.bloomRadius),
                    "--grain-amount", numberArgument(settings.grainAmount),
                    "--grain-size", numberArgument(settings.grainSize),
                    "--vignette", numberArgument(settings.vignette),
                    "--chromatic-aberration", numberArgument(settings.chromaticAberration),
                    "--fade", numberArgument(settings.fade),
                    "--contrast", numberArgument(settings.contrast),
                    "--saturation", numberArgument(settings.saturation),
                    "--mode", shellQuote(settings.outputMode),
                }, " ")

                logger:info("엔진 실행: " .. pathToEngine .. " (mode=" .. settings.outputMode .. ")")
                local exitCode = LrTasks.execute(command)
                if exitCode ~= 0 or not LrFileUtils.exists(tempOutput) then
                    logger:error("엔진 실패 (exit=" .. tostring(exitCode) .. ")")
                    removeFile(tempOutput)
                    renditionToSatisfy:renditionIsDone(false, "Halation 엔진 실패 (exit " .. tostring(exitCode) .. ")")
                else
                    local promoted, promotionError = promoteOutput(tempOutput, renderedPath)
                    if promoted then
                        renditionToSatisfy:renditionIsDone(true, "CBEF Halation 완료")
                    else
                        logger:error(promotionError)
                        removeFile(tempOutput)
                        renditionToSatisfy:renditionIsDone(false, promotionError)
                    end
                end
            end
        end
        if total > 0 then
            progressScope:setPortionComplete(index, total)
        end
    end
    progressScope:done()
end

return ExportFilter
