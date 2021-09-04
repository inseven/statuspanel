panel = require "panel"
network = require "network"

local readFile, writeFile = network.readFile, network.writeFile

-- It takes about 2 seconds for board to boot so the actual time required to
-- long press is about LongPressTime plus 2 seconds.

LongPressTime = 2000 -- milliseconds
unpairPressTimer = nil
pendingNetworkTasks = {}

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

    local imageToShow
    local id = getCurrentDisplayIdentifier()
    if id and id:match("^img_1,") then
        imageToShow = "img_2"
    else
        imageToShow = "img_1"
    end

    if file.exists(imageToShow) then
        showFile(imageToShow, imageToShow == "img_1", function()
            -- This will take care of sleeping us appropriately
            executeWithNetworking(fetch)
        end)
    else
        executeWithNetworking(fetch)
    end
end

function longPressUnpair()
    print("Long press on unpair")
    setStatusLed(1)
    resetDeviceState()
    tmr.create():alarm(1000, tmr.ALARM_SINGLE, function()
        node.restart()
    end)
end

function getDateAndSleep()
    -- In lieu of an RTC or proper NTP, just grab the date header from a dumb http request
    executeWithNetworking(function()
        local _, _, headers = http.get("http://statuspanel.io/")
        local date = headers.date
        sleepFromDate(date)
    end)
end

-- Returns the time since midnight, in seconds
function dateStringToTime(dateString)
    local h, m, s = dateString:match("(%d%d):(%d%d):(%d%d)")
    local result = (((tonumber(h) * 60) + tonumber(m)) * 60) + tonumber(s)
    return result
end

function sleepFromDate(date)
    local wakeTime = getWakeTime()
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
    printf("Sleeping for %d secs (~%d hours)", delta, math.floor(delta / (60*60)))
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

