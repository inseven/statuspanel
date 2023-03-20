#!/usr/bin/env python3

import argparse
import logging
import os
import subprocess
import sys


verbose = '--verbose' in sys.argv[1:] or '-v' in sys.argv[1:]
logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO, format="[%(levelname)s] %(message)s")


DEVICE_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
USER = os.environ['USER']

UNIT_PATH = "/etc/systemd/system/statuspanel.service"

UNIT = f"""
[Unit]

Description=StatusPanel
After=network.target

[Service]
ExecStart=/usr/bin/python3 {DEVICE_DIRECTORY}/device.py
User={USER}

[Install]
WantedBy=multi-user.target
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose')
    options = parser.parse_args()

    # Write the unit file.
    logging.info("Creating unit file...")
    unit = UNIT.lstrip().encode("utf-8")
    subprocess.run(["sudo", "tee", UNIT_PATH],
                   input=unit,
                   check=True,
                   stdout=subprocess.PIPE)

    # Reload systemd.
    logging.info("Reloading daemon...")
    subprocess.check_call(["sudo", "systemctl", "daemon-reload"])

    # Enable and start the service.
    logging.info("Enabling and starting service...")
    subprocess.check_call(["sudo", "systemctl", "enable", "statuspanel.service"])
    subprocess.check_call(["sudo", "systemctl", "start", "statuspanel.service"])

    logging.info("Done.")


if __name__ == "__main__":
    main()

