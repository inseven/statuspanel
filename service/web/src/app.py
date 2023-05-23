# Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
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

import atexit
import errno
import functools
import logging
import os
import re
import sys
import time

# Monkey patch collections to work around legacy behaviour in gobiko and dateutil.
import collections.abc
collections.Iterable = collections.abc.Iterable
collections.Mapping = collections.abc.Mapping
collections.MutableSet = collections.abc.MutableSet
collections.MutableMapping = collections.abc.MutableMapping

import psycopg2
import werkzeug

from apscheduler.schedulers.background import BackgroundScheduler
from flask import Flask, send_from_directory, request, redirect, abort, jsonify, g, make_response

import collections.abc
collections.Iterable = collections.abc.Iterable
collections.Mapping = collections.abc.Mapping
collections.MutableSet = collections.abc.MutableSet
collections.MutableMapping = collections.abc.MutableMapping

import apns
import database
import task

logging.basicConfig(level=logging.INFO,
                    format="[%(asctime)s] [%(process)d] [%(levelname)s] %(message)s",
                    datefmt='%Y-%m-%d %H:%M:%S %z')


SERVICE_DIRECTORY = os.path.dirname(os.path.abspath(__file__))
VERSION_PATH = os.path.join(SERVICE_DIRECTORY, "VERSION")

LEGACY_IDENTIFIER = "A0198E25-8436-4439-8BE1-75C445655255"


# Check that we can create an APNS instance before proceeding.
# This is somewhat inelegant, but serves as a way to double check that the necessary environment variables are defined.
# Long-term we probably want to start up one global instance of APNS and use this directly within the scheduler.
try:
    instance = apns.APNS()
    del instance
except Exception as e:
    logging.error("Failed to connect to APNS with error \(e)")
    sys.exit(errno.EINTR)


# Read the version.
METADATA = {
    "version": "Unknown"
}
if os.path.exists(VERSION_PATH):
    with open(VERSION_PATH) as fh:
        METADATA["version"] = fh.read().strip()

# Create the Flask app.
app = Flask(__name__)
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
app.config['MAX_CONTENT_LENGTH'] = 1024 * 1024

# Create a scheduler to run periodic tasks like database clean up and device notification.
scheduler = BackgroundScheduler()
scheduler.add_job(func=task.run_periodic_tasks, trigger="interval", seconds=60 * 60)  # Runs every hour.
scheduler.start()
atexit.register(lambda: scheduler.shutdown())


def get_database():
    if 'database' not in g:
        logging.info("Connecting to the database...")
        while True:
            try:
                g.database = database.Database()
                break
            except psycopg2.OperationalError:
                time.sleep(0.1)
    return g.database


@app.teardown_appcontext
def close_database(exception):
    db = g.pop('database', None)
    if db is not None:
        logging.info("Closing database connection...")
        db.close()


# Valid identifiers are either 8-character strings comprising 0-9 and a-z, or
# canonical UUID strings (hex digits structured as 8-4-4-4-12).
SHORT_IDENTIFIER_REGEX = re.compile(r"^[0-9a-z]{8}$")
UUID_IDENTIFIER_REGEX = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.IGNORECASE)


def check_identifier(fn):
    @functools.wraps(fn)
    def inner(*args, **kwargs):
        logging.info(f"Checking identifier '{kwargs['identifier']}'...")
        if SHORT_IDENTIFIER_REGEX.match(kwargs['identifier']):
            return fn(*args, **kwargs)
        elif UUID_IDENTIFIER_REGEX.match(kwargs['identifier']):
            kwargs['identifier'] = kwargs['identifier'].lower()
            return fn(*args, **kwargs)
        else:
            request.stream.read()
            return f"Invalid identifier '{kwargs['identifier']}'", 400
    return inner


@app.route('/')
def homepage():
    return send_from_directory('static', 'index.html')


@app.route('/api/v2/<identifier>', methods=['POST'])
@app.route('/api/v3/status/<identifier>', methods=['POST'])
@check_identifier
def upload(identifier):
    get_database().set_data(identifier, request.files['file'].read())
    return jsonify({})


@app.route('/api/v2/<identifier>', methods=['GET'])
@app.route('/api/v3/status/<identifier>', methods=['GET'])
@check_identifier
def download(identifier):
    try:
        data, last_modified = get_database().get_data(identifier)
        response = make_response(data)
        response.headers.set('Content-Type', 'application/octet-stream')
        response.headers.set("Access-Control-Allow-Origin", "*")
        response.last_modified = last_modified
        response.cache_control.max_age = 0
        response.make_conditional(request)
        return response
    except KeyError:
        abort(404)


@app.route('/api/v3/device/', methods=['POST'])
def device():
    logging.info(request)
    logging.info(request.get_json())

    # Store the token
    data = request.get_json()
    token = apns.encode_token(data["token"])
    get_database().register_device(token, use_sandbox=data["use_sandbox"] if "use_sandbox" in data else False)
    logging.info(get_database().get_devices())

    return jsonify(request.get_json())

@app.route('/api/v3/service/about', methods=['GET'])
def service_about():
    return jsonify(METADATA)

@app.route('/api/v3/service/status', methods=['GET'])
def service_status():
    return jsonify(get_database().status())


if __name__ == '__main__':
    app.run(host='0.0.0.0')
