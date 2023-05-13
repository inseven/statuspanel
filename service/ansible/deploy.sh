#!/bin/bash

set -e

ANSIBLE_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SERVICE_DIRECTORY="${ANSIBLE_DIRECTORY}/.."

SSH_KEY_FILE=ssh_key

PACKAGE_PATH=`realpath $1`

pushd "${ANSIBLE_DIRECTORY}"
#echo -e "$ANSIBLE_SSH_KEY" > $SSH_KEY_FILE
#chmod 0400 $SSH_KEY_FILE
ansible-playbook \
    -vv \
    -i hosts \
    statuspanel.yml \
    --extra-vars package_path="${PACKAGE_PATH}" \
    --extra-vars ansible_ssh_private_key_file="${SSH_KEY_FILE}" \
    --ask-become-pass
#rm -f "${SSH_KEY_FILE}"
popd
