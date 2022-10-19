-- Cut-down ST7789 driver for the feather-tft panel
_ENV = module()

TFT_WIDTH = 135
TFT_HEIGHT = 240

local DC_CMD = 0
local DC_DATA = 1

local gpio_write = gpio.write
local ch = string.char
local bor, band, lshift, rshift = bit.bor, bit.band, bit.lshift, bit.rshift

--  color modes
COLOR_MODE_65K = 0x50
COLOR_MODE_262K = 0x60
COLOR_MODE_12BIT = 0x03
COLOR_MODE_16BIT = 0x05
COLOR_MODE_18BIT = 0x06
COLOR_MODE_16M = 0x07

--  commands
ST7789_NOP = 0x00
ST7789_SWRESET = 0x01
ST7789_RDDID = 0x04
ST7789_RDDST = 0x09

ST7789_SLPIN = 0x10
ST7789_SLPOUT = 0x11
ST7789_PTLON = 0x12
ST7789_NORON = 0x13

ST7789_INVOFF = 0x20
ST7789_INVON = 0x21
ST7789_DISPOFF = 0x28
ST7789_DISPON = 0x29
ST7789_CASET = 0x2A
ST7789_RASET = 0x2B
ST7789_RAMWR = 0x2C
ST7789_RAMRD = 0x2E

ST7789_PTLAR = 0x30
ST7789_VSCRDEF = 0x33
ST7789_COLMOD = 0x3A
ST7789_MADCTL = 0x36
ST7789_VSCSAD = 0x37

ST7789_MADCTL_MY = 0x80  --  Page Address Order
ST7789_MADCTL_MX = 0x40  --  Column Address Order
ST7789_MADCTL_MV = 0x20  --  Page/Column Order
ST7789_MADCTL_ML = 0x10  --  Line Address Order
ST7789_MADCTL_MH = 0x04  --  Display Data Latch Order
ST7789_MADCTL_RGB = 0x00
ST7789_MADCTL_BGR = 0x08

ST7789_RDID1 = 0xDA
ST7789_RDID2 = 0xDB
ST7789_RDID3 = 0xDC
ST7789_RDID4 = 0xDD

--  Color definitions
BLACK = 0x0000
BLUE = 0x001F
RED = 0xF800
GREEN = 0x07E0
CYAN = 0x07FF
MAGENTA = 0xF81F
YELLOW = 0xFFE0
WHITE = 0xFFFF

local rotations = {
    {madctl=0x00, width=135, height=240, colstart=52, rowstart=40}, -- 0 (portrait)
    {madctl=0x60, width=240, height=135, colstart=40, rowstart=53}, -- 90 (landscape)
    {madctl=0xc0, width=135, height=240, colstart=53, rowstart=40}, -- 180 (reverse portrait)
    {madctl=0xa0, width=240, height=135, colstart=40, rowstart=52}, -- 270 (reverse landscape)
}
local validRotations = { [0] = 1, [90] = 2, [180] = 3, [270] = 4 }

local orientation

function hard_reset()
    gpio_write(TFT_RESET, 1)
    wait(50)
    gpio_write(TFT_RESET, 0)
    wait(50)
    gpio_write(TFT_RESET, 1)
    wait(150)
end

local function cmd(id, ...)
    assert(id, "Bad ID??")
    gpio_write(TFT_CS, 0)
    gpio_write(TFT_DC, DC_CMD)
    spidevice:transfer(ch(id))
    local nargs = select("#", ...)
    if nargs > 0 then
        gpio_write(TFT_DC, DC_DATA)
        spidevice:transfer(ch(...))
    end
    gpio_write(TFT_CS, 1)
end

