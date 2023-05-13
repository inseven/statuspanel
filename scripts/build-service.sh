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
TESTS_DIRECTORY="${SERVICE_DIRECTORY}/tests"

source "${SCRIPTS_DIRECTORY}/environment.sh"

if [ -d "${BUILD_DIRECTORY}" ] ; then
    rm -r "${BUILD_DIRECTORY}"
fi
mkdir -p "${BUILD_DIRECTORY}"

set -x

export BUILD_NUMBER=`build-tools generate-build-number`

# Build the and export docker images.
# TODO: Just reference the image by SHA here as that's guaranteed stable and will allow us to simplify versioning issues.
# dockerSHA=$(docker inspect --format='{{index .RepoDigests 0}}' mySuperCoolTag  | perl -wnE'say /sha256.*/g')
cd "${WEB_SERVICE_DIRECTORY}"
docker build -t jbmorley/statuspanel-web .
docker tag jbmorley/statuspanel-web "jbmorley/statuspanel-web:${BUILD_NUMBER}"

# TODO: Make this conditional

# Generate the Docker image and compose file.
mkdir -p "${PACKAGE_DIRECTORY}/statuspanel-service/usr/share/statuspanel-service"
docker save "jbmorley/statuspanel-web:${BUILD_NUMBER}" | gzip > "${PACKAGE_DIRECTORY}/statuspanel-service/usr/share/statuspanel-service/statuspanel-web-latest.tar.gz"
envsubst < "${SERVICE_DIRECTORY}/docker-compose.yaml" > "${PACKAGE_DIRECTORY}/statuspanel-service/usr/share/statuspanel-service/docker-compose.yaml"

# Create the Debian package.
export VERSION="1.0.0"
envsubst < "${PACKAGE_DIRECTORY}/control" > "${PACKAGE_DIRECTORY}/statuspanel-service/DEBIAN/control"
cd "$PACKAGE_DIRECTORY"
dpkg-deb --build statuspanel-service
mv statuspanel-service.deb "$BUILD_DIRECTORY/statuspanel-service-$VERSION.deb"

# TODO: Remove the image we've just created.
docker system prune --all --force
docker image prune --all --force
docker container ls
docker image ls
