#!/bin/bash

set -e
set -o pipefail
set -x

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIRECTORY="${SCRIPT_DIRECTORY}/.."

IPHONE_DESTINATION="platform=iOS Simulator,name=iPhone 12 Pro,OS=14.4"

function build_scheme {
    xcodebuild \
        -project StatusPanel.xcodeproj \
        -scheme "$1" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO "${@:2}" | xcpretty
}

cd "$ROOT_DIRECTORY"

# List the available devices for future reference (predominantly for build servers)
xcrun instruments -s devices

build_scheme "StatusPanel" clean build \
  -sdk iphonesimulator \
  -destination "$IPHONE_DESTINATION"
