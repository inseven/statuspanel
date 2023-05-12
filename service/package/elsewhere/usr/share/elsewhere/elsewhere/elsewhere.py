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
import atexit
import logging
import os
import re
import signal
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

import RPi.GPIO as GPIO
import gpiozero
import requests

from flask import Flask, escape, request, jsonify, send_from_directory

ROOT_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
ELSEWHERE_DIRECTORY = "/usr/share/elsewhere"
SPLASH_DIRECTORY = os.path.join(ELSEWHERE_DIRECTORY, "splash")
IMAGES_DIRECTORY = os.path.join(SPLASH_DIRECTORY, "images")
SPLASH_IMAGE_PATH = os.path.join(IMAGES_DIRECTORY, "elsewhere.png")
SHUTTING_DOWN_IMAGE_PATH = os.path.join(IMAGES_DIRECTORY, "shutting-down.png")
FIM_SCRIPT_PATH = os.path.join(SPLASH_DIRECTORY, "script.txt")
FONT_PATH = os.path.join(ELSEWHERE_DIRECTORY, "fonts/Inter/static/Inter-Thin.ttf")

logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(process)d] [%(levelname)s] %(message)s", datefmt='%Y-%m-%d %H:%M:%S %z')


def livestreamer(url):
    return subprocess.Popen(["streamlink", "--player", "cvlc --fullscreen --no-video-title-show", url, "best"])


app = Flask(__name__)


@app.after_request
def add_header(r):
    """
    Add headers to both force latest IE rendering engine or Chrome Frame,
    and also to cache the rendered page for 10 minutes.
    """
    r.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    r.headers["Pragma"] = "no-cache"
    r.headers["Expires"] = "0"
    r.headers['Cache-Control'] = 'public, max-age=0'
    return r


@app.route('/')
def hello():
    return send_from_directory(ROOT_DIRECTORY, 'index.html')


class Server(threading.Thread):

    def __init__(self, player, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.player = player
        def next():
            self.player.next()
            return jsonify({'url': self.player.url})
        def previous():
            self.player.previous()
            return jsonify({'url': self.player.url})
        def shutdown_action():
            shutdown()
            return jsonify({})
        def reboot_action():
            reboot()
            return jsonify({})
        app.add_url_rule('/api/v1/next', 'next', next)
        app.add_url_rule('/api/v1/previous', 'previous', previous)
        app.add_url_rule('/api/v1/shutdown', 'shutdown', shutdown_action)
        app.add_url_rule('/api/v1/reboot', 'reboot', reboot_action)

    def run(self):
        app.run(host='0.0.0.0')


class Streamer(threading.Thread):

    def __init__(self, url, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.url = url
        self.lock = threading.Lock()
        self._should_stop = False
        self.process = None

    def run(self):
        while True:
            process = None
            with self.lock:
                if self._should_stop:
                    return
                else:
                    # TODO: Rename to streamlink
                    process = livestreamer(self.url)
                    self.process = process
            process.wait()

    def stop(self):
        with self.lock:
            self._should_stop = True
            self.process.send_signal(signal.SIGINT)
            # self.process.kill()
        self.join()


def show_image(path):
    subprocess.check_call(["/usr/bin/fim", "--quiet", path, "--execute-script", FIM_SCRIPT_PATH])


def show_title(title):
    with tempfile.TemporaryDirectory() as directory:
        logging.info("Setting title to '%s'...", title)
        image_path = os.path.join(directory, "image.png")
        subprocess.check_call(["/usr/bin/convert",
                               "-background", "black",
                               "-fill", "white",
                               "-font", FONT_PATH,
                               "-size", "1024x768",
                               "-pointsize", "48",
                               "-gravity", "center",
                               "label:%s" % (title, ),
                               image_path])
        show_image(image_path)


class Player(object):

    def __init__(self, urls):
        self.streamer = None
        self.urls = urls
        self.index = 0

    def play(self):
        if self.streamer is not None:
            self.streamer.stop()
        url = self.url
        logging.info(f"Playing {url}...")
        title = self.title
        show_title(title)

        self.streamer = Streamer(url=url)
        self.streamer.setDaemon(True)
        self.streamer.start()

    def next(self):
        self.index = (self.index + 1) % len(self.urls)
        self.play()

    def previous(self):
        self.index = (self.index - 1) % len(self.urls)
        self.play()

    def cleanup(self):
        self.streamer.stop()

    @property
    def url(self):
        return self.urls[self.index][0]

    @property
    def title(self):
        details = self.urls[self.index]
        if len(details) > 1:
            return details[1]
        return ""


def setup_buttons(commands):
    buttons = []
    for pin, command in commands.items():
        button = gpiozero.Button(pin)
        button.when_pressed = command
        buttons.append(button)
    return buttons


def shutdown():
    # Signal the ATXRaspi (short button press).
    soft_button = 23
    GPIO.setup(soft_button, GPIO.OUT)
    GPIO.output(soft_button, GPIO.HIGH)
    time.sleep(0.4)
    GPIO.output(soft_button, GPIO.LOW)


def reboot():
    # Signal the ATXRaspi (long button press).
    soft_button = 23
    GPIO.setup(soft_button, GPIO.OUT)
    GPIO.output(soft_button, GPIO.HIGH)
    time.sleep(4.1)
    GPIO.output(soft_button, GPIO.LOW)


def main():
    parser = argparse.ArgumentParser(description="Livestream picture frame software.")
    parser.add_argument("streams", help="URL containing new-line separated livestream URLs")
    parser.add_argument("--no-gpio", action="store_true", default=False, help="disable GPIO for channel controls")
    options = parser.parse_args()

    show_image(SPLASH_IMAGE_PATH)
    GPIO.setmode(GPIO.BCM)

    content = None
    if os.path.exists(options.streams):
        with open(options.streams, "r") as fh:
            content = fh.read()
    else:
        response = requests.get(options.streams)
        content = response.text
    lines = [re.sub(r"(#.+)", "", line.strip()) for line in content.split("\n")]
    urls = [line.split(" ", 1) for line in lines if line]
    player = Player(urls=urls)
    if not options.no_gpio:
        logging.info("Setting up GPIO buttons...")
        buttons = setup_buttons({
            14: player.previous,
            15: player.next,
        })
    else:
        logging.info("Skipping GPIO button setup...")

    logging.info("Starting server...")
    server = Server(player=player)
    server.setDaemon(True)
    server.start()

    def kill(*args):
        player.cleanup()
        show_image(SHUTTING_DOWN_IMAGE_PATH)
        exit()

    signal.signal(signal.SIGINT, kill)
    signal.signal(signal.SIGTERM, kill)

    player.play()
    signal.pause()


if __name__ == "__main__":
    main()
