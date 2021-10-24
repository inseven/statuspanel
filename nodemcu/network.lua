-- Network and stuff
_ENV = module()

function getImages()
    collectgarbage() -- Clear the decks...
    local deviceId = getDeviceId()

    if gw then
        setStatusLed(1)
    else
        -- No internet connection?
        return
    end

    local currentLastModified = readFile("last_modified", 32)
    local options = {
        async = true,
        bufsz = 1024,
        cert = getRootCert(),
        headers = {
            Connection = "close",
            ["If-Modified-Since"] = currentLastModified,
        },
    }

    local conn = http.createConnection("https://api.statuspanel.io/api/v2/"..deviceId, http.GET, options)
    local f
    local result = {}
    conn:on("headers", function(status, headers)
        result.date = headers.date
        if status == 200 then
            result.lastModified = headers["last-modified"]
        end
    end)
    conn:on("data", function(status, data)
        if status == 200 then
            if f == nil then
                f = assert(file.open("img_raw", "w"))
            end
            f:write(data)
        end
    end)
    conn:on("complete", function(status)
        printf("HTTP request complete status=%d", status)
        conn:close()
        conn = nil
        if f then
            f:close()
        end
        setStatusLed(0)
        result.status = status
        coresume(result)
    end)
    conn:request()
    local result = yield()
    return result
end

function readFile(name, maxSize)
    local f = file.open(name, "r")
    if f then
        local contents = f:read(maxSize)
        f:close()
        return contents
    else
        return nil, "File not found: "..name
    end
end

function writeFile(name, contents)
    if contents == nil then
        file.remove(name)
    else
        local f = assert(file.open(name, "w"))
        assert(f:write(contents))
        f:close()
    end
end

function getRootCert()
    return assert(readFile("root.pem", 2048))
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
    id = readFile("deviceid", 8)
    if id then
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
    writeFile("deviceid", id)
end

function generateKeyPair()
    local pk, sk = sodium.crypto_box.keypair()
    writeFile("pk", pk)
    writeFile("sk", sk)
    return pk, sk
end

function getPublicKey()
    if not file.exists("pk") or not file.exists("sk") then
        local pk, sk = generateKeyPair()
        return pk
    end
    return assert(readFile("pk", 32))
end

function getSecretKey()
    if not file.exists("pk") or not file.exists("sk") then
        local pk, sk = generateKeyPair()
        return sk
    end
    return assert(readFile("sk", 32))
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

function displayQRCode(url)
    assert(coroutine.running())
    local font = require("font")
    local BLACK, WHITE, w, h = panel.BLACK, panel.WHITE, panel.w, panel.h
    local urlWidth = #url * font.charw
    local data = qrcodegen.encodeText(url)
    local sz = qrcodegen.getSize(data)
    local scale = 8
    local startx = math.floor((w - sz * scale) / 2)
    local starty = math.floor((h - sz * scale) / 2)
    local textPixel = panel.getTextPixelFn(url)
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
    panel.display(getPixel)
end

function parseImgHeader(data)
    local headerLen = 0
    local wakeTime = nil
    local imageIndexes = nil
    -- FF 00 is not a valid sequence in our RLE scheme
    if data:sub(1, 2) == "\255\0" then
        headerLen = data:byte(3)
        if headerLen >= 5 then
            local wh, wl = data:byte(4, 5)
            wakeTime = wh * 256 + wl
        end
        if headerLen >= 6 then
            local numImages = data:byte(6)
            if numImages and #data >= headerLen + numImages * 4 then
                imageIndexes = {}
                for i = 0, numImages - 1 do
                    imageIndexes[i+1] = struct.unpack("<I4", data, headerLen + (i * 4) + 1)
                end
            end
        end
    end
    return wakeTime, imageIndexes
end

return _ENV -- Must be last
