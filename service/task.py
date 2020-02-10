#!/usr/bin/env python3

import argparse
import subprocess

import apns
import database


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
    tokens = db.get_devices()
    if tokens:
        print(f"Devices: {tokens}")
        client = apns.APNS()
        try:
            client.send_keepalive(device_tokens=tokens)
        except apns.BadTokens as e:
            for device_token in e.tokens:
                print(f"Cleaning up device '{device_token}'...")
                db.delete_device(token=device_token)


if __name__=="__main__":
    main()
