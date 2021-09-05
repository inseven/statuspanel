#!/bin/bash

cd /opt/lua
/opt/nodemcu-firmware/build/luac_cross/luac.cross -o esp32/lfs.img -a 0x3F440000 -m 0x20000 *.lua