function rebootAndExecute(fn)
    print("rebootAndExecute "..fn)
    assert(#fn <= 32, "bootnext script too long")
    local f = assert(file.open("boot_next", "w"))
    f:write(fn)
    f:close()
    wifi.stop()
    node.restart()
end

function executeWithNetworking(fn)
    if ip then
        fn()
    else
        if pendingNetworkTasks == nil then
            pendingNetworkTasks = {}
        end
        table.insert(pendingNetworkTasks, fn)
        if not connectStarted then
            connectWifi()
        end
    end
end

local connectStarted = false
local connectTimer
function connectWifi(hotspotOnError)
    if connectStarted then
        return
    end
    connectStarted = true
    wifi.mode(wifi.STATION)
    wifi.sta.on("got_ip", function(name, event)
        print("Got IP "..event.ip)
        if connectTimer then
            connectTimer:unregister()
            connectTimer = nil
        end
        if provisioningSocket then
            print("Huzzah, got creds!")
            provisioningSocket:send("OK", function()
                provisioningSocket:close()
                provisioningSocket = nil
                -- Give the phone time to provision an image
                tmr.create():alarm(30 * 1000, tmr.ALARM_SINGLE, function()
                    -- It appears more reliable to reboot here rather than
                    -- attempt a direct fetch, although I'm not sure why. Maybe
                    -- memory fragmentation? Or something to do with still being
                    -- in stationap mode?
                    node.restart()
                end)
            end)
            -- Since we're going to reboot, any pending tasks get binned
            pendingNetworkTasks = nil
        end
        ip = event.ip
        gw = event.gw
        if pendingNetworkTasks then
            local tasks = pendingNetworkTasks
            pendingNetworkTasks = nil
            for _, fn in ipairs(tasks) do
                fn()
            end
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
    end)
    wifi.start()

    local ok, err = pcall(wifi.sta.connect)
    if ok then
        if hotspotOnError then
            -- Start timer so that regardless of whatever confusing status events we
            -- get back from the wifi stack, if we haven't got an IP address in 10
            -- seconds we go into hotspot mode.
            connectTimer = tmr.create()
            connectTimer:alarm(10000, tmr.ALARM_SINGLE, function(timer)
                print("Timed out waiting for an IP address, entering hotspot mode")
                enterHotspotMode()
            end)
        end
    else
        if hotspotOnError then
            print("Wifi connect failed, entering setup mode")
            enterHotspotMode()
        else
            print(err)
        end
    end
end

function main()
    local autoMode = gpio.read(AutoPin) == 1
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
        print('To show enrollment QR code: enterHotspotMode()')
        print('To fetch latest image: fetch()')
        print('To display last-fetched image: showFile("img_1")')
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

    if file.exists("boot_next") then
        local fn = assert(loadfile("boot_next"))
        file.remove("boot_next") -- Do this before executing, don't wanna get stuck in a loop
        fn()
        return
    end

    local shouldTimeoutToHotspotMode = shouldFetchImage
    connectWifi(shouldTimeoutToHotspotMode)
    if shouldFetchImage then
        executeWithNetworking(fetch)
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
    pendingNetworkTasks = nil -- All planned work is cancelled
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
        ssid = network.getApSSID(),
        pwd = encoder.toBase64(network.getPublicKey()),
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

    local url = network.getQRCodeURL(true)
    initAndDisplay(url, network.displayQRCode, url, function() print("Finished displayQRCode") end)
end

function forgetWifiCredentials()
    wifi.stop()
    wifi.mode(wifi.STATION)
    wifi.sta.config({ssid="", auto=false}, true)
    node.restart()
end

function listen()
    local port = 9001
    printf("Listening on port %d", port)
    srv = assert(net.createServer())
    srv:listen(port, function(sock)
        -- print("listen callback", sock)
        sock:on("receive", function(sock, payload)
            local ssid, pass = payload:match("([^%z]+)%z([^%z]*)")
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
                -- we should now get a got_ip or disconnected callback
            else
                print("Payload not understood")
                sock:send("NO", sendComplete)
            end
        end)
        sock:on("disconnection", function(sock, err)
            print("Disconnect", err)
        end)
        sock:on("connection", function(sock, wat)
            print("Connection", wat)
        end)
    end)
end

--

function getWakeTime()
    local wakeTime = struct.unpack("I4", readFile("wake_time", 4))
    return wakeTime
end

function getImgHash()
    return readFile("img_hash", 32)
end

function fetch()
    print("Fetching image...")

    network.getImages(function(result)
        local status = result and result.status
        local function retry()
            -- Try again in 1 minute
            sleepFor(60)
        end

        if status == 404 then
            local url = network.getQRCodeURL(false)
            initAndDisplay(url, network.displayQRCode, url, retry)
        elseif status == 200 then
            processRawImage(result.lastModified)
        elseif status == 304 then
            sleepFromDate(result.date)
        else
            -- Some sort of error we weren't expecting (network?)
            local errText = status and string.format("HTTP error %d", status) or "Unknown error (no network?)"
            initAndDisplay(errText, displayErrLine, errText, retry)
        end
    end)
end

function getCurrentDisplayIdentifier()
    return readFile("current_display_identifier", 64)
end

function setCurrentDisplayIdentifier(id)
    if id then
        local f = assert(file.open("current_display_identifier", "w"))
        f:write(id)
        f:close()
    else
        file.remove("current_display_identifier")
    end
end

function initAndDisplay(id, displayFn, ...)
    -- Last arg is completion
    local nargs = select("#", ...)
    if nargs == 0 then
        -- We can assume a nil completion in this case
        nargs = 1
    end
    local args = { ... }
    local completion = args[nargs]
    if completion == nil then
        completion = function() end
    end
    assert(type(completion) == "function", "Last argument to initAndDisplay must be nil or a completion function")

    if id and id == getCurrentDisplayIdentifier() then
        print("Requested contents are already on screen, doing nothing")
        completion()
        return
    else
        setCurrentDisplayIdentifier(nil)
    end

    -- Set new completion function that wraps the passed-in one in order to call setCurrentDisplayIdentifier
    args[nargs] = function(...)
        setCurrentDisplayIdentifier(id)
        completion(...)
    end
    panel.initp(function() displayFn(unpack(args, 1, nargs)) end)
end

function processRawImage(lastModified)
    local wakeTime = network.parseImgHeader(readFile("img_raw", 5))
    writeFile("wake_time", struct.pack("I4", wakeTime))
    writeFile("last_modified", lastModified)
    writeFile("last_ip", ip) -- So we don't have to restart networking just to show the IP address
    -- For decryption we have to reboot to defrag our heap between basically every image
    rebootAndExecute("decryptImage(1)")
end

function decryptImage(index)
    printf("Decrypting image number %d...", index)
    local pk = network.getPublicKey()
    local sk = network.getSecretKey()
    collectgarbage()
    print(node.heap(), collectgarbage("count"))
    local f = assert(file.open("img_raw", "r"))
    local hdr = f:read(32)
    local fileLen = f:seek("end")
    local _, indexes = network.parseImgHeader(hdr)

    local offset = indexes[index]
    f:seek("set", offset)
    local len = (indexes[index+1] or fileLen) - offset
    printf("Reading encrypted image from %d len=%d", offset, len)
    collectgarbage()
    local encrypted = f:read(len)
    print("Decrypting data...")
    local decrypted = sodium.crypto_box.seal_open(encrypted, pk, sk)
    printf("Decrypted data len=%d", #decrypted)
    local filename = string.format("img_%d", index)
    local hashFilename = filename.."_hash"
    -- The hashes are always of the decrypted data, not of the line format we eventually write to flash
    local existingHash = readFile(hashFilename)
    local newHash = sodium.generichash(decrypted)
    local imageHasChanged = (newHash ~= existingHash)
    if imageHasChanged then
        writeDecryptedRleToLineFormat(decrypted, string.format("img_%d", index))
        writeFile(hashFilename, newHash)
    end

    if indexes[index+1] then
        rebootAndExecute(string.format("decryptImage(%d)", index+1))
    else
        -- Decrypt complete!
        print("Decrypt complete!")

        -- At the end of a decrypt we always want to display, while preserving the currently-selected image if any
        local current = getCurrentDisplayIdentifier()
        local imageToShow = current and current:match("^(img_%d+)") or "img_1"
        local completion = nil
        local autoMode = gpio.read(AutoPin) == 1
        if autoMode then
            completion = getDateAndSleep
        end
        showFile(imageToShow, imageToShow == "img_1", completion)
    end
end

-- Generated by ./makePackedLookupTable
-- This maps 4 RLE bits to 2 panel pixels (ie 8 bits, one byte)
local kLookupTable = {
    [0] = 0x00, -- BB
    [1] = 0x40, -- CB
    [2] = 0x30, -- WB
    [3] = 0x00, -- XB
    [4] = 0x04, -- BC
    [5] = 0x44, -- CC
    [6] = 0x34, -- WC
    [7] = 0x04, -- XC
    [8] = 0x03, -- BW
    [9] = 0x43, -- CW
    [10] = 0x33, -- WW
    [11] = 0x03, -- XW
    [12] = 0x00, -- BX
    [13] = 0x40, -- CX
    [14] = 0x30, -- WX
    [15] = 0x00, -- XX
}

function writeDecryptedRleToLineFormat(decrypted, filename)
    local outf = assert(file.open(filename, "w"))
    local rle = require("rle")
    local rle_getByte, string_byte, string_char, band, rshift = rle.getByte, string.byte, string.char, bit.band, bit.rshift
    local w, h = panel.w, panel.h

    local bufIdx = 0
    local function reader()
        bufIdx = bufIdx + 1
        return string_byte(decrypted, bufIdx)
    end
    local ctx = rle.beginDecode(reader)
    -- The unpacked RLE data is 2bpp, whereas the panel is 4bpp. ie each byte of
    -- RLE data is 4 pixels, which equates to 2 bytes of panel format
    for y = 1, h do
        -- print("line", y)
        local line = {}
        for x = 1, w / 4 do
            local b = rle_getByte(ctx)
            line[x] = string_char(kLookupTable[band(b, 0xF)], kLookupTable[rshift(b, 4)])
        end
        outf:write(table.concat(line))
    end
    outf:close()
end

function getDisplayStatusLineFn(customText, isErrText)
    local batstat, batteryLow = getBatteryVoltageStatus()
    local statusTable = {
        batstat,
        "Device ID: "..network.getDeviceId(),
    }
    if customText then
        table.insert(statusTable, customText)
    else
        local ip = readFile("last_ip")
        if ip then
            table.insert(statusTable, "IP address: "..ip)
        end
        local lastModified = readFile("last_modified")
        if lastModified then
            table.insert(statusTable, "Data from: "..lastModified)
        end
    end
    local err = batteryLow or isErrText
    local statusText = table.concat(statusTable, " | ")
    local fg = BLACK
    local bg = err and COLOURED or WHITE
    return panel.getTextPixelFn(statusText, fg, bg)
end

function displayErrLine(line, completion)
    local getTextPixel = getDisplayStatusLineFn(line, true)
    local charh = require("font").charh
    local starth = (panel.h - charh) / 2
    local endh = starth + charh
    display(function(x, y)
        if y >= starth and y < endh then
            return getTextPixel(x, y - starth)
        else
            return WHITE
        end
    end, completion)
end

function displayLineFormatFile(filename, statusLine, completion)
    local f = assert(file.open(filename, "r"))
    local w = panel.w
    local statusLineFn, statusLineStart
    if statusLine then
        statusLineStart = panel.h - require("font").charh
    end
    -- print("statusLine", statusLine)
    if statusLine == true then
        statusLineFn = panel.pixelFnToLineFn(getDisplayStatusLineFn())
    elseif statusLine then
        statusLineFn = panel.pixelFnToLineFn(panel.getTextPixelFn(statusLine, panel.BLACK, panel.WHITE))
    end

    local function readLine(y)
        if statusLineFn and y >= statusLineStart then
            return statusLineFn(y - statusLineStart)
        else
            return f:read(w / 2)
        end
    end
    panel.displayLines(readLine, function()
        f:close()
        completion()
    end)
end

function showFile(filename, statusLine, completion)
    local id = string.format("%s,%s", filename, readFile(filename.."_hash"))
    initAndDisplay(id, displayLineFormatFile, filename, statusLine, completion)
end
