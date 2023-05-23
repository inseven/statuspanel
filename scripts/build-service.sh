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
set -u

SCRIPTS_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="${SCRIPTS_DIRECTORY}/.."
SERVICE_DIRECTORY="${ROOT_DIRECTORY}/service"
WEB_SERVICE_DIRECTORY="${SERVICE_DIRECTORY}/web"
BUILD_DIRECTORY="${SERVICE_DIRECTORY}/build"
PACKAGE_DIRECTORY="${SERVICE_DIRECTORY}/package"

source "${SCRIPTS_DIRECTORY}/environment.sh"

if [ -d "${BUILD_DIRECTORY}" ] ; then
    rm -r "${BUILD_DIRECTORY}"
fi
mkdir -p "${BUILD_DIRECTORY}"

# Process the command line arguments.
POSITIONAL=()
BUILD_PACKAGE=${BUILD_PACKAGE:-false}
START_SERVICE=false
TEST_SERVICE=false
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -p|--build-package)
        BUILD_PACKAGE=true
        shift
        ;;
        -s|--start)
        START_SERVICE=true
        shift
        ;;
        -t|--test)
        TEST_SERVICE=true
        shift
        ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done

set -x

# Set the application version number.
export VERSION=`build-tools generate-build-number`

# Build the and export docker images.
cd "${WEB_SERVICE_DIRECTORY}"
docker build -t jbmorley/statuspanel-web --build-arg VERSION=${VERSION} .
export IMAGE_SHA=`docker images -q jbmorley/statuspanel-web:latest`

# Generate the Docker compose and package files.
mkdir -p "${PACKAGE_DIRECTORY}/statuspanel-service/usr/share/statuspanel-service"
envsubst < "${SERVICE_DIRECTORY}/docker-compose.yaml" > "${PACKAGE_DIRECTORY}/statuspanel-service/usr/share/statuspanel-service/docker-compose.yaml"
envsubst < "${PACKAGE_DIRECTORY}/control" > "${PACKAGE_DIRECTORY}/statuspanel-service/DEBIAN/control"
envsubst < "${PACKAGE_DIRECTORY}/prerm" > "${PACKAGE_DIRECTORY}/statuspanel-service/DEBIAN/prerm"
chmod 0755 "${PACKAGE_DIRECTORY}/statuspanel-service/DEBIAN/prerm"

if $BUILD_PACKAGE ; then

    docker save "${IMAGE_SHA}" | gzip > "${PACKAGE_DIRECTORY}/statuspanel-service/usr/share/statuspanel-service/statuspanel-web-latest.tar.gz"

    cd "$PACKAGE_DIRECTORY"
    dpkg-deb --build statuspanel-service
    mv statuspanel-service.deb "$BUILD_DIRECTORY/statuspanel-service-$VERSION.deb"

fi

if $START_SERVICE ; then

    cd "${PACKAGE_DIRECTORY}/statuspanel-service/usr/share/statuspanel-service/"
    docker compose --env-file "${SERVICE_DIRECTORY}/.env" up

fi

if $TEST_SERVICE ; then

    function cleanup {
        cd "${PACKAGE_DIRECTORY}/statuspanel-service/usr/share/statuspanel-service/"
        docker compose down
    }

    cd "${PACKAGE_DIRECTORY}/statuspanel-service/usr/share/statuspanel-service/"
    docker compose --env-file "${SERVICE_DIRECTORY}/.env" up -d
    trap cleanup EXIT
    sleep 1
    "${SCRIPTS_DIRECTORY}/test-service.sh"

fi
