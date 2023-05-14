#!/bin/bash

# Copyright (c) 2021-2023 Jason Morley, Tom Sutcliffe
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

# This script expects to find the SSH key for the remote server in the ANSIBLE_SSH_KEY environment variable, and the
# become password in ANSIBLE_BECOME_PASS.

set -e

ANSIBLE_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SERVICE_DIRECTORY="${ANSIBLE_DIRECTORY}/.."

if [[ -z $ANSIBLE_SSH_KEY || -z $ANSIBLE_BECOME_PASS ]] ; then
    echo "This script expects to find the SSH key for the remote server in the ANSIBLE_SSH_KEY environment variable, and the become password in ANSIBLE_BECOME_PASS."
    exit 1
fi

SSH_KEY_FILE=ssh_key

PACKAGE_PATH=`realpath $1`

cd "${ANSIBLE_DIRECTORY}"

function cleanup {
    rm -f "${SSH_KEY_FILE}"
}

echo -e "$ANSIBLE_SSH_KEY" > $SSH_KEY_FILE
trap cleanup EXIT
chmod 0400 $SSH_KEY_FILE

ansible-playbook \
    -vv \
    -i hosts \
    statuspanel.yml \
    --extra-vars package_path="${PACKAGE_PATH}" \
    --extra-vars ansible_ssh_private_key_file="${SSH_KEY_FILE}" \
    --extra-vars ansible_become_pass='{{ lookup("env", "ANSIBLE_BECOME_PASS") }}'
