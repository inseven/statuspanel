-- init.lua

idf_v4 = node.LFS ~= nil

local _isFeatherTft = false

function isFeatherTft()
    return _isFeatherTft
end

local _isInky = false
function isInky()
    return _isInky
end

-- Assumes huzzah32 (original esp32 feather)
function configurePins_eink()
    OriginalBusy = 13
    NewBusy = 22 -- aka SCL
    Reset = 27
    DC = 33
    CS = 15
    Sck = 5
    Mosi = 18
    SpiId = 1 -- HSPI (doesn't place any restriction on pins)
    StatusLed = 21
    AutoPin = 14
    VBat = 7 -- That is, ADC1_CH7 aka GPIO 35 (internally connected to BAT)
    UnpairPin = 32
    UnpairActiveHigh = true
    UsbDetect = 39 -- aka A3
    DeepSleepIsolatePins = { 12, OldBusy, AutoPin, CS, Reset, DC }

    gpio.config({
        gpio = { Reset, DC, StatusLed },
        dir = gpio.OUT,
    }, {
        gpio = { OriginalBusy, NewBusy, UsbDetect },
        dir = gpio.IN
    }, {
        gpio = { AutoPin, UnpairPin },
        dir = gpio.IN,
        pull = gpio.PULL_DOWN
    })
    local spimaster = spi.master(SpiId, {
        sclk = Sck,
        mosi = Mosi,
        max_transfer_sz = 0,
    }, 1) -- 1 means enable DMA
    spidevice = spimaster:device({
        cs = CS,
        mode = 0,
        freq = 2*1000*1000, -- ie 2 MHz
    })
    adc.setup(adc.ADC1, VBat, adc.ATTEN_11db)
    adc.setwidth(adc.ADC1, 12)
    gpio.write(Reset, 0)
    -- if inputIsConnected(OriginalBusy) then
    -- Don't get clever, just hard code for my board (for the moment)
    if node.chipid() ~= "0xee30aea419be" then
        Busy = OriginalBusy
    else
        Busy = NewBusy
    end
end

function configurePins_tft()
    TFT_POWER = 21
    TFT_CS = 7
    TFT_DC = 39
    TFT_RESET = 40
    TFT_BL = 45
    TFT_MOSI = 35
    TFT_SCLK = 36
    UnpairPin = 0
    UnpairActiveHigh = false
    StatusLed = 13
    NeoPixelPin = 33
    NeoPixelPowerPin = 34
    Sda = 42
    Scl = 41

    gpio.config({
        gpio = { TFT_RESET, TFT_DC, TFT_BL, TFT_POWER, TFT_CS, StatusLed, NeoPixelPin, NeoPixelPowerPin },
        dir = gpio.OUT,
    }, {
        gpio = { UnpairPin },
        dir = gpio.IN,
        pull = gpio.PULL_UP,
    })

    local spimaster = spi.master(1, {
        sclk = TFT_SCLK,
        mosi = TFT_MOSI,
        max_transfer_sz = 0,
    }, 1) -- 1 means enable DMA
    spidevice = spimaster:device({
        mode = 0,
        freq = 40*1000*1000, -- ie 40 MHz
    })

    -- Doing this before the spi setup hangs, no idea why...
    i2c_setup(Sda, Scl)
end

function configurePins_inky(chiptype)
    local spiHost, spiDmaChannel
    if chiptype == "esp32s3" then
        spiHost = 1
        spiDmaChannel = 3 -- SPI_DMA_CH_AUTO
        Sda = 3 -- Pi: GP2 (SDA)
        Scl = 4 -- Pi: GP3 (SCL)
        Reset = 11 -- Pi: GP27
        Busy = 16 -- A2, Pi: GP17
        DC = 10 -- Pi: GP22
        Mosi = 35 -- Pi: 10 (MOSI)
        Sclk = 36 -- Pi: 11 (SCLK)
        CS = 9 -- Pi: 8 (CE0)
        ButtonA = 6 -- Pi: GP5
        -- ButtonB = ? -- Pi: GP6
        -- ButtonC = ? -- Pi: GP16
        -- ButtonD (Pi: GP24) we connect to reset so doesn't have a esp32 GPIO pin number

        AutoPin = 5
        StatusLed = 13 -- feather onboard LED
        NeoPixelPin = 33
        NeoPixelPowerPin = 21
        UnpairPin = ButtonA
        UnpairActiveHigh = false
        UsbDetect = 15 -- aka A3
        -- Haven't looked at battery drain yet
        DeepSleepIsolatePins = { }
    else
        spiHost = 1 -- HSPI (doesn't place any restriction on pins)
        spiDmaChannel = 1 
        Sda = 23 -- Pi: GP2 (SDA)
        Scl = 22 -- Pi: GP3 (SCL)
        Reset = 27 -- Pi: GP27 (really)
        Busy = 34 -- A2, Pi: GP17
        DC = 33 -- Pi: GP22
        Mosi = 18 -- Pi: 10 (MOSI)
        Sclk = 5 -- Pi: 11 (SCLK)
        CS = 15 -- Pi: 8 (CE0)
        ButtonA = 32 -- Pi: GP5
        -- ButtonB = ? -- Pi: GP6
        -- ButtonC = ? -- Pi: GP16
        -- ButtonD (Pi: GP24) we connect to reset so doesn't have a esp32 GPIO pin number

        AutoPin = 14
        VBat = 7 -- That is, ADC1_CH7 aka GPIO 35 (internally connected to BAT)
        StatusLed = 13 -- Just use the feather onboard LED
        UnpairPin = ButtonA
        UnpairActiveHigh = false
        UsbDetect = 39 -- aka A3
        -- For some reason isolating CS messes up after wakeup from deepsleep. I cannot figure out what's supposed to happen
        -- from the docs, so it's easiest for now just not to isolate it. And it probably doesn't save any power anyway...
        DeepSleepIsolatePins = { 12 }
    end

    gpio.config({
        gpio = { Reset, DC, CS, StatusLed },
        dir = gpio.OUT,
    }, {
        gpio = { Busy },
        dir = gpio.IN
    }, {
        gpio = { ButtonA },
        dir = gpio.IN,
        pull = gpio.PULL_UP
    }, {
        gpio = { AutoPin, UsbDetect },
        dir = gpio.IN,
        pull = gpio.PULL_DOWN
    })
    if NeoPixelPin then
        gpio.config({
            gpio = { NeoPixelPin, NeoPixelPowerPin },
            dir = gpio.OUT,
        })
        gpio.write(NeoPixelPowerPin, 0)
    end
    if chiptype == "esp32s3" then
        -- Disable STEMMA QT port to save a bit more power
        local i2cPower = 7
        gpio.config({ gpio = i2cPower, dir = gpio.OUT })
        gpio.write(i2cPower, 0)
    end

    local spimaster = spi.master(spiHost, {
        sclk = Sclk,
        mosi = Mosi,
        max_transfer_sz = 0,
    }, spiDmaChannel)
    spidevice = spimaster:device({
        cs = CS,
        mode = 0,
        freq = 2*1000*1000, -- ie 2 MHz
    })
    if VBat then
        adc.setup(adc.ADC1, VBat, adc.ATTEN_11db)
        adc.setwidth(adc.ADC1, 12)
    end
    gpio.write(Reset, 0)
end

-- Assumes pin is configured without pullups/downs
function inputIsConnected(pin)
    gpio.config { gpio = pin, dir = gpio.IN, pull = gpio.PULL_DOWN }
    local pulledDown = gpio.read(pin) == 0

    gpio.config { gpio = pin, dir = gpio.IN, pull = gpio.PULL_UP }
    local pulledUp = gpio.read(pin) == 1

    gpio.config { gpio = pin, dir = gpio.IN }
    return not(pulledUp and pulledDown)
end

-- In practice we're going to always be using slow SW i2c in projects like this
function i2c_setup(sda, scl, speed)
    i2c.setup(i2c.SW, sda, scl, speed or i2c.SLOW)
end

function i2c_write(addr, ...)
    i2c.start(i2c.SW)
    assert(i2c.address(i2c.SW, addr, i2c.TRANSMITTER))
    i2c.write(i2c.SW, ...)
end

-- Returns true if anything acks addr 
function i2c_ping(addr)
    i2c.start(i2c.SW)
    local ok = i2c.address(i2c.SW, addr, i2c.TRANSMITTER)
    i2c.stop(i2c.SW)
    return ok
end

function i2c_read(addr, numBytes)
    i2c.start(i2c.SW)
    assert(i2c.address(i2c.SW, addr, i2c.RECEIVER))
    return i2c.read(i2c.SW, numBytes)
end

function i2c_stop()
    i2c.stop(i2c.SW)
end

function init()
    -- Lua 5.3 nodemcu doesn't seem to have a (functional) egc limit
    if node.egc then
        -- Why is the default allocation limit set to 4KB? Why even is there one?
        node.egc.setmode(node.egc.ON_ALLOC_FAILURE)
    end

    -- We're assuming idf_v4 is true here, support for old LFS logic dropped
    package.loaders[3] = function(module) -- loader_flash
        local fn = node.LFS.get(module)
        return fn or "\n\tModule not in LFS"
    end
    file_open = io.open

    local chiptype = (node.chiptype and node.chiptype()) or "esp32"
    -- Since we never made any non-TFT S2 StatusPanels, just assume any S2 is a
    -- Feather TFT, there isn't really a better way to do this atm.
    _isFeatherTft = chiptype == "esp32s2"

    if isFeatherTft() then
        print("Configuring as ESP32-S2 TFT Feather")
        configurePins_tft()
    elseif node.chipid and node.chipid() == "0xee30aea419be" then
        -- Have to special-case this because the "NewBusy" eink variant unwisely used SCL for NewBusy which means we
        -- can't safely try to poke around on i2c
        printf("Configuring as NewBusy WaveShare Huzzah32")
        configurePins_eink()
    else
        local sda, scl
        if chiptype == "esp32" then
            sda = 23
            scl = 22
        elseif chiptype == "esp32s3" then
            sda = 3
            scl = 4
            -- Don't bother doing detection if we know it's an S3
            _isInky = true
        else
            error("Unsupported chip type "..chiptype)
        end
        local inky_eeprom_addr = 0x50
        -- print("i2c_setup")
        i2c_setup(sda, scl)
        if not _isInky then
            -- print("i2c_setup done")
            _isInky = i2c_ping(inky_eeprom_addr)
            i2c_stop()
        end

        if isInky() then
            print("Configuring as Inky "..chiptype) 
            configurePins_inky(chiptype)
        else
            printf("Configuring as OldBusy WaveShare Huzzah32")
            configurePins_eink()
        end
    end

    require("main")
    main()
end

-- Syntax: _ENV = module()
-- This works on both Lua 5.1 and >= 5.2
function module()
    local env = setmetatable({}, {__index = _G})
    if setfenv then
        setfenv(2, env)
    end
    return env
end

function printf(...)
    print(string.format(...))
end

local _batt

function getBatteryVoltage()
    if VBat then
        -- At 11db attenuation and 12 bits width, 4095 = VDD_A
        local val = adc.read(adc.ADC1, VBat)
        print("Raw ADC val", val)
        -- In theory result in mV should be (val * 3.3 * 2) / 4.096
        -- In practice, calibration seems off so we use a bigger number (~3.5)
        return (val * 6973) // 4096
    elseif _batt == false then
        return nil
    else
        if _batt == nil then
            -- esp32s3 can ship with one of two different battery monitors, sigh
            if i2c_ping(0xB) then
                _batt = require("LC709203F")
                _batt.init(0xB)
            elseif i2c_ping(0x36) then
                _batt = require("MAX17048")
                _batt.init(0x36)
            else
                _batt = false
                return nil
            end
        end
        return _batt.getVoltage()
    end
end

function getBatteryVoltageStatus()
    local v = getBatteryVoltage()
    if not v then return "?", false end

    local val = v // 100 -- ie 42 for 4.2V
    -- Warn below 3.4V?
    local v = val // 10
    local dv = val - v * 10
    return string.format("%d.%dV", v, dv), val < 34
end

local co = nil
local coTimer = nil

function coresume(...)
    assert(co, "Cannot call coresume() when there's no active coroutine!")
    local ok, ret, param = coroutine.resume(co, ...)
    if not ok then
        print("ERROR:", debug.traceback(co, ret))
        co = nil
        -- TODO something... deepsleep?
    elseif ret == "wait" then
        -- print("Waiting at", node.uptime())
        coTimer:interval(param)
        coTimer:start()
    elseif ret == "yield" then
        -- Callers responsibility to call coresume() at a later point
    elseif coroutine.status(co) == "dead" then
        -- coroutine has finished whatever it was doing
        co = nil
        coTimer = nil
    else
        print("Unknown yield command!", ret)
    end
    -- print("coresume complete")
end

function costart(fn, ...)
    assert(co == nil, "Cannot nest coroutines!") -- Well you can, but we aren't supporting it...
    co = coroutine.create(fn)
    coTimer = tmr.create()
    local function coTimerExpired()
        -- print("Continuing at", node.uptime())
        coresume("tmr")
    end
    coTimer:register(1000, tmr.ALARM_SEMI, coTimerExpired)
    coresume(...)
end

function wait(ms)
    assert(coroutine_running(), "Attempt to wait not from within costart()!")
    local ret = coroutine.yield("wait", ms)
    assert(ret == "tmr", "Resume was not from timer expiry! "..ret)
end

-- Manual yield, caller is responsible for calling coresume()
function yield()
    assert(coroutine_running(), "Attempt to yield not from within costart()!")
    return coroutine.yield("yield")
end

-- Why oh why did you change this, Lua 5.3? Without so much as a note in the "Incompatibilities" section...
function coroutine_running()
    local co, main = coroutine.running()
    if main == nil then
        -- Lua 5.1
        return co ~= nil
    else
        return not main
    end
end

local ok, err = pcall(init)
if not ok then
    print(err)
end
