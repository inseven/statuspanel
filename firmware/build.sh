#!/bin/bash

FIRMWARE_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="${FIRMWARE_DIRECTORY}/.."
NODEMCU_FIRMWARE_DIRECTORY="${FIRMWARE_DIRECTORY}/nodemcu-firmware"

docker pull marcelstoer/nodemcu-build

pushd "$NODEMCU_FIRMWARE_DIRECTORY"
docker run --rm -ti -v `pwd`:/opt/nodemcu-firmware marcelstoer/nodemcu-build build
popd
