require "network"

-- It takes about 2 seconds for board to boot so the actual time required to
-- long press is about LongPressTime plus 2 seconds.

LongPressTime = 2000 -- milliseconds
unpairPressTimer = nil

function unpairPressed()
    local pressed = gpio.read(UnpairPin) == 1
    if not pressed then
        -- Already released
        shortPressUnpair()
    else
        unpairDownTime = node.uptime()
        unpairPressTimer = tmr.create()
        unpairPressTimer:alarm(LongPressTime, tmr.ALARM_SINGLE, timerExpired)
        gpio.trig(UnpairPin, gpio.INTR_DOWN, unpairReleased)
    end
end

function timerExpired()
    unpairPressTimer = nil
    if unpairDownTime then
        unpairDownTime = nil
        longPressUnpair()
    end
end

function unpairReleased()
    if unpairPressTimer then
        unpairPressTimer:unregister()
        unpairPressTimer = nil
    end

    if unpairDownTime then
        local delta = node.uptime() - unpairDownTime
        unpairDownTime = nil
        if delta >= LongPressTime * 1000 then
            longPressUnpair()
        else
            shortPressUnpair()
        end
    end
end

function shortPressUnpair()
    print("Short press on unpair")
end

function longPressUnpair()
    print("Long press on unpair")
    setStatusLed(1)
end

function sleepFromDate(date, wakeTime)
    -- hugely hacky date calculations, just the absolute worst
    -- Epoch is midnight this morning
    -- print(date, wakeTime)
    local h, m, s = date:match("(%d%d):(%d%d):(%d%d)")
    h, m, s = tonumber(h), tonumber(m), tonumber(s)
    local now = (((h * 60) + m) * 60) + s

    -- wakeTime is in minutes, target is in seconds
    local target = wakeTime and wakeTime * 60 or (6 * 60 + 20) * 60
    if target < now then
        target = target + 24 * 60 * 60
    end

    local delta = target - now
    if gpio.read(UsbDetect) == 1 then
        delta = 10
    end
    sleepFor(delta)
end

function sleepFor(delta)
    print(string.format("Sleeping for %d secs (~%d hours)", delta, math.floor(delta / (60*60))))
    wifi.stop()
    node.dsleeps(delta, { UnpairPin, UsbDetect, pull=true })
end

-- For testing
function slp()
    sleepFor(60)
end

-- Sigh, bit library is 32-bit only
function isset64(num, bitnum)
    if bitnum >= 32 then
        bitnum = bitnum - 32
        num = num / 0x100000000
    end
    return bit.isset(num, bitnum)
end

function main(autoMode)
    local wokeByUsb, wokeByUnpair
    local reason, ext, pins = node.bootreason()
    if ext == 5 then -- Deep sleep wake
        if not pins then pins = 0 end
        if isset64(pins, UnpairPin) then
            wokeByUnpair = true
        elseif isset64(pins, UsbDetect) then
            wokeByUsb = true
        end
    end

    if not autoMode then
        print("To show enrollment QR code: initp(displayRegisterScreen)")
        print("To fetch latest image: getImg()")
        print("To display last-fetched image: initp(displayStatusImg)")
        if wokeByUsb then
            print("Woke up by UsbDetect (A3)")
        end
        if wokeByUnpair then
            print("Woke up by UnpairPin (32)")
        end
    end

    local shouldFetchImage = autoMode

    if wokeByUnpair then
        shouldFetchImage = false
        unpairPressed()
    end

    wifi.mode(wifi.STATION)
    wifi.sta.on("got_ip", function(name, event)
        print("Got IP "..event.ip)
        ip = event.ip
        gw = event.gw
        if shouldFetchImage then
            fetch()
        end
    end)
    wifi.start()
    wifi.sta.connect()
end