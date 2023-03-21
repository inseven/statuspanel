#!/usr/bin/env python3

import argparse
import base64
import enum
import json
import io
import logging
import os
import signal
import struct
import subprocess
import sys
import threading
import time
import urllib.parse
import uuid

from dataclasses import dataclass

import inky
import pysodium
import qrcode
import requests
import RPi.GPIO as GPIO

from PIL import Image, ImageOps
from inky.auto import auto


verbose = '--verbose' in sys.argv[1:] or '-v' in sys.argv[1:]
logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO, format="[%(levelname)s] %(message)s")


SETTINGS_PATH = os.path.expanduser("~/.statuspanel")

PALETTE = {
    0: (0, 0, 0),
    1: (255, 255, 0),
    2: (255, 255, 255),
}


@dataclass
class Size:
    width: int
    height: int


@dataclass
class DisplayState:
    images: list
    index: int


class DeviceIdentifier(object):

    def __init__(self, id, public_key, secret_key):
        self.id = id
        self.public_key = public_key
        self.secret_key = secret_key

    @classmethod
    def generate(cls):
        public_key, secret_key = pysodium.crypto_box_keypair()
        return cls(id=str(uuid.uuid4()),
                   public_key=public_key,
                   secret_key=secret_key)

    @property
    def pairing_url(self):
        public_key = base64.b64encode(self.public_key)
        parameters = urllib.parse.urlencode({
            'id': self.id,
            'pk': public_key,
        })
        return "statuspanel:r2?" + parameters


DEVICE_SIZE = Size(640, 384)


class MissingUpdate(Exception):
    pass


class InvalidHeader(Exception):
    pass


class UnsupportedUpdate(Exception):
    pass


class State(enum.Enum):
    UNKNOWN = 0
    PAIRING = 1


class Button(enum.Enum):
    A = 5
    B = 6
    C = 16
    D = 24


class Service(object):

    def __init__(self, identifier):
        self.identifier = identifier

    @property
    def update_url(self):
        return "https://api.statuspanel.io/api/v3/status/" + self.identifier.id

    def get_status(self):
        logging.info("Fetching update '%s'...", self.update_url)
        response = requests.get(self.update_url)
        if response.status_code != 200:
            logging.warning("Failed to fetch update with status code '%s'.",
                            response.status_code)
            raise MissingUpdate()

        data = io.BytesIO(response.content)

        # Check for a valid update.
        if unpack(data, '>H')[0] != 0xFF00:
            raise InvalidHeader()

        # Ensure the header 'version' is high enough for the assumptions in our
        # implementation.
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

        # Read the index (given after the header), calculating the lengths as we
        # go.
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

        # Read the images.
        images = []
        for (offset, size) in offsets:
            assert(data.tell() == offset)
            image = data.read(size)
            contents = pysodium.crypto_box_seal_open(image,
                                                     self.identifier.public_key,
                                                     self.identifier.secret_key)

            # Unpack the RLE data.
            rle_data = io.BytesIO(contents)
            pixel_data = bytearray()
            try:
                while len(pixel_data) * 4 < DEVICE_SIZE.width * DEVICE_SIZE.height:
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
                rgb_data.append(PALETTE[(byte >> 0) & 3])
                rgb_data.append(PALETTE[(byte >> 2) & 3])
                rgb_data.append(PALETTE[(byte >> 4) & 3])
                rgb_data.append(PALETTE[(byte >> 6) & 3])

            images.append(rgb_data)

        return images


