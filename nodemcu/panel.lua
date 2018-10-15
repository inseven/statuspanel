-- panel.lua

-- Translated from https://www.waveshare.com/w/upload/8/80/7.5inch-e-paper-hat-b-code.7z raspberrypi/python/epd7in5b.py
PANEL_SETTING = 0x00
POWER_SETTING = 0x01
POWER_OFF = 0x02
-- POWER_OFF_SEQUENCE_SETTING = 0x03
POWER_ON = 0x04
-- POWER_ON_MEASURE = 0x05
BOOSTER_SOFT_START = 0x06
DEEP_SLEEP = 0x07
DATA_START_TRANSMISSION_1 = 0x10
DATA_STOP = 0x11
DISPLAY_REFRESH = 0x12
IMAGE_PROCESS = 0x13
-- LUT_FOR_VCOM = 0x20
-- LUT_BLUE = 0x21
-- LUT_WHITE = 0x22
-- LUT_GRAY_1 = 0x23
-- LUT_GRAY_2 = 0x24
-- LUT_RED_0 = 0x25
-- LUT_RED_1 = 0x26
-- LUT_RED_2 = 0x27
-- LUT_RED_3 = 0x28
-- LUT_XON = 0x29
PLL_CONTROL = 0x30
-- TEMPERATURE_SENSOR_COMMAND = 0x40
TEMPERATURE_CALIBRATION = 0x41
-- TEMPERATURE_SENSOR_WRITE = 0x42
-- TEMPERATURE_SENSOR_READ = 0x43
VCOM_AND_DATA_INTERVAL_SETTING = 0x50
-- LOW_POWER_DETECTION = 0x51
TCON_SETTING = 0x60
TCON_RESOLUTION = 0x61
-- SPI_FLASH_CONTROL = 0x65
-- REVISION = 0x70
-- GET_STATUS = 0x71
-- AUTO_MEASUREMENT_VCOM = 0x80
-- READ_VCOM_VALUE = 0x81
VCM_DC_SETTING = 0x82


esp32 = (gpio.mode == nil)

