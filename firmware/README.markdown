# Firmware

The firmware is responsible for managing the StatusPanel device itself. It handles WiFi setup, encryption keys, device sleep, and scheduling fetching updates, and drawing on the eInk display.

The device runs Lua using [NodeMCU](https://nodemcu.readthedocs.io/en/release/). We the [`tomsci_dev_esp32`](https://github.com/tomsci/nodemcu-firmware/tree/tomsci_dev_esp32) branch of NodeMCU which provides some additional features that have not yet been accepted upstream.

## Usage

## Status LED

- **Continuous Flashs=ing** -- the device is in pairing / hotspot mode

## Development

### Installing dependencies

StatusPanel uses a shared script for installing and managing dependencies. Follow the instructions [here](/README.markdown#installing-dependencies).

When developing on Linux, there are some additional tools which may be useful. These can be installed on Debian-based systems as follows:

```bash
sudo apt install \
    minicom \
    pipenv \
    libpq-dev
```

### Flashing pre-built firmware (updating your device)

1. Ensure the device is **not** set to auto.

2. Flash the latest firmware.

   ```bash
   scripts/firmware flash
   ```

   The USB device can be customized by specifying `--device` on the command line, or setting the `STATUSPANEL_DEVICE` environment variable.

### Debugging and troubleshooting

The serial console is your first port of call when trying to work out why something isn't working correctly; log output is directed here, and you call [execute Lua code directly on-device](#running-code-on-device) if you really need to poke things to see what's going on. You have lots of options for how to connect to the serial console...

- Using the `firmware` tool:

  ```bash
  scripts/firmware console
  ```

- Using Minicom directly (the `firmware` tool uses Minicom under the hood, but you can launch it yourself if you want full control):

  ```bash
  minicom -D /dev/tty.SLAB_USBtoUART -b 115200
  ```

- Using the Arduino IDE

  The Arduino IDE can also be a convenient way to communicate with the device. You can find out more about setting this up on the [Adafruit website](https://learn.adafruit.com/adafruit-huzzah32-esp32-feather/using-with-arduino-ide).

### Running code on-device

The device run-loop will automatically start if the auto switch is on (GPIO 14 held high). If you wish to run Lua code on-device and manually step through the lifecycle to investigate problems, disable this and connect to the StatusPanel with a [console](#debugging-and-troubleshooting).

- **Initiate Automatic Wi-Fi Setup**

  ```lua
  enterHotspotMode() -- show enrollment QR code
  ```

- **Manually Configure Wi-Fi**

  ```lua
  wifi.sta.config({auto = false, ssid = "<yourssid>", pwd = "<password>"}, true)
  ```

- **Fetch Updates**

  ```lua
  fetch() -- fetch latest image from the service
  ```

- **Display Update**

  ```lua
  showFile("img_1") -- display last-fetched image
  ```

- **Reset / Unpair**

  ```lua
  file.remove("deviceid") -- remove the unique device identifier
  file.remove("sk") -- remove the device secret used to encrypt updates
  wifi.sta.config({auto = false, ssid = "", pwd = ""}, true) -- clear the WiFi details
  file.remove("last_modified") -- remove details of the last cached update
  ```

  N.B. If you remove just `"deviceid"`, you'll initiate new device registration but with the same keys as before, which probably isn't desirable.

## Building firmware

https://github.com/marcelstoer/docker-nodemcu-build

Drop sdkconfig in, run `make MORE_CFLAGS="-DLUA_NUMBER_INTEGRAL"`.
To rebuild LFS, run `make_lfs.sh` (although that is configured for my cross-VM-mountpointed setup).

---

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
/Users/tomsci/Library/Arduino15/packages/esp32/tools/esptool/2.3.1/esptool \
    --chip esp32 \
    --port /dev/cu.SLAB_USBtoUART \
    --baud 921600 \
    --before default_reset \
    --after hard_reset write_flash \
    -z \
    --flash_mode dio \
    --flash_freq 80m \
    --flash_size detect \
    0xe000 /Users/tomsci/Library/Arduino15/packages/esp32/hardware/esp32/1.0.0/tools/partitions/boot_app0.bin \
    0x1000 /Users/tomsci/Library/Arduino15/packages/esp32/hardware/esp32/1.0.0/tools/sdk/bin/bootloader_dio_80m.bin \
    0x10000 /var/folders/h2/xybvrtgs07g17_yvy7njh2tc0000gn/T/arduino_build_680606/epd7in5b-demo.ino.bin \
    0x8000 /var/folders/h2/xybvrtgs07g17_yvy7njh2tc0000gn/T/arduino_build_680606/epd7in5b-demo.ino.partitions.bin
```

### Latest

```bash
esptool.py \
    --port /dev/cu.SLAB_USBtoUART \
    --baud 921600 \
    write_flash \
    --flash_mode dio \
    --flash_freq 40m \
    0x1000 ~/Documents/Dev/nodemcu/esp32/build/bootloader/bootloader.bin \
    0x10000 ~/Documents/Dev/nodemcu/esp32/build/NodeMCU.bin \
    0x8000 ~/Documents/Dev/nodemcu/esp32/build/partitions_tomsci.bin
```

## How things were made

### root.pem

Is the root cert that statuspanel.io is using, created by:

```bash
openssl x509 -inform der -outform pem -in "Baltimore CyberTrust Root.cer" -out root.pem
```
