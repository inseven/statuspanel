# NodeMCU Firmware

The firmware is responsible for managing the StatusPanel device itself. It handles WiFi setup, encryption keys, device sleep, and scheduling fetching updates, and drawing on the eInk display.

The device runs Lua using [NodeMCU](https://nodemcu.readthedocs.io/en/dev-esp32-idf4/). We use the [`tomsci-dev-esp32-idf4`](https://github.com/tomsci/nodemcu-firmware/tree/tomsci-dev-esp32-idf4) branch of NodeMCU which provides some additional features that have not yet been accepted upstream, as well as being based on the latest IDF v4 which supports the esp32s2 and esp32s3.

## Usage

## Status LED

- **Flashing** – the device is in pairing / hotspot mode.
- **On, non-flashing** – device is busy, eg downloading or processing an update, or updating the display.

## NeoPixel

On platforms that have one, the NeoPixel will use different colours to indicate different states:

- **Solid blue** – device is accessing the network.
- **Flashing blue** – device is in pairing / hotspot mode.
- **Solid green** – WiFi credentials were accepted (will shortly transition to blue indicating accessing the network.
- **Solid red** – indicates unpairing is starting (and you can stop holding down the toggle/unpair button).
- **Solid pink** – device is processing an update or updating the display.

## Development

### Installing Dependencies

StatusPanel uses a shared script for installing and managing dependencies. Follow the instructions [here](/README.markdown#installing-dependencies).

When developing on Linux, there are some additional tools which may be useful. These can be installed on Debian-based systems as follows:

```bash
sudo apt install \
    minicom \
    pipenv \
    libpq-dev
```

### Flashing Pre-Built Firmware (Updating Your Device)

1. Download the latest `main` branch firmware build from [GitHub Actions](https://github.com/inseven/statuspanel/actions/workflows/build.yaml).

2. Ensure the device is **not** set to auto.

3. Flash the latest firmware:

   ```bash
   scripts/firmware flash ~/Downloads/Firmware.zip
   ```

### Debugging and Troubleshooting

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

### Running Code On-Device

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

## Building Firmware

The easiest way to build the firmware is to use the build script:

```bash
device/nodemcu/build.sh
```

You can find the build output in `firmware/build`.

Alternatively the recent esp-idf plays quite nicely with native macOS, even on Apple Silicon:

```bash
$ cd device/nodemcu/nodemcu-firmware

# if you have python 3.11 installed on Apple Silicon, have to downgrade...
$ export PATH=/opt/homebrew/opt/python@3.9/libexec/bin:$PATH

# Only needed the first time.
$ ./sdk/esp32-esp-idf/install.sh

$ . ./sdk/esp32-esp-idf/export.sh

$ PATH=${IDF_PYTHON_ENV_PATH}:${PATH} pip install -r requirements.txt

# Change this to esp32s2 or esp32s3 if applicable (and in the make_lfs.py call below)
$ idf.py set-target esp32

$ idf.py build
$ ./make_lfs.py --max-size 0x20000 --target esp32
```

## Firmware

### Last Known Good

```bash
./esptool/esptool.py \
    --port /dev/cu.SLAB_USBtoUART \
    --baud 921600 \
    write_flash \
    --flash_mode dio \
    --flash_freq 40m \
    0x1000 device/nodemcu/src/esp32/bootloader.bin \
    0x8000 device/nodemcu/src/esp32/partition-table.bin \
    0x10000 device/nodemcu/src/esp32/nodemcu.bin \
    0x190000 device/nodemcu/src/esp32/lfs.img
```

### Latest

Assuming you've built it yourself with the "alternatively" commands in the "Building Firmware" section above:

```bash
cd device/nodemcu/nodemcu-firmware
../../../esptool/esptool.py \
    --port /dev/cu.SLAB_USBtoUART \
    --baud 921600 \
    write_flash \
    --flash_mode dio \
    --flash_freq 40m \
    0x1000 build/bootloader/bootloader.bin \
    0x8000 build/partition_table/partition-table.bin \
    0x10000 build/nodemcu.bin \
    0x190000 build/lfs.img
```

### Hardware notes

#### esp32s2

To get working serial UART on anything with native USB, in `Component config -> ESP System Settings` and set:

* `Channel for console output -> Custom UART`
* `UART peripheral to use for console output -> UART1`
* `UART TX on GPIO# -> 1`
* `UART RX on GPIO# -> 2`

Then attach a TTL serial cable to GND, RX and TX pins.

Note, this configuration is now the default, because USB CDC does not (currently) work with SPIRAM, which is required to decode PNGs and thus display anything.

#### esp32s3

The esp32s3 supports "USB JTAG" which offers a dedicated USB serial port. However the device will not boot until something connects to the serial port meaning this configuration is useless when using the device when not connected to a computer. Therefore, the default sdkconfig sets the primary console to be on the RX and TX pins, with debug output being mirrored to the USB serial port (but not supporting input on that port). This default configuration does allow the device to boot with nothing connected to the USB port, while also being able to get output out of the USB port and flash it. Just not to input commands over USB when in non-auto mode.

To revert to having the console on USB serial (eg for convenience of debugging), apply the `usbdebug.patch` diff to `sdkconfig`:

```bash
cd device/nodemcu/esp32s3
patch sdkconfig usbdebug.patch -o ../nodemcu-firmware/sdkconfig
```

## How things were made

### ios/StatusPanel/Assets.xcassets/TlsCertificates.dataset/root.pem

Is the root cert that api.statuspanel.io is using, created by:

```bash
openssl x509 -inform der -outform pem -in "Baltimore CyberTrust Root.cer" -out root.pem
```
