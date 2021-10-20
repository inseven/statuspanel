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
import glob
import logging
import os
import subprocess
import sys
import tempfile
import time
import zipfile

import pick
import serial

import cli


SCRIPT_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
ROOT_DIRECTORY = os.path.dirname(SCRIPT_DIRECTORY)
NODEMCU_DIRECTORY = os.path.join(ROOT_DIRECTORY, "nodemcu")
ESP32_DIRECTORY = os.path.join(NODEMCU_DIRECTORY, "esp32")

ESPTOOL_PATH = os.path.join(ROOT_DIRECTORY, "esptool", "esptool.py")
NODEMCU_UPLOADER_PATH = os.path.join(ROOT_DIRECTORY, "nodemcu-uploader", "nodemcu-uploader.py")


verbose = '--verbose' in sys.argv[1:] or '-v' in sys.argv[1:]
logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO, format="[%(levelname)s] %(message)s")


def run(command):
    return subprocess.run(command)


def check_access(device):
    if os.access(device, os.R_OK | os.W_OK):
        return
    logging.info("Changing permissions on '%s'...", device)
    subprocess.check_call(["sudo", "chmod", "o+rw", device])


def get_device(options):
    device = None
    try:
        device = os.environ["STATUSPANEL_DEVICE"]
    except KeyError:
        pass
    if options.device is not None:
        device = options.device
    if device is None:
        device = pick.pick(glob.glob("/dev/cu.*"))[0]
    check_access(device)
    return device


def execute_lua(device, command):
    with serial.Serial(port=device, baudrate=115200, bytesize=8, parity='N') as ser:
        time.sleep(1)
        for line in command.strip().split("\n"):
            ser.write(('%s\n' % line).encode('utf-8'))
            print(ser.readline().decode('utf-8'))


class DeviceArgument(cli.Argument):

    def __init__(self):
        super().__init__("--device", help="USB serial device")


@cli.command("erase", help="erase device flash", arguments=[
    DeviceArgument(),
])
def command_erase(options):
    device = get_device(options)
    logging.info("Erasing device...")
    subprocess.run([ESPTOOL_PATH,
                    "--chip", "esp32",
                    "--port", device,
                    "--baud", "921600",
                    "--before", "default_reset",
                    "--after", "hard_reset",
                    "erase_flash"])

def flash_firmware(device, path):
    logging.info("Flashing firmware...")
    run([ESPTOOL_PATH,
         "--chip", "esp32",
         "--port", device,
         "--baud", "921600",
         "--before", "default_reset",
         "--after", "hard_reset",
         "write_flash",
         "-z",
         "--flash_mode", "dio",
         "--flash_freq", "40m",
         "--flash_size", "detect",
         "0x1000",
         os.path.join(path, "bootloader.bin"),
         "0x10000",
         os.path.join(path, "NodeMCU.bin"),
         "0x8000",
         os.path.join(path, "partitions.bin"),
         "0x190000",
         os.path.join(path, "lfs.img")])


@cli.command("flash", help="flash device firmware", arguments=[
    DeviceArgument(),
    cli.Argument("--path", help="firmware to use to flash the device (may be a directory or zip file)")
])
def command_flash(options):
    device = get_device(options)

    firmware_path = ESP32_DIRECTORY
    if options.path is not None:
        firmware_path = os.path.abspath(options.path)
    if os.path.isdir(firmware_path):
        flash_firmware(device, firmware_path)
    else:
        with tempfile.TemporaryDirectory() as directory:
            with zipfile.ZipFile(firmware_path) as zip:
                logging.info("Extracting zip...")
                zip.extractall(directory)
                flash_firmware(device, directory)


@cli.command("upload", help="upload the latest Lua scripts", arguments=[
    DeviceArgument(),
])
def command_upload(options):
    device = get_device(options)
    logging.info("Uploading Lua scripts...")
    run([sys.executable,
         NODEMCU_UPLOADER_PATH,
         "--port", device,
         "--baud", "115200",
         "--start_baud", "115200",
         "upload",
         "%s:init.lua" % (os.path.join(NODEMCU_DIRECTORY, "init.lua"), ),
         "%s:root.pem" % (os.path.join(NODEMCU_DIRECTORY, "root.pem", ))])


@cli.command("console", help="connect to the device console using minicom", arguments=[
    DeviceArgument(),
])
def command_console(options):
    device = get_device(options)
    logging.info("Connecting to device...")
    run(["minicom",
         "-D", device,
         "-b", "115200"])


@cli.command("configure-wifi", help="set device wifi details", arguments=[
    DeviceArgument(),
])
def command_configure_wifi(options):
    device = get_device(options)
    logging.info("Configuring Wi-Fi...")
    ssid = input('Network Name: ')
    pwd = input('Network Password: ')
    execute_lua(device, 'wifi.sta.config({auto = false, ssid = "%s", pwd = "%s"}, true)' % (ssid, pwd))


@cli.command("reset", help="reset device to factory settings", arguments=[
    DeviceArgument(),
])
def command_reset(options):
    device = get_device(options)
    execute_lua(device, """
file.remove("deviceid")
file.remove("sk")
wifi.sta.config({auto = false, ssid = "", pwd = ""}, true)
file.remove("last_modified")
""")


def main():
    verbose = '--verbose' in sys.argv[1:] or '-v' in sys.argv[1:]
    logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO, format="[%(levelname)s] %(message)s")
    parser = cli.CommandParser(description="Convenience utility for managing StatusPanel firmware.")
    parser.add_argument('--verbose', '-v', action='store_true', default=False, help="show verbose output")
    parser.run()


if __name__ == "__main__":
    main()
