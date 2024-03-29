-- Abstraction layer over eink.lua and tft.lua
_ENV = module()

if isFeatherTft() then
    tft = require("tft")
    WHITE = tft.WHITE
    COLOURED = tft.YELLOW
    BLACK = tft.BLACK
    FG = WHITE
    BG = BLACK
    w = tft.TFT_HEIGHT -- rotated
    h = tft.TFT_WIDTH
    displayLines = tft.displayEinkFormatLines
    displayPngFile = tft.displayPngFile
    display = tft.display
elseif isInky() then
    inky = require("inky")
    WHITE = inky.WHITE
    BLACK = inky.BLACK
    COLOURED = inky.YELLOW
    FG = BLACK
    BG = WHITE
    w = inky.w
    h = inky.h
    pixelFnToLineFn = inky.pixelFnToLineFn
    displayLines = inky.displayLines
    displayPngFile = inky.displayPngFile
    display = inky.display
    rleLookupTable = inky.rleLookupTable
else
    eink = require("eink")
    WHITE = eink.WHITE
    COLOURED = eink.COLOURED
    BLACK = eink.BLACK
    FG = BLACK
    BG = WHITE
    w = eink.w
    h = eink.h
    pixelFnToLineFn = eink.pixelFnToLineFn
    displayLines = eink.displayLines
    display = eink.display
    rleLookupTable = eink.rleLookupTable
end

ERRFG = BLACK
ERRBG = COLOURED

function init()
    -- eink doesn't have any one-time init
    if isFeatherTft() then
        tft.init()
    end
end

function initp()
    if eink then
        eink.initp()
    elseif inky then
        inky.initp()
    end
end

function getTextPixelFn(text, fg, bg)
    local font = require("font")
    local charw, charh = font.charw, font.charh
    local FG, BG = FG, BG
    if not fg then fg = FG end
    if not bg then bg = BG end
    return function(x, y)
        if x < 0 or x >= #text * charw or y < 0 or y >= charh then
            return bg
        end
        local textPos = 1 + (x // charw)
        local char = text:sub(textPos, textPos)
        local chx = x % charw
        return font.getPixel(char, chx, y) and fg or bg
    end
end

function displayQRCode(url)
    assert(coroutine_running())
    local font = require("font")
    local BG, FG, w, h = BG, FG, w, h
    local urlWidth = #url * font.charw
    local data = qrcodegen.encodeText(url)
    local sz = qrcodegen.getSize(data)
    local scale
    local textStart
    local texty
    if panel.h < 400 then
        scale = 3
        textStart = 0
        texty = 0
    else
        scale = 8
        textStart = (w - urlWidth) // 2
        texty = 20
    end
    local startx = (w - sz * scale) // 2
    local starty = (h - sz * scale) // 2
    local textPixel = getTextPixelFn(url)
    local function getPixel(x, y)
        if y >= texty and y < texty + font.charh then
            return textPixel(x - textStart, y - texty)
        end
        local codex = math.floor((x - startx) / scale)
        local codey = math.floor((y - starty) / scale)
        if codex >= 0 and codex < sz and codey >= 0 and codey < sz then
            return qrcodegen.getPixel(data, codex, codey) and FG or BG
        else
            return BG
        end
    end
    display(getPixel)
end

return _ENV
