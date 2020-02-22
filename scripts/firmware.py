#!/usr/bin/env python3

import argparse
import subprocess


def main():
    parser = argparse.ArgumentParser(description="Convenience utility for managing the device firmware.")
    parser.add_argument("command", choices=["erase", "flash-firmware", "upload-scripts"], help="command to run")
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
                        "esp32/partitions_tomsci.bin"])
    elif options.command == "upload-scripts":
        print("Uploading Lua scripts...")
        subprocess.run(["python3", "../nodemcu-uploader/nodemcu-uploader.py",
                        "--port", "/dev/tty.SLAB_USBtoUART",
                        "--baud", "9600",
                        "--start_baud", "115200",
                        "upload",
                        "init.lua", "panel.lua", "network.lua", "rle.lua", "font.lua", "root.pem", "main.lua"])


if __name__ == "__main__":
    main()
