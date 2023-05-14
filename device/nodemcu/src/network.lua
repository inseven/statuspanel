-- Network and stuff
_ENV = module()

IMAGE_FLAG_PNG = 1

function getImages()
    collectgarbage() -- Clear the decks...
    local deviceId = getDeviceId()

    if not gw then
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

    local conn = http.createConnection("https://api.statuspanel.io/api/v3/status/"..deviceId, http.GET, options)
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
                f = assert(file_open("img_raw", "w"))
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
        result.status = status
        coresume(result)
    end)
    conn:request()
    local result = yield()
    return result
end

function readFile(name, maxSize)
    local f = file_open(name, "r")
    if f then
        local contents = f:read(maxSize or 32)
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
        local f = assert(file_open(name, "w"))
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

--[[
Register v1 format:
statuspanel:r?id=<deviceid>&pk=<pk>[&s=<ssid>]

Register v2 format:
statuspanel:r2?id=<deviceid>&pk=<pk>[&t=<devicetype>][&s=<ssid>]

devicetype:
* 0: Original 640x384 3-colour e-ink display
* 1: 240x135 16-bit colour esp32 TFT Feather
* 2: 640x400 Pimoroni Inky Impression 4 7-colour e-ink display (PNG format)
* 3: 640x400 Pimoroni Inky Impression 4 7-colour e-ink display (3-colour RLE format)

Is used to indicate root certs need to also be supplied. The reason for
introducing a new version here is so that and old iOS client will not attempt
to pair it (because it doesn't know how to supply all the data the v2 device
requires).
]]
function getQRCodeURL(includeSsid)
    local id = getDeviceId()
    local ssid = getApSSID()
    local pk = getPublicKey()
    -- toBase64 doesn't URL-encode the unsafe chars, so do that too
    local pkstr = encoder.toBase64(pk):gsub("[/%+%=]", function(ch) return string.format("%%%02X", ch:byte()) end)
    local type
    if isFeatherTft() then
        type = 1
    elseif isInky() then
        if node.heap() > 2000000 then
            -- We have SPI RAM and can thus support PNGs
            type = 2
        else
            type = 3
        end
    else
        type = 0
    end
    local result = string.format("statuspanel:r2?id=%s&pk=%s&t=%d", id, pkstr, type)
    if includeSsid then
        result = result.."&s="..getApSSID()
    end
    return result
end

function parseImgHeader(data)
    local headerLen = 0
    local wakeTime = nil
    local imageIndexes = nil
    local flags = 0
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
                    imageIndexes[i+1] = string.unpack("<I4", data, headerLen + (i * 4) + 1)
                end
            end
        end
        if headerLen >= 8 and #data >= 8 then
            flags = string.unpack("<I2", data, 7)
        end
    end
    return wakeTime, imageIndexes, flags
end

return _ENV -- Must be last
