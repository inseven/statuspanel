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

SCRIPTS_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIRECTORY="${SCRIPTS_DIRECTORY}/.."
CHANGES_DIRECTORY="${SCRIPTS_DIRECTORY}/changes"
BUILD_TOOLS_DIRECTORY="${SCRIPTS_DIRECTORY}/build-tools"
NODEMCU_DIRECTORY="${ROOT_DIRECTORY}/nodemcu"
SIMULATOR_WEB_DIRECTORY="${ROOT_DIRECTORY}/simulator/web"

ENVIRONMENT_PATH="${SCRIPTS_DIRECTORY}/environment.sh"

source "$ENVIRONMENT_PATH"

# Install the Python dependencies
pip3 install --user pipenv
# PIPENV_PIPFILE="$ROOT_DIRECTORY/Pipfile" pipenv sync
PIPENV_PIPFILE="$CHANGES_DIRECTORY/Pipfile" pipenv install
PIPENV_PIPFILE="$BUILD_TOOLS_DIRECTORY/Pipfile" pipenv sync
PIPENV_PIPFILE="$NODEMCU_DIRECTORY/Pipfile" pipenv sync

# Install the JavaScript dependencies
cd "$SIMULATOR_WEB_DIRECTORY"
npm install
