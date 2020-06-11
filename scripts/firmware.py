#!/usr/bin/env python3

import argparse
import logging
import os
import subprocess
import sys
import tempfile


DEFAULT_DEVICE = "/dev/cu.SLAB_USBtoUART"

# Support overriding defaults using environment variables.
try:
    DEFAULT_DEVICE = os.environ["STATUSPANEL_DEVICE"]
except KeyError:
    pass

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


def main():
    parser = argparse.ArgumentParser(description="Convenience utility for managing StatusPanel firmware.")
    parser.add_argument("--device", type=str, default=DEFAULT_DEVICE, help="USB serial device (defaults to %s)" % (DEFAULT_DEVICE, ))
    parser.add_argument("command", choices=["erase",
                                            "flash",
                                            "console",
                                            "configure-wifi"], help="command to run")
    options = parser.parse_args()

    check_access(options.device)

    if options.command == "erase":
        logging.info("Erasing device...")
        subprocess.run([ESPTOOL_PATH,
                        "--chip", "esp32",
                        "--port", options.device,
                        "--baud", "921600",
                        "--before", "default_reset",
                        "--after", "hard_reset",
                        "erase_flash"])
    elif options.command == "flash":
        logging.info("Flashing latest firmware...")
        run([ESPTOOL_PATH,
             "--chip", "esp32",
             "--port", options.device,
             "--baud", "921600",
             "--before", "default_reset",
             "--after", "hard_reset",
             "write_flash",
             "-z",
             "--flash_mode", "dio",
             "--flash_freq", "40m",
             "--flash_size", "detect",
             "0x1000",
             os.path.join(ESP32_DIRECTORY, "bootloader.bin"),
             "0x10000",
             os.path.join(ESP32_DIRECTORY, "NodeMCU.bin"),
             "0x8000",
             os.path.join(ESP32_DIRECTORY, "partitions.bin"),
             "0x190000",
             os.path.join(ESP32_DIRECTORY, "lfs.img")])
        logging.info("Uploading Lua scripts...")
        run([sys.executable,
             NODEMCU_UPLOADER_PATH,
             "--port", options.device,
             "--baud", "115200",
             "--start_baud", "115200",
             "upload",
             "%s:init.lua" % (os.path.join(NODEMCU_DIRECTORY, "init.lua"), ),
             "%s:root.pem" % (os.path.join(NODEMCU_DIRECTORY, "root.pem", ))])
    elif options.command == "console":
        logging.info("Connecting to device...")
        run(["minicom",
             "-D", options.device,
             "-b", "115200",
             "--capturefile", os.path.expanduser("console.log")])
    elif options.command == "configure-wifi":
        logging.info("Configuring Wi-Fi...")
        ssid = input('Network Name: ')
        pwd = input('Network Password: ')
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "script.txt")
            with open(path, "w") as fh:
                fh.write('sleep 1\n')
                fh.write('send \"wifi.sta.config({auto = false, ssid = \\\"%s\\\", pwd = \\\"%s\\\"}, true)\\n\"\n' % (ssid, pwd))
                fh.write('exit\n')
            subprocess.run(["minicom",
                            "-D", options.device,
                            "-b", "115200",
                            "--script", path])


if __name__ == "__main__":
    main()
