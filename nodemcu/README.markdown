# Firmware

## Getting Started

Install submodules:

```bash
git submodule update --init
```

Install dependencies:

Ubuntu:

```bash
sudo apt install \
     minicom \
     pipenv \
     libpq-dev
```

Install the Python dependencies:

```bash
./scripts/install_dependencies.sh
```

Flash the latest firmware:

```bash
./scripts/firmware flash
```

Open a serial console (useful for debugging):

```bash
./scripts/firmware console
```

The USB device can be customized by specifying `--device` on the command line, or setting the `STATUSPANEL_DEVICE` environment variable.

## Using Commands Directly

Run the following commands from the `nodecmu` directory:

    cd ~/Documents/Dev/StatusPanel/nodemcu

Once you've installed the scripts, you can connect to the board using `minicom` as follows:

    minicom -D /dev/tty.SLAB_USBtoUART -b 115200

---

The Arduino IDE can be a convenient way to communicate with the device. You can find out more about setting this up on the [Adafruit website](https://learn.adafruit.com/adafruit-huzzah32-esp32-feather/using-with-arduino-ide).

The firmware will automatically start if GPIO 14 is held high. This can be done by shorting it to the 3.3V pin. For debugging purposes, you may wish to leave it low (or disconnected) and execute the code directly from the serial console:

```lua
enterHotspotMode()           -- To show enrollment QR code
fetch()                      -- To fetch latest image
showFile("img_1")            -- To display last-fetched image
```

### Wi-Fi

Once you've flashed the latest firmware, you'll need to configure Wi-Fi from the serial console as follows, substituting your network name and password:

```lua
wifi.sta.config({auto = false, ssid = "<yourssid>", pwd = "<password>"}, true)
```

### Reset

There's currently no hardware mechanism to reset (un-pair) the device. You'll need to delete the configuration files from the device and then restart it:

```lua
file.remove("deviceid")
file.remove("sk")
```

(If you remove just `"deviceid"`, you'll initiate new device registration but with the same keys as before, which probably isn't desirable.)

---

# ESP8266

_No longer supported._

# ESP32

## Firmware

### Last Known Good

```bash
esptool.py \
    --port /dev/cu.SLAB_USBtoUART \
    --baud 921600 \
    write_flash \
    --flash_mode dio \
    --flash_freq 40m \
    0x1000 esp32/bootloader.bin \
    0x10000 esp32/NodeMCU.bin \
    0x8000 esp32/partitions.bin \
    0x190000 esp32/lfs.img
```

vs Arduino:

```bash
/Users/tomsci/Library/Arduino15/packages/esp32/tools/esptool/2.3.1/esptool --chip esp32 --port /dev/cu.SLAB_USBtoUART --baud 921600 --before default_reset --after hard_reset write_flash -z --flash_mode dio --flash_freq 80m --flash_size detect 0xe000 /Users/tomsci/Library/Arduino15/packages/esp32/hardware/esp32/1.0.0/tools/partitions/boot_app0.bin 0x1000 /Users/tomsci/Library/Arduino15/packages/esp32/hardware/esp32/1.0.0/tools/sdk/bin/bootloader_dio_80m.bin 0x10000 /var/folders/h2/xybvrtgs07g17_yvy7njh2tc0000gn/T/arduino_build_680606/epd7in5b-demo.ino.bin 0x8000 /var/folders/h2/xybvrtgs07g17_yvy7njh2tc0000gn/T/arduino_build_680606/epd7in5b-demo.ino.partitions.bin
```

### Latest

    esptool.py --port /dev/cu.SLAB_USBtoUART --baud 921600 write_flash --flash_mode dio --flash_freq 40m 0x1000 ~/Documents/Dev/nodemcu/esp32/build/bootloader/bootloader.bin 0x10000 ~/Documents/Dev/nodemcu/esp32/build/NodeMCU.bin 0x8000 ~/Documents/Dev/nodemcu/esp32/build/partitions_tomsci.bin

## Updating Lua scripts

Before getting started, you'll have to install the Python dependencies:

```bash
cd nodemcu
pipenv install
```

Ensure the device is **not** set to auto, and use `nodemcu-uploader.py` to copy the script files:


```bash
pipenv run python3 ../nodemcu-uploader/nodemcu-uploader.py \
    --port /dev/tty.SLAB_USBtoUART \
    --baud 115200 \
    --start_baud 115200 \
    upload bootstrap:init.lua root.pem
```

## How things were made

### root.pem

Is the root cert that statuspanel.io is using, created by:

```bash
openssl x509 -inform der -outform pem -in "Baltimore CyberTrust Root.cer" -out root.pem
```

### The ROM image

Drop sdkconfig in, run `make MORE_CFLAGS="-DLUA_NUMBER_INTEGRAL"`.
To rebuild LFS, run `make_lfs.sh` (although that is configured for my cross-VM-mountpointed setup).

The ROM image should be built using @tomsci's branch of NodeMCU at https://github.com/tomsci/nodemcu-firmware/tree/tomsci_dev_esp32.
