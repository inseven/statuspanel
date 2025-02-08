#!/bin/bash

# Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
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

SCRIPTS_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="${SCRIPTS_DIRECTORY}/.."
WEBSITE_DIRECTORY="${ROOT_DIRECTORY}/docs"
WEBSITE_SIMULATOR_DIRECTORY="${ROOT_DIRECTORY}/docs/simulator"
SIMULATOR_WEB_DIRECTORY="${ROOT_DIRECTORY}/simulator/web"

SIMULATOR_INDEX_TEMPLATE_PATH="${SCRIPTS_DIRECTORY}/simulator-template.md"

# Clean up any previous builds.
if [ -d "${WEBSITE_SIMULATOR_DIRECTORY}" ]; then
    rm -r "${WEBSITE_SIMULATOR_DIRECTORY}"
fi

# Build the simulator.
cd "$SIMULATOR_WEB_DIRECTORY"
npm run build
mkdir -p "${WEBSITE_SIMULATOR_DIRECTORY}"

# Copy the build output.
cp -R dist/assets "${WEBSITE_SIMULATOR_DIRECTORY}"

# Generate the index page.
pushd dist/assets
INDEX_FILENAME=`ls index*.js` envsubst < "${SIMULATOR_INDEX_TEMPLATE_PATH}" > "${WEBSITE_SIMULATOR_DIRECTORY}/index.md"
popd
