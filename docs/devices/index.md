---
title: Devices
---

# Devices

There are three versions of StatusPanel with each being defined by its choice of display:

- **Version 1**--[Waveshare 640x384 7.5" Three-Color E-Ink HAT for Raspberry Pi](https://www.waveshare.com/7.5inch-e-paper-hat-c.htm)
- **Version 2**--[Pimoroni Inky Impression 4](https://shop.pimoroni.com/products/inky-impression-4?variant=39599238807635)
- **Mini**--[Adafruit ESP32-S2 TFT Feather](https://www.adafruit.com/product/5300)

In order to ease prototyping and development, we have two hardware platforms:

- **ESP32**--Lua \
  Low-power, robust to power cycling and perfect for battery powered devices.
- **Raspberry Pi**--Python \
  Enables incredibly rapid bring-up and testing of new screens as they are often well supported on Raspberry Pis.

Our long-term focus is on designing a custom PCB for ESP32-based devices.

## Building Your Own

Until we can offer a custom PCB to make it really easy to build an ESP32-based StatusPanel, the Raspberry Pi-based Version 2 device is the easiest to build. Right now, this also offers the largest choice of third-party cases.

### Parts List

- [Raspberry Pi Zero 2 WH](https://www.adafruit.com/product/3708)[^1]
- [Pimoroni Inky Impression 4](https://shop.pimoroni.com/products/inky-impression-4?variant=39599238807635)
- [Power adapter](https://www.adafruit.com/product/1995)
- [SD card](https://www.adafruit.com/product/1294)
- Case

[^1]: Any recent Raspberry Pi should work but the power of anything more than a Zero would be wasted on StatusPanel and will make your device much bulkier.

### Assembly Instructions

1. Connect the Raspberry Pi Zero 2 and Pimoroni Inky Impression 4.
2. Download the latest Raspberry Pi firmware.
3. Flash the firmare to your SD card using the Raspberry Pi Imager
   - Select 'Other' when selecting your operating system and choose the new downloaded firmware image.
   - Unlike the ESP32 firmware, the Rasbperry Pi implementation doesn't support WiFi configuration during pairing time--you will do it in the Raspberry Pi imager.
   - Click the gear icon and find the section entitled 'XXX'/ Enter your WiFi details in here and click 'OK' to confirm. (Feel free to configure additional details like setting the default account details, enabling ssh and setting the hostname if you want to tinker with your StatusPanel later on.)
4. Insert the SD card into the Raspberry Pi, connect up the power, and turn it on.
5. The first boot will take quite some time as the Raspberry Pi expands the disk image and performs initial setup--please be patient.
6. Install the latest version of StatusPanel for iOS while you're waiting.
7. Once initial setup is complete, your new StatusPanel should display a pairing QR code. Scan this code with your iPhone, and follow the on-screen instructions to set up your new StatusPanel!

### Cases

We're working on some designs for dedicated StatusPanel cases. Until these are available, you can use use something like the '[Desktop Case for Pimoroni Inky Impression 4"](https://www.shapeways.com/product/WHY25YGN8/desktop-case-for-pimoroni-inky-impression-4-quot)' by [printminion](https://cults3d.com/en/users/printminion/3d-models). They sell prints directly on Shapeways but these are a little pricy, so you may want to buy the [STL files](https://cults3d.com/en/3d-model/gadget/desktop-case-for-pimoroni-inky-impression-4-7-colour-epaper-eink-hat-and-raspberry-pi-zero-3-a) and print your own.
