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

FIRMWARE_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="${FIRMWARE_DIRECTORY}/.."
NODEMCU_FIRMWARE_DIRECTORY="${FIRMWARE_DIRECTORY}/nodemcu-firmware"
BUILD_DIRECTORY="${FIRMWARE_DIRECTORY}/build"

TARGET=esp32


# Process the command line arguments.
POSITIONAL=()
CLEAN=false
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -c|--clean)
        CLEAN=true
        shift
        ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done
if [ ${#POSITIONAL[@]} -ne 0 ] ; then
    echo "Usage: build.sh [--clean]"
    exit 1
fi

# Check the Python version.
if [[ $( python -V ) != "Python 3.10"* ]] ; then
    echo "Python 3.10 required."
    exit 1
fi

# Clean up the top-level build directory.
if [ -d "${BUILD_DIRECTORY}" ] ; then
    rm -r "${BUILD_DIRECTORY}"
fi
mkdir -p "${BUILD_DIRECTORY}"


# Build the firmware.
cd "${NODEMCU_FIRMWARE_DIRECTORY}"

# Only needed the first time.
export IDF_TOOLS_PATH="${FIRMWARE_DIRECTORY}/.espressif"
./sdk/esp32-esp-idf/install.sh

. ./sdk/esp32-esp-idf/export.sh
PATH=${IDF_PYTHON_ENV_PATH}:${PATH} pip install -r requirements.txt

# Change this to esp32s2 if applicable
CURRENT_TARGET=$(cat build/config/sdkconfig.json | jq '.IDF_TARGET')
if [ "${CURRENT_TARGET}" != "\"${TARGET}\"" ] ; then
    idf.py set-target "${TARGET}"
fi

exit

# Copy the configuration.
cp ../src/esp32/sdkconfig .

# Optionally clean.
if $CLEAN ; then
    idf.py clean
fi

# Build.
idf.py build

# Build the image.
./build/luac_cross/luac.cross -f -m 0x20000 -o build/lfs.tmp ../src/*.lua
./build/luac_cross/luac.cross -F build/lfs.tmp -a 0x3f430000 -o build/lfs.img

# Archive the artifacts.
zip --junk-paths "${BUILD_DIRECTORY}/firmware-${TARGET}.zip" \
    build/bootloader/bootloader.bin \
    build/partition_table/partition-table.bin \
    build/nodemcu.bin \
    build/lfs.img
