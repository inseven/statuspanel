#!/usr/bin/env python3

import subprocess

import apns
import database


db = database.Database()

# Delete any devices that haven't been seen in a month.
print("Purging stale devices...")
db.purge_stale_devices(max_age=60 * 60 * 24 * 30)

# Send the tokens.
print("Sending keepalive...")
tokens = db.get_devices()
if tokens:
    print(f"Devices: {tokens}")
    client = apns.APNS(use_sandbox=True)
    client.send_keepalive(device_tokens=tokens)
