#!/usr/bin/env python3

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

import argparse
import subprocess

import apns
import database


def send_keepalive(db, use_sandbox, tokens):
    if tokens:
        print(f"Devices: {tokens}")
        client = apns.APNS(use_sandbox=use_sandbox)
        try:
            client.send_keepalive(device_tokens=tokens)
        except apns.BadTokens as e:
            for device_token in e.tokens:
                print(f"Cleaning up device '{device_token}'...")
                db.delete_device(token=device_token)


def main():
    parser = argparse.ArgumentParser(description="Periodic task for StatusPanel.")
    parser.add_argument('--database-url', default=None, help="use alternative database URL; the DATABASE_URL environment variable will be used otherwise")
    options = parser.parse_args()

    # Connect to the database.
    db = database.Database(database_url=options.database_url)

    # Delete any devices that haven't been seen in a month.
    print("Purging stale devices...")
    db.purge_stale_devices(max_age=60 * 60 * 24 * 30)

    # Send the tokens.
    print("Sending keepalive...")
    devices = db.get_devices()

    print("Sending sandbox tokens...")
    send_keepalive(db, use_sandbox=True, tokens=[device["token"] for device in devices if device["use_sandbox"]])

    print("Sending tokens...")
    send_keepalive(db, use_sandbox=False, tokens=[device["token"] for device in devices if not device["use_sandbox"]])


if __name__=="__main__":
    main()
