Run the following commands from the `nodecmu` directory:

    cd ~/Documents/Dev/StatusPanel/nodemcu

Once you've installed the scripts, you can connect to the board using `minicom` as follows:

    minicom -D /dev/tty.SLAB_USBtoUART -b 115200
    
---

The Arduino IDE can be a convenient way to communicate with the device. You can find out more about setting this up on the [Adafruit website](https://learn.adafruit.com/adafruit-huzzah32-esp32-feather/using-with-arduino-ide).

The firmware will automatically start if GPIO 14 is held high. This can be done by shorting it to the 3.3V pin. For debugging purposes, you may wish to leave it low and execute the code directly from the serial console:

```lua
main()
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

---

# ESP8266

## Firmware

```bash
esptool.py --port /dev/tty.SLAB_USBtoUART write_flash -fm qio 0 nodemcu-master-12-modules-2018-09-29-16-30-32-integer.bin
```

## Scripts

```bash
python ~/Documents/Dev/esp8266/nodemcu-uploader/nodemcu-uploader.py \
    --port /dev/tty.SLAB_USBtoUART \
    upload \
    panel.lua:init.lua
```

# ESP32

## Firmware

### Last Known Good

    esptool.py --chip esp32 --port /dev/cu.SLAB_USBtoUART --baud 921600 --before default_reset --after hard_reset write_flash -z --flash_mode dio --flash_freq 40m --flash_size detect 0x1000 esp32/bootloader.bin 0x10000 esp32/NodeMCU.bin 0x8000 esp32/partitions_tomsci.bin

### Latest

    esptool.py --chip esp32 --port /dev/cu.SLAB_USBtoUART --baud 921600 --before default_reset --after hard_reset write_flash -z --flash_mode dio --flash_freq 40m --flash_size detect 0x1000 ~/Documents/Dev/nodemcu/esp32/build/bootloader/bootloader.bin 0x10000 ~/Documents/Dev/nodemcu/esp32/build/NodeMCU.bin 0x8000 ~/Documents/Dev/nodemcu/esp32/build/partitions_tomsci.bin

## Script

```bash
python3 ../nodemcu-uploader/nodemcu-uploader.py \
    --port /dev/tty.SLAB_USBtoUART \
    --baud 9600 \
    --start_baud 115200 \
    upload init.lua panel.lua network.lua rle.lua font.lua root.pem
```

make menuconfig
make MORE_CFLAGS="-DLUA_NUMBER_INTEGRAL"

vs Arduino:

```bash
/Users/tomsci/Library/Arduino15/packages/esp32/tools/esptool/2.3.1/esptool --chip esp32 --port /dev/cu.SLAB_USBtoUART --baud 921600 --before default_reset --after hard_reset write_flash -z --flash_mode dio --flash_freq 80m --flash_size detect 0xe000 /Users/tomsci/Library/Arduino15/packages/esp32/hardware/esp32/1.0.0/tools/partitions/boot_app0.bin 0x1000 /Users/tomsci/Library/Arduino15/packages/esp32/hardware/esp32/1.0.0/tools/sdk/bin/bootloader_dio_80m.bin 0x10000 /var/folders/h2/xybvrtgs07g17_yvy7njh2tc0000gn/T/arduino_build_680606/epd7in5b-demo.ino.bin 0x8000 /var/folders/h2/xybvrtgs07g17_yvy7njh2tc0000gn/T/arduino_build_680606/epd7in5b-demo.ino.partitions.bin 
```

---

openssl x509 -inform der -outform pem -in "Baltimore CyberTrust Root.cer" -out root.pem


TODO:

Error in tmr_register /Users/tomsci/Documents/Dev/nodemcu/esp32/components/modules/tmr.c if interval < configured configTICK_RATE_HZ (from CONFIG_FREERTOS_HZ) rather than asserting

Last known good dev-esp32: bf58084


lcross fix issue:
https://github.com/nodemcu/nodemcu-firmware/issues/1977
tomsci_fix_crosscompiler


