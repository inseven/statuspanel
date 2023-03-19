#!/usr/bin/env python3

import argparse
import base64
import enum
import json
import io
import logging
import os
import struct
import sys
import time
import urllib.parse
import uuid

import inky
import pysodium
import qrcode
import requests

from PIL import Image, ImageOps
from inky.auto import auto

verbose = '--verbose' in sys.argv[1:] or '-v' in sys.argv[1:]
logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO, format="[%(levelname)s] %(message)s")


SETTINGS_PATH = os.path.expanduser("~/.statuspanel")

COLORS = {
    0: (0, 0, 0, 255),
    1: (255, 255, 0, 255),
    2: (255, 255, 255, 255),
}


class MissingUpdate(Exception):
    pass


class InvalidHeader(Exception):
    pass


class UnsupportedUpdate(Exception):
    pass


class State(enum.Enum):
    UNKNOWN = 0
    PAIRING = 1


class Device(object):

    def __init__(self, id, public_key, secret_key):
        self.id = id
        self.public_key = public_key
        self.secret_key = secret_key
        self.state = State.UNKNOWN
        self.images = []

    @classmethod
    def load(cls, path):
        with open(path) as fh:
            settings = json.load(fh)
            id = settings["id"]
            public_key = base64.b64decode(settings["public_key"])
            secret_key = base64.b64decode(settings["secret_key"])
            return cls(id=id, public_key=public_key, secret_key=secret_key)

    def save(self, path):
        with open(path, "w") as fh:
            json.dump({
                'id': self.id,
                'public_key': base64.b64encode(self.public_key).decode('utf-8'),
                'secret_key': base64.b64encode(self.secret_key).decode('utf-8'),
            }, fh)

    @property
    def pairing_url(self):
        public_key = base64.b64encode(self.public_key)
        parameters = urllib.parse.urlencode({
            'id': self.id,
            'pk': public_key,
        })
        return "statuspanel:r2?" + parameters

    @property
    def update_url(self):
        return "https://api.statuspanel.io/api/v3/status/" + self.id

    def show_setup_screen(self, display):
        if self.state == State.PAIRING:
            return
        self.state = State.PAIRING
        image = Image.new("RGB", display.resolution, (255, 255, 255))
        code = qrcode.make(self.pairing_url, box_size=6)
        origin_x = int((image.size[0] - code.size[0]) / 2)
        origin_y = int((image.size[1] - code.size[1]) / 2)
        image.paste(code, (origin_x, origin_y))
        display.set_image(image)
        display.show()

    def show_error(self, display, message):
        image = Image.new("RGB", display.resolution, (255, 255, 255))
        image.paste((255, 0, 255), (0, 0, image.size[0], image.size[1]))
        display.set_image(image)
        display.show()        

    def fetch_update(self, display):
        logging.info("Fetching update '%s'...", self.update_url)
        response = requests.get(self.update_url)
        if response.status_code != 200:
            logging.warning("Failed to fetch update with status code '%s'.", response.status_code)
            raise MissingUpdate()
        
        data = io.BytesIO(response.content)

        # Check for a valid update.
        if unpack(data, '>H')[0] != 0xFF00:
            raise InvalidHeader()

        # Ensure the header 'version' is high enough for the assumptions in our implementation.
        headerLength = unpack(data, '>B')[0]
        logging.debug("Header Length: %d", headerLength)
        if headerLength < 6:
            raise UnsupportedUpdate()

        wakeupTime = unpack(data, '>H')[0]
        logging.debug("Wakeup Time: %d", wakeupTime)

        imageCount = unpack(data, '>B')[0]
        logging.debug("Image Count: %d", imageCount)

        # Seek to the end of the header.
        data.seek(headerLength)

        # Read the index (given after the header), calculating the lengths as we go.
        offsets = []
        start = None
        for _ in range(0, imageCount):
            offset = unpack(data, '<I')[0]
            if start is not None:
                offsets.append((start, offset - start))
            start = offset
        if start is not None:
            offsets.append((start, -1))
        logging.debug("Offsets: %s", offsets)

        # Original dimensions
        (width, height) = (640, 384)

        # Read the images.
        images = []
        for (offset, size) in offsets:
            assert(data.tell() == offset)
            image = data.read(size)
            contents = pysodium.crypto_box_seal_open(image, self.public_key, self.secret_key)

            # Unpack the RLE data.
            rle_data = io.BytesIO(contents)
            pixel_data = bytearray()
            try:
                while len(pixel_data) * 4 < width * height:
                    pixel = unpack(rle_data, 'B')[0]
                    if pixel == 255:
                        count = unpack(rle_data, 'B')[0]
                        value = unpack(rle_data, 'B')[0]
                        for _ in range(0, count):
                            pixel_data.append(value)
                    else:
                        pixel_data.append(pixel)
            except Exception as e:
                # TODO: Make this more specific.
                pass

            # Convert the 2BPP representation to 8BPP RGB.
            rgb_data = []
            for byte in pixel_data:
                rgb_data.append(COLORS[(byte >> 0) & 3])
                rgb_data.append(COLORS[(byte >> 2) & 3])
                rgb_data.append(COLORS[(byte >> 4) & 3])
                rgb_data.append(COLORS[(byte >> 6) & 3])

            images.append(rgb_data)

        if self.images == images:
            logging.info("No changes; ignoring update...")
            return

        logging.info("Contents updated; drawing...")
        self.images = images

        hack_image = Image.new("RGBA", (width, height), (255, 255, 255, 255))
        hack_image.putdata(images[0])
        
        
        image = Image.new("RGBA", display.resolution, (255, 255, 255, 255))
        image.paste(hack_image, (0, 0))
        display.set_image(image.convert("RGB"))  # TODO: Probably unnecessary
        display.show()


# https://stackoverflow.com/questions/17537071/idiomatic-way-to-struct-unpack-from-bytesio
def unpack(stream, fmt):
    size = struct.calcsize(fmt)
    buf = stream.read(size)
    return struct.unpack(fmt, buf)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose', action="store_true")
    options = parser.parse_args()

    try:
        device = Device.load(SETTINGS_PATH)
    except Exception as e:
        logging.error(e)
        public_key, secret_key = pysodium.crypto_box_keypair()
        device = Device(id=str(uuid.uuid4()), public_key=public_key, secret_key=secret_key)
        device.save(SETTINGS_PATH)

    logging.info("Pairing URL: %s", device.pairing_url)
    display = auto(ask_user=True, verbose=True)

    while True:
        try:
            logging.info("Fetching update...")
            device.fetch_update(display)
            logging.info("Sleeping 30s...")
            time.sleep(30)
        except MissingUpdate:
            device.show_setup_screen(display)
            logging.info("Sleeping 10s...")
            time.sleep(10)
        except requests.exceptions.ConnectionError as e:
            logging.error("Failed to fetch update with error '%s'", e)
            device.show_error(display, "Connection Error")
            logging.info("Sleeping 10s...")
            time.sleep(10)

    
if __name__ == "__main__":
    main()