function init()
    gpio_write(TFT_POWER, 1)
    hard_reset()
    cmd(ST7789_SLPOUT)
    wait(120)

    -- cmd(ST7789_MADCTL, 0)
    set_rotation(90)
    cmd(ST7789_COLMOD, bor(COLOR_MODE_65K, COLOR_MODE_16BIT), 1)
    cmd(0xB2, 0x5, 0x5, 0, 0x33, 0x33)
    cmd(0xB7, 0x23)
    cmd(0xBB, 0x22)
    cmd(0xC0, 0x2C)
    cmd(0xC2, 0x01)
    cmd(0xC3, 0x13)
    cmd(0xC4, 0x20)
    cmd(0xC6, 0x0F)

    cmd(0xD0, 0xA7, 0xA1)
    cmd(0xD0, 0xA4, 0xA1)
    cmd(0xD6, 0xA1)
    cmd(0xE0, 0x70, 0x06, 0x0C, 0x08, 0x09, 0x27, 0x2E, 0x34, 0x46, 0x37, 0x13, 0x13, 0x25, 0x2A)
    cmd(0xE1, 0x70, 0x04, 0x08, 0x09, 0x07, 0x03, 0x2C, 0x42, 0x42, 0x38, 0x14, 0x14, 0x27, 0x2C)
    cmd(0xE4, 0x22, 0, 0)
    cmd(ST7789_INVON)
    cmd(ST7789_DISPON)

    -- cmd(ST7789_CASET, 0x00, 0x34, 0x00, 0xBA)
    -- cmd(ST7789_RASET, 0x00, 0x28, 0x01, 0x17)
    -- cmd(ST7789_RAMWR)

    cmd(ST7789_SLPOUT)
    wait(120)

    fill_rect(0, 0, width(), height(), BLUE)
    gpio_write(TFT_BL, 1)
    wait(200)
end

function width()
    return rotations[orientation].width
end

function height()
    return rotations[orientation].height
end

function set_rotation(val)
    orientation = assert(validRotations[val], "Bad rotation value")
    cmd(ST7789_MADCTL, rotations[orientation].madctl);
end

function colourToStr(colour)
    return ch(band(rshift(colour, 8), 0xFF), band(colour, 0xFF))
end

function fill_rect(x, y, w, h, colour)
    local right = x + w - 1
    local bottom = y + h - 1
    local len = w * h
    set_window(x, y, right, bottom)
    gpio_write(TFT_CS, 0)
    gpio_write(TFT_DC, DC_DATA)
    local colourStr = colourToStr(colour)
    local buf = string.rep(colourStr, 128)
    local transferInfo = {
        txdata = buf,
        rxlen = 0, -- Saves some allocations native side
    }
    local nbufs = math.floor(len / 128)
    local rest = len % 128
    while nbufs > 0 do
        spidevice:transfer(transferInfo)
        nbufs = nbufs - 1
    end
    if rest > 0 then
        transferInfo.txdata = buf:sub(1, rest * 2)
        spidevice:transfer(transferInfo)
    end
    gpio_write(TFT_CS, 1)
end

function set_window(x0, y0, x1, y1)
    -- Hardcoded 135x240 portrait....
    local colstart = rotations[orientation].colstart
    local rowstart = rotations[orientation].rowstart
    cmd(ST7789_CASET, rshift(x0 + colstart, 8), band(x0 + colstart, 0xFF), rshift(x1 + colstart, 8), band(x1 + colstart, 0xFF))
    cmd(ST7789_RASET, rshift(y0 + rowstart, 8), band(y0 + rowstart, 0xFF), rshift(y1 + rowstart, 8), band(y1 + rowstart, 0xFF))
    cmd(ST7789_RAMWR)
end

function display(getPixelFn)
    local w = width()
    local h = height()
    set_window(0, 0, w - 1, h - 1)
    gpio_write(TFT_CS, 0)
    gpio_write(TFT_DC, DC_DATA)
    local buf = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            buf[x + 1] = colourToStr(getPixelFn(x, y))
        end
        local line = table.concat(buf)
        spidevice:transfer(line)
    end
    gpio_write(TFT_CS, 1)
end

return _ENV -- Must be last
