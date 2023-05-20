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
set -- "${POSITIONAL[@]:-}" # restore positional parameters
if [[ ${#POSITIONAL[@]} != 1 ]] || ! [[ "$1" =~ ^(esp32|esp32s3)$ ]]; then
    echo "Usage: build.sh [--clean] <esp32|esp32s3>"
    exit 1
fi

TARGET=$1
NODEMCU_FIRMWARE_DIRECTORY="${FIRMWARE_DIRECTORY}/nodemcu-firmware"
BUILD_DIRECTORY="${FIRMWARE_DIRECTORY}/build-${TARGET}"

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
SDKCONFIG="${BUILD_DIRECTORY}/config/sdkconfig.json"
if [ ! -f "${SDKCONFIG}" ] || [ $(cat "${SDKCONFIG}" | jq '.IDF_TARGET') != "\"${TARGET}\"" ] ; then
    idf.py -B "${BUILD_DIRECTORY}" set-target "${TARGET}"
fi

# Copy the configuration.
cp ../${TARGET}/sdkconfig .

# Optionally clean.
if $CLEAN ; then
    idf.py -B "${BUILD_DIRECTORY}" clean
fi

# Build the ROM image.
idf.py -B "${BUILD_DIRECTORY}" build

# Build the LFS image.
${IDF_PYTHON_ENV_PATH}/bin/python ${FIRMWARE_DIRECTORY}/make_lfs.py -B "${BUILD_DIRECTORY}" --max-size 0x20000 --target ${TARGET}

# Archive the artifacts.
zip --junk-paths "${BUILD_DIRECTORY}/firmware-${TARGET}.zip" \
    "${BUILD_DIRECTORY}/bootloader/bootloader.bin" \
    "${BUILD_DIRECTORY}/partition_table/partition-table.bin" \
    "${BUILD_DIRECTORY}/nodemcu.bin" \
    "${BUILD_DIRECTORY}/lfs.img"
