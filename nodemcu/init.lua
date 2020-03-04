-- init.lua

-- Some globals needed by everything before they're require'd

esp32 = (gpio.mode == nil)

if esp32 then
    -- No more horrible mappings from SDK pin numbers to GPIO numbers!
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
    UsbDetect = 39 -- aka A3
else
    -- See https://learn.adafruit.com/adafruit-feather-huzzah-esp8266/pinouts
    Busy = 4 -- GPIO 2
    Reset = 1 -- GPIO 5
    DC = 2 -- GPIO 4
    CS = 0 -- GPIO 16
    SpiId = 1 -- HSPI (CLK=14, MOSI=13, MISO=12)
    SpiClockDiv = 40
end

function configurePins()
    if esp32 then
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
    else
        gpio.mode(Reset, gpio.OUTPUT)
        gpio.mode(DC, gpio.OUTPUT)
        gpio.mode(CS, gpio.OUTPUT)
        gpio.mode(Busy, gpio.INPUT)
        -- See https://www.waveshare.com/wiki/7.5inch_e-Paper_HAT_(B)#Communication_protocol
        spi.setup(SpiId, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, SpiClockDiv)
        gpio.write(CS, 1)
    end
    gpio.write(Reset, 0)
    if inputIsConnected(OriginalBusy) then
        Busy = OriginalBusy
    else
        Busy = NewBusy
    end
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


function init()
    -- Why is the default allocation limit set to 4KB? Why even is there one?
    node.egc.setmode(node.egc.ON_ALLOC_FAILURE)

    configurePins()
    local autoMode = gpio.read(AutoPin) == 1

    if not autoMode then
        -- Require panel now, so as to catch syntax errors early. But in auto mode, don't load it
        -- until after we've done the network ops, to save RAM.
        require "panel"
    end
    require "main"
    main(autoMode)
end


statusTable = {}

function setStatusLed(val)
    if StatusLed then
        gpio.write(StatusLed, val)
    end
end

function addStatus(...)
    local status = string.format(...)
    print(status)
    table.insert(statusTable, status)
end

function addErrorStatus(...)
    setStatusErrored()
    addStatus(...)
end

function setStatusErrored()
    statusTable.err = true
end

function getBatteryVoltage()
    -- At 11db attenuation and 12 bits width, 4095 = VDD_A
    local val = adc.read(adc.ADC1, VBat)
    print("Raw ADC val", val)
    -- In theory result in mV should be (val * 3.3 * 2) / 4.096
    -- In practice, calibration seems off so we use a bigger number (~3.5)
    return math.floor((val * 6973) / 4096)
end

function getBatteryVoltageStatus()
    local val = math.floor(getBatteryVoltage() / 100) -- ie 42 for 4.2V
    -- Warn below 3.4V?
    local v = math.floor(val / 10)
    local dv = val - v*10
    return string.format("%d.%dV", v, dv), val < 34
end

local ok, err = pcall(init)
if not ok then
    addStatus(err)
end
