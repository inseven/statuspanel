#!/usr/bin/env python

import argparse
import glob
import os
import subprocess
import sys

MmuPageSize = 65536

def arg_auto_int(x):
    return int(x, 0)

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

    parser = argparse.ArgumentParser(description="Build LFS image compatible with a given target. The target's ROM "
        "must have already been built and be located in the build directory.")
    parser.add_argument("--target", "-t", choices=("esp32", "esp32s2", "esp32s3"), required=True,
        help="ROM image file format (required for parsing the ROM).")
    parser.add_argument("--max-size", "-m", type=arg_auto_int, help="Maximum LFS size, in bytes.")
    parser.add_argument("--build-dir", "-B", default="build", help="Build directory, if not specified defaults to "
        "'build'. Relative paths are assumed to be relative to the nodemcu-firmware directory.")

    args = parser.parse_args()

    build_dir = args.build_dir
    if not os.path.isabs(build_dir):
        firmware_dir = os.path.join(root_dir, "device", "nodemcu", "nodemcu-firmware")
        build_dir = os.path.normpath(os.path.join(firmware_dir, build_dir))

    sys.path += [ os.path.join(root_dir, "esptool") ]

    rom_file = os.path.join(build_dir, "nodemcu.bin")
    assert os.path.isfile(rom_file)

    addr = get_lfs_load_addr(args.target, rom_file)
    print("LFS load address should be 0x{:x}".format(addr))

    luac_cross = os.path.join(build_dir, "luac_cross", "luac.cross")
    lua_dir = os.path.join(root_dir, "device", "nodemcu", "src")
    lua_files = glob.glob(os.path.join(lua_dir, "*.lua"))
    lua_filenames = []
    for path in lua_files:
        lua_filenames.append(os.path.basename(path))
    lfs_tmp = os.path.join(build_dir, "lfs.tmp")
    lfs_img = os.path.join(build_dir, "lfs.img")
    # chdir to lua_dir here so we can pass lua filenames with no path, as the path info is stored in the debug info and
    # we don't want build machine file paths appearing in device stacktraces.
    subprocess.check_call([
        luac_cross,
        "-f",
        "-m", "0x{:x}".format(args.max_size),
        "-o", lfs_tmp
    ] + lua_filenames, cwd=lua_dir)

    # Aargh the -F option is bugged and only accepts a max of 32 chars so chdir to lfs_tmp's directory to be safe...
    subprocess.check_call([
        luac_cross,
        "-F", os.path.basename(lfs_tmp),
        "-a", "0x{:x}".format(addr),
        "-o", lfs_img
    ], cwd=os.path.dirname(lfs_tmp))
    print("Created " + lfs_img)

def get_drom_segment(image):
    for seg in image.segments:
        if seg.get_memory_type(image)[0] == "DROM":
            return seg
    raise RuntimeError("Failed to find DROM segment in image!")

def get_lfs_load_addr(target, rom_file):
    import esptool
    image = esptool.bin_image.LoadFirmwareImage(target, rom_file)
    seg = get_drom_segment(image)
    addr = ((seg.addr + len(seg.data) + MmuPageSize - 1) // MmuPageSize) * MmuPageSize
    return addr

if __name__ == "__main__":
    main()
