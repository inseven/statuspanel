-- Network and stuff

function getImg(completion)
    local currentLastModified
    local lastModifiedFile = file.open("last_modified", "r")
    if lastModifiedFile then
        currentLastModified = lastModifiedFile:read(32)
        lastModifiedFile:close()
    end

    local f = assert(file.open("root.pem", "r"))
    local cert = f:read(2048)
    f:close()

    local deviceId = getDeviceId()
    statusTable = {}
    local batstat, batteryLow = getBatteryVoltageStatus()
    addStatus(batstat)
    if batteryLow then
        setStatusErrored()
    end
    addStatus("Device ID: %s", deviceId)
    
    if not gw and wifi.sta.getip then
        -- TODO remove this after retesting esp8266 code
        local _
        _, _, gw = wifi.sta.getip()
    end
    if gw then
        setStatusLed(1)
    else
        addErrorStatus("No internet connection!")
        if completion then
            node.task.post(function() completion(nil) end)
        end
        return
    end

    local options = {
        cert = cert,
        headers = {
            ["If-Modified-Since"] = currentLastModified,
        },
    }

    collectgarbage() -- Maximise change of TLS code not crapping itself
    http.get("https://statuspanel.io/api/v2/"..deviceId, options, function(status, response, headers)
        local hash
        if status == 304 then
            addStatus("Not modified since: %s", currentLastModified)
        elseif status == 404 then
            print("No image on server yet")
        elseif status ~= 200 then
            addErrorStatus("Error %d returned from http.get()", status)
        else
            local clen = tonumber(headers["content-length"])
            if clen and clen ~= #response then
                print("Bad response!")
            end
            print(string.format("Got data %d bytes", #response))
            local lastModifiedHeader = headers["last-modified"]
            addStatus("Update fetched: %s", headers.date)
            local pk = getPublicKey()
            local sk = getSecretKey()
            local decrypted = sodium.crypto_box.seal_open(response, pk, sk)
            if decrypted == nil then
                addErrorStatus("Failed to decrypt image data")
                -- print(response)
                status = nil
            else
                local needToUpdate = true
                hash = sodium.generichash(decrypted)
                local existingHash = getCurrentDisplayIdentifier()
                if hash == existingHash then
                    print("Image has not changed")
                    needToUpdate = false
                    status = 304 -- Prevent main() from updating the panel
                end

                if needToUpdate then
                    local f = assert(file.open("img_panel_rle", "w"))
                    f:write(decrypted)
                    f:close()
                end

                if lastModifiedHeader then
                    local f = assert(file.open("last_modified", "w"))
                    f:write(lastModifiedHeader)
                    f:close()
                end
            end
        end

        print("Done!")
        setStatusLed(0)
        if completion then
            -- Super hacky, use the date header as an approximation of the
            -- current time. Will be off by maybe a minute by the time we come
            -- to use it, but oh well. Hope there's some proper RTC and tz
            -- support before DST comes along...
            node.task.post(function() completion(status, headers and headers.date, hash) end)
        end
    end)
end

function clearCache()
    file.remove("last_modified")
    setCurrentDisplayIdentifier(nil)
end

-- Avoid o, i, 0, 1
local idchars = "abcdefghjklmnpqrstuvwxyz23456789"
function makeDeviceId()
    local t = {}
    for i = 1, 8 do
        local idx = sodium.random.uniform(#idchars) + 1
        t[i] = idchars:sub(idx, idx)
    end
    return table.concat(t)
end

local id = nil
function getDeviceId()
    if id then
        return id
    end
    local f = file.open("deviceid", "r")
    if f then
        id = assert(f:read(8))
        f:close()
        return id
    end
    -- Otherwise generate one and save it
    setDeviceId(makeDeviceId())
    return id
end

function getApSSID()
    return "SP"..getDeviceId()
end

function setDeviceId(aId)
    id = aId
    if aId == nil then
        file.remove("deviceid")
    else
        local f = assert(file.open("deviceid", "w"))
        f:write(id)
        f:close()
    end
end

function generateKeyPair()
    local pk, sk = sodium.crypto_box.keypair()
    local f = assert(file.open("pk", "w"))
    f:write(pk)
    f:close()
    f = assert(file.open("sk", "w"))
    f:write(sk)
    f:close()
    return pk, sk
end

function getPublicKey()
    if not file.exists("pk") or not file.exists("sk") then
        local pk, sk = generateKeyPair()
        return pk
    end
    local f = assert(file.open("pk", "r"))
    local pk = f:read()
    f:close()
    return pk
end

function getSecretKey()
    if not file.exists("pk") or not file.exists("sk") then
        local pk, sk = generateKeyPair()
        return sk
    end
    local f = assert(file.open("sk", "r"))
    local sk = f:read()
    f:close()
    return sk
end

function getQRCodeURL(includeSsid)
    local id = getDeviceId()
    local ssid = getApSSID()
    local pk = getPublicKey()
    -- toBase64 doesn't URL-encode the unsafe chars, so do that too
    local pkstr = encoder.toBase64(pk):gsub("[/%+%=]", function(ch) return string.format("%%%02X", ch:byte()) end)
    local result = string.format("statuspanel:r?id=%s&pk=%s", id, pkstr)
    if includeSsid then
        result = result.."&s="..getApSSID()
    end
    return result
end

function displayQRCode(url, completion)
    local font = require("font")
    local urlWidth = #url * font.charw
    local data = qrcodegen.encodeText(url)
    local sz = qrcodegen.getSize(data)
    local scale = 8
    local startx = math.floor((w - sz * scale) / 2)
    local starty = math.floor((h - sz * scale) / 2)
    local textPixel = getTextPixelFn(url)
    local texty = 20
    local textStart = math.floor((w - urlWidth) / 2)
    local function getPixel(x, y)
        if y >= texty and y < texty + font.charh then
            return textPixel(x - textStart, y - texty)
        end
        local codex = math.floor((x - startx) / scale)
        local codey = math.floor((y - starty) / scale)
        if codex >= 0 and codex < sz and codey >= 0 and codey < sz then
            return qrcodegen.getPixel(data, codex, codey) and BLACK or WHITE
        else
            return WHITE
        end
    end
    display(getPixel, completion)
end

function displayStatusImg(completion)
    displayImg("img_panel_rle", completion)
end

function fetch()
    print("Fetching image...")
    getImg(function(status, date, hash)
        if status == 404 then
            clearCache()
            local url = getQRCodeURL(false)
            initAndDisplay(url, displayQRCode, url, nil)
        elseif status == 200 then
            initAndDisplay(hash, displayStatusImg, function(wakeTime) sleepFromDate(date, wakeTime) end)
        elseif status == 304 then
            -- Need to grab waketime from existing img
            local f, packed, wakeTime = openImg("img_panel_rle")
            f:close()
            sleepFromDate(date, wakeTime)
        else
            -- Some sort of error we weren't expecting (network?)
            clearCache()
            local function completion()
                -- Try again in 5 minutes?
                sleepFor(60 * 5)
            end
            initAndDisplay(nil, displayStatusLineOnly, completion)
        end
    end)
end

function getCurrentDisplayIdentifier()
    local id
    local f = file.open("current_display", "r")
    if f then
        id = f:read()
        f:close()
    end
    return id
end

function setCurrentDisplayIdentifier(id)
    if id then
        local f = assert(file.open("current_display", "w"))
        f:write(id)
        f:close()
    else
        file.remove("current_display")
    end
end

function initAndDisplay(id, displayFn, ...)
    if not initp then
        require "panel"
    end

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
    initp(function() displayFn(unpack(args, 1, nargs)) end)
end
