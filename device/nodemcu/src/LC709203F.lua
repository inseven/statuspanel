-- See https://github.com/adafruit/Adafruit_CircuitPython_LC709203F/blob/main/adafruit_lc709203f.py

_ENV = module()

I2CADDR_DEFAULT = 0x0B
CMD_ICVERSION = 0x11
CMD_BATTPROF = 0x12
CMD_POWERMODE = 0x15
CMD_APA = 0x0B
CMD_INITRSOC = 0x07
CMD_CELLVOLTAGE = 0x09
CMD_CELLITE = 0x0F
CMD_CELLTEMPERATURE = 0x08
CMD_THERMISTORB = 0x06
CMD_STATUSBIT = 0x16

POWER_MODE_OPERATE = 1
POWER_MODE_SLEEP = 2

-- These are pseudo-commands only used for calculating CRCs. I'm moderately sure
-- these should actually be derived from I2CAddr not I2CADDR_DEFAULT, ie the
-- actual I2C address being used, based on my reading of the datasheet. But
-- that's not what the adafruit code does, and I don't have a device where the
-- address isn't 0xB so I can't test it.
local WriteCmd = I2CADDR_DEFAULT << 1
local ReadCmd = WriteCmd | 1

local function doCrc(crc, byte, ...)
    if byte == nil then
        return crc
    end
    crc = crc ~ byte
    for _ = 1, 8 do
        if crc & 0x80 > 0 then
            crc = (crc << 1) ~ 0x7
        else
            crc = crc << 1
        end
        crc = crc & 0xFF
    end
    return doCrc(crc, ...)
end

function generateCrc(...)
    return doCrc(0, ...)
end

function read(cmd)
    assert(I2CAddr, "Must call init(addr) first!")
    i2c_write(I2CAddr, cmd)
    local data = i2c_read(I2CAddr, 3)
    i2c_stop()
    local result, crc = string.unpack("<HB", data)
    local expectedCrc = generateCrc(WriteCmd, cmd, ReadCmd, string.byte(data, 1, 2))
    assert(crc == expectedCrc, "CRC check failed on LC709203F I2C read!")
    -- print("crc", crc, expectedCrc)
    return result
end

function write(cmd, data)
    assert(I2CAddr, "Must call init(addr) first!")
    local dataLo = data & 0xFF
    local dataHi = (data >> 8) & 0xFF
    local crc = generateCrc(WriteCmd, cmd, dataLo, dataHi)
    i2c_write(I2CAddr, cmd, dataLo, dataHi, crc)
    i2c_stop()
end

function init(addr)
    I2CAddr = addr
    write(CMD_POWERMODE, POWER_MODE_OPERATE)
    write(CMD_APA, 0x19) -- 1000mAh
    write(CMD_BATTPROF, 1) -- ??
    write(CMD_INITRSOC, 0xAA55)
end

function getVoltage()
    return read(CMD_CELLVOLTAGE)
end

return _ENV
