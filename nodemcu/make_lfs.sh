#!/bin/bash
~/dev/esp32/build/luac_cross/luac.cross -o esp32/lfs.img -a 0x3F440000 -m 0x10000 *.lua