-- Based on https://github.com/pimoroni/inky/blob/master/library/inky/inky_uc8159.py
_ENV = module()

w = 640
h = 400

eepromAddr = 0x50

BLACK = 0
WHITE = 1
GREEN = 2
BLUE = 3
RED = 4
YELLOW = 5
ORANGE = 6
CLEAN = 7

UC8159_PSR = 0x00
UC8159_PWR = 0x01
UC8159_POF = 0x02
UC8159_PFS = 0x03
UC8159_PON = 0x04
UC8159_BTST = 0x06
UC8159_DSLP = 0x07
UC8159_DTM1 = 0x10
UC8159_DSP = 0x11
UC8159_DRF = 0x12
UC8159_IPC = 0x13
UC8159_PLL = 0x30
UC8159_TSC = 0x40
UC8159_TSE = 0x41
UC8159_TSW = 0x42
UC8159_TSR = 0x43
UC8159_CDI = 0x50
UC8159_LPD = 0x51
UC8159_TCON = 0x60
UC8159_TRES = 0x61
UC8159_DAM = 0x65
UC8159_REV = 0x70
UC8159_FLG = 0x71
UC8159_AMV = 0x80
UC8159_VV = 0x81
UC8159_VDCS = 0x82
UC8159_PWS = 0xE3
UC8159_TSSET = 0xE5

local DC_CMD, DC_DATA = 0, 1

rleLookupTable = {
    [0] = 0x00, -- BB
    [1] = 0x50, -- CB
    [2] = 0x10, -- WB
    [3] = 0x00, -- XB
    [4] = 0x05, -- BC
    [5] = 0x55, -- CC
    [6] = 0x15, -- WC
    [7] = 0x05, -- XC
    [8] = 0x01, -- BW
    [9] = 0x51, -- CW
    [10] = 0x11, -- WW
    [11] = 0x01, -- XW
    [12] = 0x00, -- BX
    [13] = 0x50, -- CX
    [14] = 0x10, -- WX
    [15] = 0x00, -- XX
}

-- Make these local for performance
local gpio_write = gpio.write
local spidevice = spidevice
local spidevice_transfer = spidevice.transfer
local ch = string.char
local uptime = node.uptime

function test_setup()
    i2c_write(eepromAddr, 0, 0)
    local bytes = i2c_read(eepromAddr, 29)
    i2c_stop()

    local width, height, color, pcb_variant, display_variant, write_time = string.unpack(">HHBBBc22", bytes)
    print(width, height, color, pcb_variant, display_variant, write_time)
end

function reset()
    gpio.write(Reset, 0)
    wait(100)
    gpio.write(Reset, 1)
    waitUntilIdle()
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

local function sendByte(b, dc)
    gpio_write(DC, dc)
    spidevice.transfer(spidevice, ch(b))
    -- bytesSent = bytesSent + 1
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

function sleep()
    cmd(UC8159_POF)
    waitUntilIdle()
    cmd(UC8159_DSLP, 0xA5)
end

function initp()
    reset()

    -- Resolution Setting
    cmd(UC8159_TRES, string.byte(string.pack(">HH", w, h), 1, 4))

    -- Panel setting
    local resolution_setting = 0x2
    cmd(UC8159_PSR, (resolution_setting << 6) | 0x2F, 0x08)

    -- Power Setting
    cmd(UC8159_PWR,
        (0x06 << 3) |  -- ??? - not documented in UC8159 datasheet
        (0x01 << 2) |  -- SOURCE_INTERNAL_DC_DC
        (0x01 << 1) |  -- GATE_INTERNAL_DC_DC
        (0x01),        -- LV_SOURCE_INTERNAL_DC_DC
        0x00,          -- VGx_20V
        0x23,          -- UC8159_7C
        0x23           -- UC8159_7C
    )

    cmd(UC8159_PLL, 0x3C)
    cmd(UC8159_TSE, 0x00)

    local cdi = (WHITE << 5) | 0x17
    cmd(UC8159_CDI, cdi)
    cmd(UC8159_TCON, 0x22)
    cmd(UC8159_DAM, 0x00)
    cmd(UC8159_PWS, 0xAA)
    cmd(UC8159_PFS, 0x00)
end

function pixelFnToLineFn(getPixelFn)
    local function getLine(y)
        local line = {}
        for i = 0, (w // 2) - 1 do
            local x = i * 2
            local b = (getPixelFn(x, y) << 4) + getPixelFn(x + 1, y)
            line[i+1] = ch(b)
        end
        local data = table.concat(line, nil, 1, w // 2)
        return data
    end
    return getLine
end

function display(getPixelFn)
    displayLines(pixelFnToLineFn(getPixelFn))
end

function displayLines(lineFn)
    -- This overload assumes the caller already has the pixel data assembled into panel format
    local t = uptime()
    cmd(UC8159_DTM1)
    gpio_write(DC, DC_DATA)

    for y = 0, h - 1 do
        local data = lineFn(y)
        collectgarbage() -- Temporary allocations that go into SRAM can deprive SPI which requires SRAM buffers for DMA
        spidevice_transfer(spidevice, data)
    end

    cmd(UC8159_PON)
    waitUntilIdle()
    cmd(UC8159_DRF)
    waitUntilIdle()

    local elapsed = math.floor((uptime() - t) / 1000000)
    sleep()
    printf("Display complete, took %ds", elapsed)
end

function displayPngFile(filename)
    local imgData, w, h = assert(lodepng.decode_file(filename, lodepng.PALETTE))
    local byte = string.byte
    local pixelFn = function(x, y)
        local pos = w * y + x
        -- Since the palette we use in the PNG is designed to exactly match our colour definitions, we can return the
        -- PNG pixel value directly.
        return byte(imgData, 1 + pos)
    end
    displayLines(pixelFnToLineFn(pixelFn))
end

return _ENV