#!/bin/bash

# Copyright (c) 2018-2021 Jason Morley, Tom Sutcliffe
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

FIRMWARE_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="$( cd "$( dirname "${FIRMWARE_DIRECTORY}" )" &> /dev/null && pwd )"
NODEMCU_FIRMWARE_DIRECTORY="${FIRMWARE_DIRECTORY}/nodemcu-firmware"
NODEMCU_DIRECTORY="${ROOT_DIRECTORY}/nodemcu"
NODEMCU_ESP32_BUILD_DIRECTORY="${NODEMCU_DIRECTORY}/esp32"

SDKCONFIG_PATH="${NODEMCU_ESP32_BUILD_DIRECTORY}/sdkconfig"

# Process the command line arguments.
POSITIONAL=()
CHECKOUT=${CHECKOUT:-false}
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -c|--checkout)
        CHECKOUT=true
        shift
        ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done


if $CHECKOUT ; then
    cd "${FIRMWARE_DIRECTORY}"
    if [ -d nodemcu-firmware ] ; then
        rm -rf nodemcu-firmware
    fi
    git clone --branch tomsci_dev_esp32 https://github.com/tomsci/nodemcu-firmware.git --depth 1
    cd nodemcu-firmware
    git submodule update --init --recursive --depth 1
fi

cd "${FIRMWARE_DIRECTORY}/nodemcu-firmware"
cp "$SDKCONFIG_PATH" .


# TODO: Consider a flag for enabling/disabling interactive builds (since this easily allows configuration)
# docker run --rm -ti -v `pwd`:/opt/nodemcu-firmware marcelstoer/nodemcu-build build

docker pull marcelstoer/nodemcu-build
if [[ "$OSTYPE" == "darwin"* ]]; then
    docker run --rm -v `pwd`:/opt/nodemcu-firmware:delegated marcelstoer/nodemcu-build build

else
    docker run --rm \
        -v `pwd`:/opt/nodemcu-firmware \
        marcelstoer/nodemcu-build build
    docker run --rm \
        -v `pwd`:/opt/nodemcu-firmware \
        -v "${NODEMCU_DIRECTORY}:/opt/lua" \
        -v "${FIRMWARE_DIRECTORY}/make-lfs.sh:/opt/make-lfs.sh" \
        marcelstoer/nodemcu-build bash "/opt/make-lfs.sh"
fi
