#!/usr/bin/env python3

# Copyright (c) 2018-2021 Jason Morley
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
import logging
import os
import subprocess
import sys
import time

import RPi.GPIO as GPIO

import jinja2

import cli


REBOOT_MINIMUM_DURATION = 0.2
REBOOT_MAXIMUM_DURATION = 2.0


verbose = '--verbose' in sys.argv[1:] or '-v' in sys.argv[1:]
logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO, format="[%(levelname)s] %(message)s")


def wait_for_low(channel, maximum_duration):
    start = time.time()
    while True:
        logging.info("Waiting for low...")
        time.sleep(0.1)
        duration = time.time() - start
        if not GPIO.input(channel) or duration > maximum_duration:
            return duration


@cli.command("monitor")
def command_monitor(options):

    boot_ok = 8
    shutdown = 7

    GPIO.setmode(GPIO.BCM)
    GPIO.setup(boot_ok, GPIO.OUT)
    GPIO.setup(shutdown, GPIO.IN)

    # Reset the board by toggling the the boot OK signal
    GPIO.output(boot_ok, GPIO.LOW)
    time.sleep(0.1)
    GPIO.output(boot_ok, GPIO.HIGH)

    while True:
        time.sleep(0.1)
        if GPIO.input(shutdown):
            logging.info("Received input...")
            duration = wait_for_low(shutdown, REBOOT_MAXIMUM_DURATION)
            if duration < REBOOT_MINIMUM_DURATION:
                logging.info("Ignoring unknown signal...")
                continue
            elif duration < REBOOT_MAXIMUM_DURATION:
                logging.info("Rebooting..")
                subprocess.check_call(["sudo", "reboot"])
                break
            else:
                logging.info("Shutting down...")
                subprocess.check_call(["sudo", "poweroff"])
                break

    # Note that we don't clean up the GPIO to ensure the boot OK signal remains high.


def main():
    parser = cli.CommandParser()
    parser.add_argument('--verbose', '-v', action='store_true', default=False, help="show verbose output")
    parser.run()


if __name__ == "__main__":
    main()