if esp32 then
	-- No more horrible mappings from SDK pin numbers to GPIO numbers!
	Busy = 13
	Reset = 27
	DC = 33
	CS = 15
	Sck = 5 -- I can't find this documented anywhere other than pins_arduino.h...
	Mosi = 18 -- Ditto
	SpiId = 1 -- HSPI (doesn't place any restriction on pins)
else
	-- See https://learn.adafruit.com/adafruit-feather-huzzah-esp8266/pinouts
	Busy = 4 -- GPIO 2
	Reset = 1 -- GPIO 5
	DC = 2 -- GPIO 4
	CS = 0 -- GPIO 16
	SpiId = 1 -- HSPI (CLK=14, MOSI=13, MISO=12)
	SpiClockDiv = 40
end


local bytesSent = 0
local CMD_BYTE, DATA_BYTE = 0, 1

-- Make these local for performance
local gpio_write = gpio.write
local spidevice
local spidevice_transfer
local ch = string.char
local print, select = print, select
local tmr_now = tmr.now or function() return 0 end
local Busy, Reset, DC, CS, Sck, Mso, SpiId = Busy, Reset, DC, CS, Sck, Mso, SpiId

local sendByte
if esp32 then
	function sendByte(b, dc)
		-- spidevice:transfer(ch(b))
		-- gpio_write(CS, 0)
		-- spidevice_transfer(spidevice, ch(b))
		-- gpio_write(CS, 1)

		spidevice_transfer(spidevice, {
			cmd = dc,
			txdata = ch(b),
		})
		bytesSent = bytesSent + 1
	end
else
	function sendByte(b, dc)
		gpio_write(DC, dc)
		-- Have to toggle CS on *every byte*
		gpio_write(CS, 0)
		spi.send(SpiId, b)
		bytesSent = bytesSent + 1
		gpio_write(CS, 1)
	end
end

local function cmd(id, ...)
	assert(id, "Bad ID??")
	sendByte(id, CMD_BYTE)
	local nargs = select("#", ...)
	if nargs > 0 then
		local data = { ... }
		for i = 1, nargs do
			sendByte(data[i], DATA_BYTE)
		end
	end
end

_G.cmd = cmd

local function doneFn()
	print("Done!")
end

function init1()
	if esp32 then
		gpio.config({
			gpio = { Reset, DC, --[[CS]] },
			dir = gpio.OUT,
		}, {
			gpio = Busy,
			dir = gpio.IN
		})
		local spimaster = spi.master(SpiId, {
			sclk = Sck,
			mosi = Mosi,
			max_transfer_sz = 0,
		}, 0) -- 0 means disable DMA
		spidevice = spimaster:device({
			cs = CS,
			mode = 0,
			freq = 2*1000*1000, -- ie 2 MHz
			command_bits = 1,
		})
		spidevice_transfer = spidevice.transfer
		-- gpio_write(CS, 1)
	else
		gpio.mode(Reset, gpio.OUTPUT)
		gpio.mode(DC, gpio.OUTPUT)
		gpio.mode(CS, gpio.OUTPUT)
		gpio.mode(Busy, gpio.INPUT)
		-- See https://www.waveshare.com/wiki/7.5inch_e-Paper_HAT_(B)#Communication_protocol
		spi.setup(SpiId, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, SpiClockDiv)
		gpio_write(CS, 1)
	end
	gpio_write(Reset, 0)
end

function init2(completion)
	if not completion then completion = doneFn end
	print("init2")
	reset(function()
		cmd(POWER_SETTING, 0x37, 0x00)
		cmd(PANEL_SETTING, 0xCF, 0x08)
		cmd(BOOSTER_SOFT_START, 0xC7, 0xCC, 0x28)
		cmd(POWER_ON)
		waitUntilIdle(function()
			print("powered on")
			cmd(PLL_CONTROL, 0x3C)
			-- print("cmd6")
			cmd(TEMPERATURE_CALIBRATION, 0x00)
			-- print("cmd7")
			cmd(VCOM_AND_DATA_INTERVAL_SETTING, 0x77)
			-- print("cmd8")
			cmd(TCON_SETTING, 0x22)
			-- print("cmd9")
			cmd(TCON_RESOLUTION, 0x02, 0x80, 0x01, 0x80) -- 0x0280 = 640, 0x0180 = 384
			-- print("cmd10")
			cmd(VCM_DC_SETTING, 0x1E)
			cmd(0xE5, 0x03) -- FLASH MODE
			-- print("cmd11")
			completion()
		end)
	end)
end

function reset(completion)
	if not completion then completion = doneFn end
	gpio.write(Reset, 0)
	tmr.create():alarm(200, tmr.ALARM_SINGLE, function()
		gpio.write(Reset, 1)
		tmr.create():alarm(200, tmr.ALARM_SINGLE, function()
			node.task.post(completion)
		end)
	end)
end

function waitUntilIdle(completion)
	if not completion then completion = doneFn end
	if gpio.read(Busy) == 1 then
		-- Already idle
		node.task.post(completion)
		return
	end
	print("waitUntilIdle...")

	tmr.create():alarm(100, tmr.ALARM_SEMI, function(t)
		if gpio.read(Busy) == 0 then
			t:start()
		else
			print("Wait complete!")
			t:unregister()
			node.task.post(completion)
		end
	end)

	-- while gpio.read(Busy) == 0 do -- 0 = Busy, 1 = Idle
	-- 	tmr.delay(100 * 1000)
	-- end
end

function init(completion)
	init1()
	init2(completion)
end

function sleep(completion)
	if not completion then completion = doneFn end
	cmd(POWER_OFF)
	waitUntilIdle(function()
		cmd(DEEP_SLEEP, 0xA5)
		node.task.post(completion)
	end)
end

local WHITE = 3
local COLOURED = 4 
local BLACK = 0

w, h = 640, 384

-- The actual display code!

function display(getPixelFn, completion)
	if not getPixelFn then
		getPixelFn = whiteColourBlack
	end
	local t = tmr_now()
	cmd(DATA_START_TRANSMISSION_1)
	local y = 0
	bytesSent = 0
	local function drawLine()
		if y == h then
			local pixels = bytesSent * 2
			cmd(DISPLAY_REFRESH)
			waitUntilIdle(function()
				local elapsed = (tmr_now() - t) / 1000000
				sleep(function()
					print(string.format("Wrote %d pixels, took %ds", pixels, elapsed))
					if completion then
						completion()
					end
				end)
			end)
			return
		end

		-- print("Line " ..tostring(y))
		for x = 0, w - 1, 2 do
			local b = getPixelFn(x, y) * 16 + getPixelFn(x + 1, y)
			sendByte(b, DATA_BYTE)
		end
		y = y + 1
		node.task.post(drawLine)
		-- tmr.create():alarm(100, tmr.ALARM_SINGLE, drawLine)
	end
	node.task.post(drawLine)
end

local mod3 = { [0] = WHITE, [1] = COLOURED, [2] = BLACK }
function whiteColourBlack(x, y)
	-- Draw alternate lines of white, colour and black
	return mod3[y % 3]
end

function main()
	init(function()
		-- display()
		displayImg()
	end)
end

function white()
	display(function() return WHITE end)
end

function black()
	display(function() return BLACK end)
end

function dither()
	display(function(x, y)
		if x % 2 == 0 or y % 2 == 0 then
			return COLOURED
		else
			return BLACK
		end
	end)
end	 

function displayImg()
	local rle = require("rle")
	local f = assert(file.open("img_panel_rle", "rb"))
	local function reader()
		local ch = f:read(1)
		if ch then
			return string.byte(ch)
		else
			return nil
		end
	end
	local ctx = rle.beginDecode(reader)
	local function getPixel(x, y)
		-- getPixel is always called in sequence, so don't need to seek
		return rle.getByte(ctx)
	end

	display(getPixel, function()
		f:close()
	end)
end

function getImg()
	local lastModified
	lastModifiedFile = file.open("last_modified", "r")
	if lastModifiedFile then
		lastModified = lastModifiedFile:read(32)
		lastModifiedFile:close()
	end

	local ifModifiedHeader = ""
	if lastModified then
		ifModifiedHeader = "\r\nIf-Modified-Since: "..lastModified
		lastModified = nil
	end
	local req = "GET /api/v1 HTTP/1.1\r\nHost: calendar-image-server.herokuapp.com\r\nConnection: close"..ifModifiedHeader.."\r\n\r\n"
	local conn = net.createConnection(net.TCP, 0)
	conn:on("connection", function(sock)
		print("Connected, sending")
		sock:send(req)
	end)
	local status
	local bytesRead = 0
	local lastModified
	local f
	conn:on("receive", function(sock, data)
		-- print("Got ", #data)
		if not status then
			status = tonumber(data:match("^HTTP/1.1 (%d+)"))
			if status ~= 200 then
				print("Error fetching image", status)
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
			if not lastModified then
				lastModified = data:match("Last%-Modified: (.-)[\r\n]")
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
		if lastModified then
			local lastModifiedFile = assert(file.open("last_modified", "w"))
			lastModifiedFile:write(lastModified)
			lastModifiedFile:close()
		end
		if status == 200 then
			print(string.format("Got %d bytes written at %s", bytesRead, lastModified or ""))
		end
	end)
	local _, _, gw = wifi.sta.getip()
	if gw then
		local dest = "calendar-image-server.herokuapp.com"
		conn:connect(80, dest)
	else
		print("No gateway!")
	end
end

function displayText()
	local text = "Hello, World!"
	local font = require("font")
	local oldh = h
	local charw, charh = font.charw, font.charh
	local function getPixel(x, y)
		if x >= #text * charw or y >= charh then
			return WHITE
		end
		local textPos = 1 + math.floor(x / charw)
		local char = text:sub(textPos, textPos)
		local chx = x % charw
		return font.getPixel(char, chx, y) and BLACK or WHITE
	end
	h = charh
	display(getPixel, function() h = oldh end)
end
