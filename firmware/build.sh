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
FIRMWARE_BUILD_DIRECTORY="${FIRMWARE_DIRECTORY}/build"
NODEMCU_FIRMWARE_DIRECTORY="${FIRMWARE_DIRECTORY}/nodemcu-firmware"
NODEMCU_DIRECTORY="${ROOT_DIRECTORY}/nodemcu"
NODEMCU_ESP32_BUILD_DIRECTORY="${NODEMCU_DIRECTORY}/esp32"
SDKCONFIG_PATH="${NODEMCU_ESP32_BUILD_DIRECTORY}/sdkconfig"

# Process the command line arguments.
POSITIONAL=()
UPDATE=${UPDATE:-false}
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -u|--update)
        UPDATE=true
        shift
        ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done

function volume-flag {
    # Echo a Docker volume flag optimised for the current platform.
    # This appends the 'delegated' option when on macOS as this apparently significantly improves build times.
    VOLUME_FLAGS=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        VOLUME_FLAGS=":delegated"
    fi
    echo "--volume ${1}:${2}${VOLUME_FLAGS}"
}

cd "${NODEMCU_FIRMWARE_DIRECTORY}"
cp "$SDKCONFIG_PATH" .

# Pass the interactive flags to Docker if we're running in interactive mode.
# https://stackoverflow.com/questions/911168/how-to-detect-if-my-shell-script-is-running-through-a-pipe
DOCKER_INTERACTIVE_FLAGS=""
if [ -t 1 ]; then
    DOCKER_INTERACTIVE_FLAGS="-ti"
fi

# Ensure the Docker container is up-to-date.
if $UPDATE ; then
    docker pull marcelstoer/nodemcu-build
fi

# Build the firmware and LFS.
docker run --rm $DOCKER_INTERACTIVE_FLAGS \
    --env GIT_DIR=/opt/statuspanel/firmware/nodemcu-firmware/.git \
    --env GIT_WORK_TREE=/opt/nodemcu-firmware \
    `volume-flag "${ROOT_DIRECTORY}" /opt/statuspanel` \
    `volume-flag "${NODEMCU_FIRMWARE_DIRECTORY}" /opt/nodemcu-firmware` \
    marcelstoer/nodemcu-build build
docker run --rm $DOCKER_INTERACTIVE_FLAGS \
    -v `pwd`:/opt/nodemcu-firmware \
    --env GIT_DIR=/opt/statuspanel/firmware/nodemcu-firmware/.git \
    --env GIT_WORK_TREE=/opt/nodemcu-firmware \
    `volume-flag "${ROOT_DIRECTORY}" /opt/statuspanel` \
    `volume-flag "${NODEMCU_FIRMWARE_DIRECTORY}" /opt/nodemcu-firmware` \
    `volume-flag "${NODEMCU_DIRECTORY}" /opt/lua` \
    -v "${FIRMWARE_DIRECTORY}/make-lfs.sh:/opt/make-lfs.sh" \
    marcelstoer/nodemcu-build bash "/opt/make-lfs.sh"

# Copy the build output.
mkdir -p "${FIRMWARE_BUILD_DIRECTORY}"
cp "${NODEMCU_FIRMWARE_DIRECTORY}/build/bootloader/bootloader".{bin,elf,map} "${FIRMWARE_BUILD_DIRECTORY}"
cp "${NODEMCU_FIRMWARE_DIRECTORY}/build/NodeMCU".{bin,elf,map} "${FIRMWARE_BUILD_DIRECTORY}"
cp "${NODEMCU_FIRMWARE_DIRECTORY}/build/partitions.bin" "${FIRMWARE_BUILD_DIRECTORY}"
cp "${NODEMCU_ESP32_BUILD_DIRECTORY}/lfs.img" "${FIRMWARE_BUILD_DIRECTORY}"
