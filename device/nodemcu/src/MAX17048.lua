-- See https://github.com/adafruit/Adafruit_CircuitPython_MAX1704x/blob/main/adafruit_max1704x.py

_ENV = module()

VCELL_REG = 0x02
SOC_REG = 0x04
MODE_REG = 0x06
VERSION_REG = 0x08
HIBRT_REG = 0x0A
CONFIG_REG = 0x0C
VALERT_REG = 0x14
CRATE_REG = 0x16
VRESET_REG = 0x18
CHIPID_REG = 0x19
STATUS_REG = 0x1A
CMD_REG = 0xFE

function read(cmd, fmt)
    i2c_write(I2CAddr, cmd)
    local data = i2c_read(I2CAddr, string.packsize(fmt))
    i2c_stop()
    return string.unpack(">"..fmt, data)
end

function init(addr)
    I2CAddr = addr
    local version = read(VERSION_REG, "H")
    assert(version & 0xFFF0 == 0x0010, "Bad chip version from MAX17048!")
    i2c_write(I2CAddr, CMD_REG, 0, 0x54) -- power-on reset
end

function getVoltage()
    local v = read(VCELL_REG, "H")
    -- v is measured in units of 78.125uV ie 0.078125mV aka 10/128 mV
    return (v * 10) // 128
end

return _ENV
