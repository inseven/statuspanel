import functools
import logging
import os
import re
import time

import psycopg2
import werkzeug

from flask import Flask, send_from_directory, request, redirect, abort, jsonify, g, make_response

import database

logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(process)d] [%(levelname)s] %(message)s", datefmt='%Y-%m-%d %H:%M:%S %z')


LEGACY_IDENTIFIER = "A0198E25-8436-4439-8BE1-75C445655255"


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


app = Flask(__name__)
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
app.config['MAX_CONTENT_LENGTH'] = 1024 * 1024


@app.teardown_appcontext
def close_database(exception):
    db = g.pop('database', None)
    if db is not None:
        logging.info("Closing database connection...")
        db.close()


def check_identifier(fn):
    @functools.wraps(fn)
    def inner(*args, **kwargs):
        logging.info(f"Checking identifier '{kwargs['identifier']}'...")
        if not re.match(r"^[0-9a-z]{8}$", kwargs['identifier']):
            request.stream.read()
            return f"Invalid identifier '{kwargs['identifier']}'", 400
        return fn(*args, **kwargs)
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
        response.last_modified = last_modified
        response.cache_control.max_age = 0
        response.make_conditional(request)
        return response
    except KeyError:
        abort(404)


@app.route('/api/v3/device/', methods=['POST'])
def device():
    logging.info(request.get_json())
    return jsonify(request.get_json())


if __name__ == '__main__':
    app.run(host='0.0.0.0')
