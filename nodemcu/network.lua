-- Network and stuff

function getImg(completion)
	local currentLastModified
	lastModifiedFile = file.open("last_modified", "r")
	if lastModifiedFile then
		currentLastModified = lastModifiedFile:read(32)
		lastModifiedFile:close()
	end

	local ifModifiedHeader = ""
	if currentLastModified then
		ifModifiedHeader = "\r\nIf-Modified-Since: "..currentLastModified
	end
	statusTable = {}
	local req = "GET /api/v1 HTTP/1.1\r\nHost: calendar-image-server.herokuapp.com\r\nConnection: close"..ifModifiedHeader.."\r\n\r\n"
	local conn = net.createConnection(net.TCP, 0)
	conn:on("connection", function(sock)
		print("Connected, sending request")
		sock:send(req)
	end)
	local status
	local bytesRead = 0
	local lastModifiedHeader
	local f
	conn:on("receive", function(sock, data)
		-- print("Got ", #data)
		if not status then
			status = tonumber(data:match("^HTTP/1.1 (%d+)"))
			if status == 304 then
				print("Image not modified since "..currentLastModified)
			elseif status ~= 200 then
				addStatus("Error %d returned from server", status)
			end
		end
		if status ~= 200 then
			if status ~= 304 then
				print(data) -- Is probably detailed error description
			end
			return
		end

		if bytesRead == 0 then
			-- Initial data is the HTTP headers
			if not lastModifiedHeader then
				lastModifiedHeader = data:match("Last%-Modified: (.-)[\r\n]")
			end
			-- Strip remaining headers
			local _, pos = data:find("\r\n\r\n", 1, true)
			if pos then
				data = data:sub(pos + 1)
			else
				return
			end
		end
		if not f then
			f = assert(file.open("img_panel_rle", "w"))
		end
		bytesRead = bytesRead + #data
		f:write(data)
	end)
	conn:on("disconnection", function(sock)
		if f then
			f:close()
		end
		if lastModifiedHeader and lastModifiedHeader ~= currentLastModified then
			local lastModifiedFile = assert(file.open("last_modified", "w"))
			lastModifiedFile:write(lastModifiedHeader)
			lastModifiedFile:close()
		end
		if status == 200 then
			print(string.format("Got %d bytes written at %s", bytesRead, lastModifiedHeader or ""))
			addStatus("Last updated: %s", lastModifiedHeader or "?")
		elseif status == 304 then
			addStatus("Last updated: %s", currentLastModified)
		end
		setStatusLed(0)
		if completion then
			node.task.post(completion)
		end
	end)
	if not gw and wifi.sta.getip then
		-- TODO remove this after retesting esp8266 code
		local _
		_, _, gw = wifi.sta.getip()
	end
	if gw then
		setStatusLed(1)
		addStatus("IP address = %s", ip)
		local dest = "calendar-image-server.herokuapp.com"
		conn:connect(80, dest)
	else
		addStatus("No internet connection!")
	end
end