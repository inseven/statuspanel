-- Network and stuff

function getImg(completion)
	local currentLastModified
	lastModifiedFile = file.open("last_modified", "r")
	if lastModifiedFile then
		currentLastModified = lastModifiedFile:read(32)
		lastModifiedFile:close()
	end

	local deviceId = getDeviceId()
	statusTable = {}
	addStatus("Device ID: %s", deviceId)
	
	if not gw and wifi.sta.getip then
		-- TODO remove this after retesting esp8266 code
		local _
		_, _, gw = wifi.sta.getip()
	end
	if gw then
		setStatusLed(1)
		addStatus("IP address = %s", ip)
	else
		addStatus("No internet connection!")
		node.task.post(function() completion(nil) end)
		return
	end

	local headers = {
		["If-Modified-Since"] = currentLastModified,
	}

	http.get("https://statuspanel.io/api/v2/"..deviceId, headers, function(status, response, headers)
		if status == 304 then
			addStatus("Last updated: %s", currentLastModified)
		elseif status == 404 then
			print("No image on server yet")
		elseif status ~= 200 then
			addStatus("Error %d returned from server", status)
		else
			local lastModifiedHeader = headers["last-modified"]
			addStatus("Last updated: %s", lastModifiedHeader or "?")
			local pk = getPublicKey()
			local sk = getSecretKey()
			local decrypted = sodium.crypto_box_seal_open(response, pk, sk)
			if decrypted == nil then
				addStatus("Failed to decrypt image data")
				print(response)
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
			node.task.post(function() completion(status) end)
		end
	end)
end

-- Avoid o, i, 0, 1
local idchars = "abcdefghjklmnpqrstuvwxyz23456789"
function makeDeviceId()
	local t = {}
	for i = 1, 8 do
		local idx = sodium.randombytes_uniform(#idchars) + 1
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
	id = makeDeviceId()
	f = assert(file.open("deviceid", "w"))
	f:write(id)
	f:close()
	return id
end

function generateKeyPair()
	local pk, sk = sodium.crypto_box_keypair()
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
	getImg(function(status)
		if status == 404 then
			initp(displayRegisterScreen)
		else
			initp(displayImg)
		end
	end)
end
