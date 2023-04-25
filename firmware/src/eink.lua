-- eink.lua
_ENV = module()

-- Translated from https://www.waveshare.com/w/upload/8/80/7.5inch-e-paper-hat-b-code.7z raspberrypi/python/epd7in5b.py
PANEL_SETTING = 0x00
POWER_SETTING = 0x01
POWER_OFF = 0x02
-- POWER_OFF_SEQUENCE_SETTING = 0x03
POWER_ON = 0x04
-- POWER_ON_MEASURE = 0x05
BOOSTER_SOFT_START = 0x06
DEEP_SLEEP = 0x07
DATA_START_TRANSMISSION_1 = 0x10
DATA_STOP = 0x11
DISPLAY_REFRESH = 0x12
IMAGE_PROCESS = 0x13
-- LUT_FOR_VCOM = 0x20
-- LUT_BLUE = 0x21
-- LUT_WHITE = 0x22
-- LUT_GRAY_1 = 0x23
-- LUT_GRAY_2 = 0x24
-- LUT_RED_0 = 0x25
-- LUT_RED_1 = 0x26
-- LUT_RED_2 = 0x27
-- LUT_RED_3 = 0x28
-- LUT_XON = 0x29
PLL_CONTROL = 0x30
-- TEMPERATURE_SENSOR_COMMAND = 0x40
TEMPERATURE_CALIBRATION = 0x41
-- TEMPERATURE_SENSOR_WRITE = 0x42
-- TEMPERATURE_SENSOR_READ = 0x43
VCOM_AND_DATA_INTERVAL_SETTING = 0x50
-- LOW_POWER_DETECTION = 0x51
TCON_SETTING = 0x60
TCON_RESOLUTION = 0x61
-- SPI_FLASH_CONTROL = 0x65
-- REVISION = 0x70
-- GET_STATUS = 0x71
-- AUTO_MEASUREMENT_VCOM = 0x80
-- READ_VCOM_VALUE = 0x81
VCM_DC_SETTING = 0x82

local bytesSent = 0
local DC_CMD, DC_DATA = 0, 1

-- Make these local for performance
local gpio_write = gpio.write
local spidevice = spidevice
local spidevice_transfer = spidevice.transfer
local ch = string.char
local print, select = print, select
local uptime = node.uptime or tmr.now
local Reset, DC, CS, Sck, Mso, SpiId = Reset, DC, CS, Sck, Mso, SpiId

local function sendByte(b, dc)
    gpio_write(DC, dc)
    spidevice_transfer(spidevice, ch(b))
    bytesSent = bytesSent + 1
end

local function cmd(id, ...)
    assert(id, "Bad ID??")
    sendByte(id, DC_CMD)
    local nargs = select("#", ...)
    if nargs > 0 then
        local data = { ... }
        for i = 1, nargs do
            sendByte(data[i], DC_DATA)
        end
    end
end

function initp()
    reset()
    cmd(POWER_SETTING, 0x37, 0x00)
    cmd(PANEL_SETTING, 0xCF, 0x08)
    cmd(BOOSTER_SOFT_START, 0xC7, 0xCC, 0x28)
    cmd(POWER_ON)
    waitUntilIdle()
    print("Powered on")
    cmd(PLL_CONTROL, 0x3C)
    cmd(TEMPERATURE_CALIBRATION, 0x00)
    cmd(VCOM_AND_DATA_INTERVAL_SETTING, 0x77)
    cmd(TCON_SETTING, 0x22)
    cmd(TCON_RESOLUTION, 0x02, 0x80, 0x01, 0x80) -- 0x0280 = 640, 0x0180 = 384
    cmd(VCM_DC_SETTING, 0x1E)
    cmd(0xE5, 0x03) -- FLASH MODE
end

function reset()
    gpio.write(Reset, 0)
    wait(200)
    gpio.write(Reset, 1)
    wait(200)
end

function waitUntilIdle()
    if gpio.read(Busy) == 1 then
        -- Already idle
        return
    end    
    print("waitUntilIdle...")
    while gpio.read(Busy) == 0 do
        wait(100)
    end
    print("Wait complete!")
end

function sleep()
    cmd(POWER_OFF)
    waitUntilIdle()
    cmd(DEEP_SLEEP, 0xA5)
end

WHITE = 3
COLOURED = 4 
BLACK = 0

local WHITE, COLOURED, BLACK = WHITE, COLOURED, BLACK

w, h = 640, 384

-- The actual display code!

function displayLines(lineFn)
    -- This overload assumes the caller already has the pixel data assembled into panel format
    setStatusLed(1)
    local t = uptime()
    cmd(DATA_START_TRANSMISSION_1)
    gpio_write(DC, DC_DATA)

    for y = 0, h - 1 do
        -- print("Line", y)
        setStatusLed(y % 2)
        local data = lineFn(y)
        spidevice_transfer(spidevice, data)
    end
    -- print("Refreshing...")
    cmd(DISPLAY_REFRESH)
    waitUntilIdle()
    local elapsed = math.floor((uptime() - t) / 1000000)
    sleep()
    printf("Display complete, took %ds", elapsed)
    setStatusLed(0)
end

function pixelFnToLineFn(getPixelFn)
    local function getLine(y)
        local line = {}
        for i = 0, math.floor(w / 2) - 1 do
            local x = i * 2
            local b = getPixelFn(x, y) * 16 + getPixelFn(x + 1, y)
            line[i+1] = ch(b)
        end
        local data = table.concat(line)
        return data
    end
    return getLine
end

function display(getPixelFn)
    displayLines(pixelFnToLineFn(getPixelFn))
end

local mod3 = { [0] = WHITE, [1] = COLOURED, [2] = BLACK }
function whiteColourBlack(x, y)
    -- Draw alternate lines of white, colour and black
    return mod3[y % 3]
end

function white()
    initp()
    display(function() return WHITE end)
end

function black()
    initp()
    display(function() return BLACK end)
end

function dither()
    initp()
    display(function(x, y)
        if x % 2 == 0 or y % 2 == 0 then
            return COLOURED
        else
            return BLACK
        end
    end)
end  

return _ENV -- Must be last