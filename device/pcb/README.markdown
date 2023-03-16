# PCB

## Bill of Materials

| *Part*                                                                              | *Supplier*        | *Link*                                              | *Cost* | *Quantity* |
| ----------------------------------------------------------------------------------- | ----------------- | --------------------------------------------------- | ------ | ---------- |
| Tactile Button Switch (6 mm)                                                        | Adafruit          | https://www.adafruit.com/product/367                | $0.125 | 1          |
| Breadboard-friendly SPDT Slide Switch / E-Switch EG1218                             | Adafruit / Mouser | https://www.adafruit.com/product/805 / https://www.mouser.com/ProductDetail/E-Switch/EG1218                | $0.95  | 1          |
| Adafruit HUZZAH32 – ESP32 Feather Board                                             | Adafruit          | https://www.adafruit.com/product/3405               | $19.95 | 1          |
| 640x384, 7.5inch E-Ink display HAT for Raspberry Pi, yellow/black/white three-color | Waveshare         | https://www.waveshare.com/7.5inch-e-paper-hat-c.htm | $53.99 | 1          |
| Diffused 3mm LED                                                                    | Adafruit          | https://www.adafruit.com/product/4202               | $0.118 | 1          |

Possible future display:

- [Waveshare 1304×984, 12.48inch E-Ink display module, red/black/white three-color](https://www.waveshare.com/product/raspberry-pi/12.48inch-e-paper-module-b.htm)

It looks like Waveshare are phasing out the display we're currently using and replacing it with one of the same physical size, but a higher resolution.

## Components

The EagleCAD files make use of the following component libraries which are added to the project as submodules:

- pcb/libraries/SparkFun-Eagle-Libraries/SparkFun-LED.lbr

## Schematics

![Schematics](statuspanel.png)

## Pinouts

![Tom's notes](pinout.jpg)
