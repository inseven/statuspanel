-- init.lua

-- Some globals needed by everything before they're require'd

idf_v4 = node.LFS ~= nil

function isFeatherTft()
    return node.chipid == nil -- Basically, testing for the esp32s2
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
end

-- Currently assumes huzzah32
function configurePins_inky()
    SpiId = 1 -- HSPI (doesn't place any restriction on pins)
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

    local spimaster = spi.master(SpiId, {
        sclk = Sclk,
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

function i2c_try_write(addr, ...)
    i2c.start(i2c.SW)
    if not i2c.address(i2c.SW, addr, i2c.TRANSMITTER) then
        return nil
    end
    return i2c.write(i2c.SW, ...)
end

function i2c_read(addr, numBytes)
    i2c.start(i2c.SW)
    assert(i2c.address(i2c.SW, eepromAddr, i2c.RECEIVER))
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

    if idf_v4 then
        package.loaders[3] = function(module) -- loader_flash
            local fn = node.LFS.get(module)
            return fn or "\n\tModule not in LFS"
        end
        file_open = io.open
    else
        local flashindex = node.flashindex
        local lfs_t = {
              __index = function(_, name)
                local fn_ut, base, mapped, size, modules = flashindex(name)
                if not base then
                    return fn_ut
                elseif name == '_time' then
                    return fn_ut
                elseif name == '_config' then
                    local fs_ma, fs_size = file.fscfg()
                    return {
                        lfs_base = base, lfs_mapped = mapped, lfs_size = size,
                        fs_mapped = fs_ma, fs_size = fs_size
                    }
                elseif name == '_list' then
                    return modules
                else
                    return nil
                end
            end,

            __newindex = function(_, name, value)
                error("LFS is readonly. Invalid write to LFS." .. name, 2)
            end,
        }
        _G.LFS = setmetatable(lfs_t, lfs_t)
        -- Configure LFS
        package.loaders[3] = function(module) -- loader_flash
            local fn, base = flashindex(module)
            return base and "\n\tModule not in LFS" or fn
        end
        file_open = file.open
    end

    if isFeatherTft() then
        print("Configuring as ESP32-S2 TFT Feather")
        configurePins_tft()
    elseif node.chipid and node.chipid() == "0xee30aea419be" then
        -- Have to special-case this because the "NewBusy" eink variant unwisely used SCL for NewBusy which means we
        -- can't safely try to poke around on i2c
        printf("Configuring as NewBusy WaveShare Huzzah32")
        _isInky = false
        configurePins_eink()
    else
        local esp32_Sda = 23
        local esp32_Scl = 22
        local inky_eeprom_addr = 0x50
        i2c_setup(esp32_Sda, esp32_Scl)
        _isInky = i2c_try_write(inky_eeprom_addr, 0, 0)
        i2c_stop()

        if isInky() then
            print("Configuring as Inky Huzzah32") 
            configurePins_inky()
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

function setStatusLed(val)
    if StatusLed then
        gpio.write(StatusLed, val)
    end
end

function printf(...)
    print(string.format(...))
end

function getBatteryVoltage()
    if isFeatherTft() then
        return nil
    else
        -- At 11db attenuation and 12 bits width, 4095 = VDD_A
        local val = adc.read(adc.ADC1, VBat)
        print("Raw ADC val", val)
        -- In theory result in mV should be (val * 3.3 * 2) / 4.096
        -- In practice, calibration seems off so we use a bigger number (~3.5)
        return (val * 6973) // 4096
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
