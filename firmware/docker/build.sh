#!/bin/bash

# Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e
set -o pipefail
set -x
set -u

PROJECT_ROOT="/opt/statuspanel"
LUA_ROOT="$PROJECT_ROOT/nodemcu"
NODEMCU_FIRMWARE_ROOT="$PROJECT_ROOT/firmware/nodemcu-firmware"
BUILD_DIRECTORY="$PROJECT_ROOT/firmware/build"
SDKCONFIG_PATH="$PROJECT_ROOT/nodemcu/esp32/sdkconfig"
LUAC_CROSS_PATH="$NODEMCU_FIRMWARE_ROOT/build/luac_cross/luac.cross"

INIT_SCRIPT="\"(node.flashindex(\\\"init\\\") or (function() print(\\\"No LFS!\\\") end))()\""

# Check that the project is in the expected location.
if [ ! -d "$PROJECT_ROOT" ] ; then
    echo "Unable to find source at /opt/statuspanel. Did you forget to run the script inside Docker?"
    exit 1
fi

# Clean up previous builds.
if [ -d "$BUILD_DIRECTORY" ] ; then
    rm -r "$BUILD_DIRECTORY"
fi
mkdir -p "$BUILD_DIRECTORY"

# Build the firmware
cp -u "$SDKCONFIG_PATH" "$NODEMCU_FIRMWARE_ROOT"
cd "$NODEMCU_FIRMWARE_ROOT"
python -m pip install --user -r sdk/esp32-esp-idf/requirements.txt
make MORE_CFLAGS="-DLUA_NUMBER_INTEGRAL -DLUA_INIT_STRING='$INIT_SCRIPT'"
cp "$NODEMCU_FIRMWARE_ROOT"/build/bootloader/bootloader.* "$BUILD_DIRECTORY"
cp "$NODEMCU_FIRMWARE_ROOT"/build/NodeMCU.* "$BUILD_DIRECTORY"
cp "$NODEMCU_FIRMWARE_ROOT"/build/partitions.bin "$BUILD_DIRECTORY"

# Build the LFS.
cd "$LUA_ROOT"
"$LUAC_CROSS_PATH" -o "$BUILD_DIRECTORY/lfs.img" -a 0x3F440000 -m 0x20000 *.lua

# Compress the build directory.
cd "$BUILD_DIRECTORY"
zip rom.zip *
