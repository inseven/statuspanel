-- init.lua

-- Some globals needed by everything before they're require'd

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
	StatusLed = 21
else
	-- See https://learn.adafruit.com/adafruit-feather-huzzah-esp8266/pinouts
	Busy = 4 -- GPIO 2
	Reset = 1 -- GPIO 5
	DC = 2 -- GPIO 4
	CS = 0 -- GPIO 16
	SpiId = 1 -- HSPI (CLK=14, MOSI=13, MISO=12)
	SpiClockDiv = 40
end

function configurePins()
	if esp32 then
		gpio.config({
			gpio = { Reset, DC, StatusLed },
			dir = gpio.OUT,
		}, {
			gpio = Busy,
			dir = gpio.IN
		})
		-- See https://github.com/nodemcu/nodemcu-firmware/issues/1617 for best documentation of new API
		local spimaster = spi.master(SpiId, {
			sclk = Sck,
			mosi = Mosi,
			max_transfer_sz = 0,
		}, 1) -- 1 means enable DMA
		spidevice = spimaster:device({
			cs = CS,
			mode = 0,
			freq = 2*1000*1000, -- ie 2 MHz
		})
	else
		gpio.mode(Reset, gpio.OUTPUT)
		gpio.mode(DC, gpio.OUTPUT)
		gpio.mode(CS, gpio.OUTPUT)
		gpio.mode(Busy, gpio.INPUT)
		-- See https://www.waveshare.com/wiki/7.5inch_e-Paper_HAT_(B)#Communication_protocol
		spi.setup(SpiId, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, SpiClockDiv)
		gpio.write(CS, 1)
	end
	gpio.write(Reset, 0)
end

function init()
	-- First things first, start bringing up WiFi since getting an IP address takes time
	if esp32 then
		wifi.mode(wifi.STATION)
		wifi.sta.on("got_ip", function(name, event)
			print("Got IP "..event.ip)
			ip = event.ip
			gw = event.gw
			-- Why is the default allocation limit set to 4KB? Why even is there one?
			node.egc.setmode(node.egc.ON_ALLOC_FAILURE)
		end)
		wifi.start()
		wifi.sta.connect()
	end

	configurePins()

	-- Finally, pull in other modules
	require "panel"
	require "network"
end


statusTable = {}

function setStatusLed(val)
	if StatusLed then
		gpio.write(StatusLed, val)
	end
end

function addStatus(...)
	local status = string.format(...)
	print(status)
	table.insert(statusTable, status)
end

local ok, err = pcall(init)
if not ok then
	addStatus(err)
end
