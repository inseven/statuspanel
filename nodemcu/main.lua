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

-- Returns the time since midnight, in seconds
function dateStringToTime(dateString)
    local h, m, s = dateString:match("(%d%d):(%d%d):(%d%d)")
    local result = (((tonumber(h) * 60) + tonumber(m)) * 60) + tonumber(s)
    return result
end

function sleepFromDate(date, wakeTime)
    -- hugely hacky date calculations, just the absolute worst
    -- Epoch is midnight this morning
    -- print(date, wakeTime)
    local now = dateStringToTime(date)

    -- wakeTime is in minutes, target is in seconds
    local target = wakeTime and wakeTime * 60 or (6 * 60 + 20) * 60
    if target < now then
        target = target + 24 * 60 * 60
    end

    local delta = target - now
    if gpio.read(UsbDetect) == 1 then
        delta = 60
    end
    sleepFor(delta)
end

function sleepFor(delta)
    wifi.stop()
    print(string.format("Sleeping for %d secs (~%d hours)", delta, math.floor(delta / (60*60))))
    local shouldUsbDetect = true
    if gpio.read(UsbDetect) == 1 then
        -- Don't wake for USB if USB is actually attached when we sleep, because
        -- that would mean we'd wake immediately.
        shouldUsbDetect = false
    end
    node.dsleeps(delta, {
        UnpairPin, (shouldUsbDetect and UsbDetect or nil),
        pull = true,
        isolate = { 12, OldBusy, AutoPin, CS, Reset, DC },
    })
end

-- For testing
function slp()
    sleepFor(-1)
end

function slpdbg()
    local function completion(status, headerDate)
        local function fmtMins(mins)
            local h = math.floor(mins / 60)
            local m = mins - (h * 60)
            return string.format("%dh%dm", h, m)
        end
        local f, packed, wakeTime = openImg("img_panel_rle")
        f:close()
        print(string.format("wakeTime is %s headerDate is %s", fmtMins(wakeTime), headerDate))
        local now = math.floor(dateStringToTime(headerDate) / 60) -- in mins

        if wakeTime < now then
            wakeTime = wakeTime + 24 * 60
        end
        print(string.format("sleepTime is %s", fmtMins(wakeTime - now)))
    end
    getImg(completion)
end

function isset64(numlo, numhi, bitnum)
    local num = numlo
    if bitnum >= 32 then
        bitnum = bitnum - 32
        num = numhi
    end
    return bit.isset(num, bitnum)
end

local provisioningSocket = nil
local function closeSocket(sock)
    print("Closing socket", sock)
    sock:close()
end

function main(autoMode)
    local wokeByUsb, wokeByUnpair
    local reason, ext, pinslo, pinshi = node.bootreason()
    if ext == 5 then -- Deep sleep wake
        if not pinshi then pinslo, pinshi = 0, 0 end
        if isset64(pinslo, pinshi, UnpairPin) then
            wokeByUnpair = true
        elseif isset64(pinslo, pinshi, UsbDetect) then
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
        if provisioningSocket then
            print("Huzzah, got creds!")
            provisioningSocket:send("OK", closeSocket)
            provisioningSocket = nil
        end
        ip = event.ip
        gw = event.gw
        if shouldFetchImage then
            fetch()
        end
    end)
    wifi.sta.on("disconnected", function(name, event)
        print("Disconnected", event.ssid, event.reason)
        if provisioningSocket then
            print("Bad creds")
            provisioningSocket:send("NO", closeSocket)
            provisioningSocket = nil
            wifi.mode(wifi.SOFTAP, false)
            return -- Already in hotspot mode, no need to retry
        end
        -- It seems like low reasons like AUTH_EXPIRE(2) can occur with valid creds, and are seemingly transient errors
        if not ip and event.reason >= 15 then
            -- This is another way in which wifi config failure can manifest.
            enterHotspotMode()
        end
    end)
    wifi.start()

    local ok, err = pcall(wifi.sta.connect)
    if not ok then
        if autoMode then
            print("Wifi connect failed, entering setup mode")
            enterHotspotMode()
        else
            print(err)
        end
    end

    -- Despite EGC being disabled at this point (by init.lua), lua.c will reenable it once init.lua is finished!
    -- So that can fsck right noff.
    tmr.create():alarm(20, tmr.ALARM_SINGLE, function()
        node.egc.setmode(node.egc.ON_ALLOC_FAILURE)
    end)
end

function resetDeviceState()
    local files = {
        "deviceid",
        "pk",
        "sk",
    }
    for _, name in ipairs(files) do
        file.remove(name)
    end
    clearCache()
    setDeviceId(nil)
end

function enterHotspotMode()
    if wifi.getmode() == wifi.STATION then
        wifi.stop()
    end
    wifi.mode(wifi.SOFTAP, false)
    wifi.ap.on("sta_connected", function(_, info)
        print("Connection from", info.mac)
    end)
    wifi.ap.on("start", function()
        listen()
    end)

    -- The password here doesn't really matter, so just reuse the public key -
    -- that's sufficiently unguessable as to prevent drive-by connections while
    -- also not adding more stuff to the QR code we need to display.
    wifi.ap.config({
        ssid = getApSSID(),
        pwd = encoder.toBase64(getPublicKey()),
        auth = wifi.AUTH_WPA2_PSK,
        hidden = false,
    }, false)
    local ip = "192.168.4.1"
    wifi.ap.setip({
        ip = ip,
        netmask = "255.255.255.0",
        gateway = ip,
        -- dns = "127.0.0.1", -- This prevents clients from even attempting DNS
    })
    wifi.start()

    local url = getQRCodeURL(true)
    initAndDisplay(url, displayQRCode, url, function() print("Finished displayQRCode") end)
end

function forgetWifiCredentials()
    wifi.stop()
    wifi.mode(wifi.STATION)
    wifi.sta.config({ssid="", auto=false}, true)
    node.restart()
end

function listen()
    local port = 9001
    print(string.format("Listening on port %d", port))
    srv = assert(net.createServer())
    srv:listen(port, function(sock)
        -- print("listen callback", sock)
        sock:on("receive", function(sock, payload)
            local ssid, pass = payload:match("([^%z]+)%z([^%z]+)")
            -- print("Got data", payload:gsub("%z", " "))
            -- print("ssid,pass=", ssid, pass)
            local function sendComplete(sock)
                print("Closing socket", sock)
                sock:close()
            end

            if ssid and pass then
                provisioningSocket = sock
                wifi.mode(wifi.STATIONAP, false)
                wifi.sta.config({ ssid=ssid, pwd=pass, auto=false }, true)
            else
                print("Payload not understood")
                sock.send("NO", sendComplete)
            end
            -- print("Got data on", sock, payload)
            -- sock:send("OK", sendComplete)
        end)
        sock:on("disconnection", function(sock, err)
            print("Disconnect", err)
        end)
        sock:on("connection", function(sock, wat)
            print("Connection", wat)
        end)
    end)
end