class Device(object):

    def __init__(self, identifier):
        self.identifier = identifier
        self.service = Service(identifier)

        self.state = State.UNKNOWN

        self._lock = threading.Lock()
        self._state = None  # Synchronized on _lock
        self._requested_state = None  # Synchronized on _lock

    @classmethod
    def load(cls, path):
        with open(path) as fh:
            settings = json.load(fh)
            id = settings["id"]
            public_key = base64.b64decode(settings["public_key"])
            secret_key = base64.b64decode(settings["secret_key"])
            identifier = DeviceIdentifier(id, public_key, secret_key)
            return cls(identifier=identifier)

    def save(self, path):
        with open(path, "w") as fh:
            json.dump({
                'id': self.identifier.id,
                'public_key': base64.b64encode(self.identifier.public_key).decode('utf-8'),
                'secret_key': base64.b64encode(self.identifier.secret_key).decode('utf-8'),
            }, fh)

    def toggle(self):
        with self._lock:
            # Toggle does nothing if we don't already have a state to work on.
            if self._requested_state is None:
                return
            index = (self._requested_state.index + 1) % len(self._requested_state.images)
            self._requested_state = DisplayState(self._requested_state.images, index)
            logging.info("Showing image %d...", self._requested_state.index)

    def show_setup_screen(self, display):
        if self.state == State.PAIRING:
            return
        self.state = State.PAIRING
        image = Image.new("RGB", display.resolution, (255, 255, 255))
        code = qrcode.make(self.identifier.pairing_url, box_size=4)
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
        images = self.service.get_status()

        with self._lock:
            index = 0 if self._requested_state is None else self._requested_state.index % len(images)
            self._requested_state = DisplayState(images, index)

        self.display_image_if_necessary(display)

    def display_image_if_necessary(self, display):
        """
        Updates the contents of the display if the requested draw state
        differs from the currently drawn state.
        """
        state = None
        with self._lock:
            if self._state == self._requested_state:
                logging.info("No update requested; ignoring...")
                return
            self._state = self._requested_state
            state = self._requested_state
        assert state is not None

        image = Image.new("RGB",
                          (DEVICE_SIZE.width, DEVICE_SIZE.height),
                          (255, 255, 255))
        image.putdata(state.images[state.index])
        panel_image = Image.new("RGB",
                                display.resolution,
                                (255, 255, 255))
        panel_image.paste(image, (0, 0))
        display.set_image(panel_image)
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
        device = Device(identifier=DeviceIdentifier.generate())
        device.save(SETTINGS_PATH)

    logging.info("Pairing URL: %s", device.identifier.pairing_url)
    display = auto(ask_user=True, verbose=True)

    # Set up the button callbacks.
    GPIO.setmode(GPIO.BCM)
    GPIO.setup([Button.A.value, Button.D.value],
               GPIO.IN,
               pull_up_down=GPIO.PUD_UP)

    def toggle(pin):
        # Select a different image and then schedule the redraw
        # by sending SIGUSR1.
        print("toggle")
        device.toggle()
        os.kill(os.getpid(), signal.SIGUSR1)

    def shutdown(pin):
        logging.info("Shutting down...")
        subprocess.check_call(["sudo", "systemctl", "poweroff"])

    GPIO.add_event_detect(Button.A.value,
                          GPIO.FALLING,
                          toggle,
                          bouncetime=250)
    GPIO.add_event_detect(Button.D.value,
                          GPIO.FALLING,
                          shutdown,
                          bouncetime=250)

    tasks = []

    def update():
        try:
            logging.info("Fetching update...")
            device.fetch_update(display)
            logging.info("Sleeping 30s...")
            signal.alarm(30)
        except MissingUpdate:
            device.show_setup_screen(display)
            logging.info("Sleeping 10s...")
            signal.alarm(10)
        except requests.exceptions.ConnectionError as e:
            logging.error("Failed to fetch update with error '%s'", e)
            device.show_error(display, "Connection Error")
            logging.info("Sleeping 10s...")
            signal.alarm(10)

    def redraw():
        device.display_image_if_necessary(display)

    def alarm(sig, frame):
        tasks.append(update)

    def user(sig, frame):
        tasks.append(redraw)

    def interrupt(sig, frame):
        exit()

    signal.signal(signal.SIGALRM, alarm)
    signal.signal(signal.SIGUSR1, user)
    signal.signal(signal.SIGINT, interrupt)

    tasks.append(update)

    while True:
        while True:
            try:
                tasks.pop(0)()
            except IndexError:
                break
        signal.pause()


if __name__ == "__main__":
    main()
