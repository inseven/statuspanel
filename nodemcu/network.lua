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
    addStatus(getBatteryVoltageStatus())
    addStatus("Device ID: %s", deviceId)
    
    if not gw and wifi.sta.getip then
        -- TODO remove this after retesting esp8266 code
        local _
        _, _, gw = wifi.sta.getip()
    end
    if gw then
        setStatusLed(1)
        addStatus("IP: %s", ip)
    else
        addStatus("No internet connection!")
        node.task.post(function() completion(nil) end)
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
        if status == 304 then
            addStatus("Not modified since: %s", currentLastModified)
        elseif status == 404 then
            print("No image on server yet")
        elseif status ~= 200 then
            addStatus("Error %d returned from server", status)
        else
            local clen = tonumber(headers["content-length"])
            if clen and clen ~= #response then
                print("Bad response!")
            end
            local lastModifiedHeader = headers["last-modified"]
            addStatus("Update fetched: %s", headers.date)
            local pk = getPublicKey()
            local sk = getSecretKey()
            local decrypted = sodium.crypto_box.seal_open(response, pk, sk)
            if decrypted == nil then
                addStatus("Failed to decrypt image data")
                -- print(response)
                status = nil
            else
                local f = assert(file.open("img_panel_rle", "w"))
                f:write(decrypted)
                f:close()

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
            node.task.post(function() completion(status, headers and headers.date) end)
        end
    end)
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

function setDeviceId(aId)
    id = aId
    f = assert(file.open("deviceid", "w"))
    f:write(id)
    f:close()
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

function getQRCodeURL()
    local id = getDeviceId()
    local pk = getPublicKey()
    -- toBase64 doesn't URL-encode the unsafe chars, so do that too
    local pkstr = encoder.toBase64(pk):gsub("[/%+%=]", function(ch) return string.format("%%%02X", ch:byte()) end)
    return string.format("statuspanel:r?id=%s&pk=%s", id, pkstr)
end

function displayRegisterScreen()
    local font = require("font")
    local url = getQRCodeURL()
    local urlWidth = #url * font.charw
    local data = qrcodegen.encodeText(url, 1, 5)
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
    display(getPixel)
end

function main()
    getImg(function(status, date)
        if not initp then
            require "panel"
        end
        if status == 404 then
            initp(displayRegisterScreen)
        elseif status == 200 then
            initp(function()
                displayImg(function() sleepFromDate(date) end)
            end)
        end
    end)
end

function sleepFromDate(date)
    -- hugely hacky date calculations, just the absolute worst
    -- Epoch is midnight this morning
    local h, m, s = date:match("(%d%d):(%d%d):(%d%d)")
    h, m, s = tonumber(h), tonumber(m), tonumber(s)
    local secs = (((h * 60) + m) * 60) + s

    local targeth, targetm = 24 + 6, 20 -- ie 6:20am tomorrow
    -- local targeth, targetm = h, m+3 -- DEBUG
    local target = ((targeth * 60) + targetm) * 60

    local delta = target - secs
    print(string.format("Sleeping for %d secs (~%d hours)", delta, math.floor(delta / (60*60))))
    node.dsleeps(delta)
end
