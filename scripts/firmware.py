#!/usr/bin/env python3

import argparse
import os
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description="Convenience utility for managing the device firmware.")
    parser.add_argument("command", choices=["erase",
                                            "flash-firmware",
                                            "upload-scripts",
                                            "console",
                                            "configure-wifi"], help="command to run")
    options = parser.parse_args()

    if options.command == "erase":
        print("Erasing device...")
        subprocess.run(["esptool.py",
                        "--chip", "esp32",
                        "--port", "/dev/cu.SLAB_USBtoUART",
                        "--baud", "921600",
                        "--before", "default_reset",
                        "--after", "hard_reset",
                        "erase_flash"])
    elif options.command == "flash-firmware":
        print("Flashing latest firmware...")
        subprocess.run(["esptool.py",
                        "--chip", "esp32",
                        "--port", "/dev/cu.SLAB_USBtoUART",
                        "--baud", "921600",
                        "--before", "default_reset",
                        "--after", "hard_reset",
                        "write_flash",
                        "-z",
                        "--flash_mode", "dio",
                        "--flash_freq", "40m",
                        "--flash_size", "detect",
                        "0x1000",
                        "esp32/bootloader.bin",
                        "0x10000",
                        "esp32/NodeMCU.bin",
                        "0x8000",
                        "esp32/partitions.bin",
                        "0x190000",
                        "esp32/lfs.img"])
    elif options.command == "upload-scripts":
        print("Uploading Lua scripts...")
        subprocess.run(["python3", "../nodemcu-uploader/nodemcu-uploader.py",
                        "--port", "/dev/tty.SLAB_USBtoUART",
                        "--baud", "115200",
                        "--start_baud", "115200",
                        "upload",
                        "bootstrap:init.lua", "root.pem"])
    elif options.command == "console":
        print("Connecting to device...")
        subprocess.run(["minicom",
                        "-D", "/dev/tty.SLAB_USBtoUART",
                        "-b", "115200",
                        "--capturefile", os.path.expanduser("~/Desktop/output.txt")])
    elif options.command == "configure-wifi":
        print("Configuring Wi-Fi...")
        ssid = input('Network Name: ')
        pwd = input('Network Password: ')
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "script.txt")
            with open(path, "w") as fh:
                fh.write('sleep 1\n')
                fh.write('send \"wifi.sta.config({auto = false, ssid = \\\"%s\\\", pwd = \\\"%s\\\"}, true)\\n\"\n' % (ssid, pwd))
                fh.write('exit\n')
            subprocess.run(["minicom",
                            "-D", "/dev/tty.SLAB_USBtoUART",
                            "-b", "115200",
                            "--script", path])


if __name__ == "__main__":
    main()
