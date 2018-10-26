import functools
import logging
import os
import psycopg2
import re
import time

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


@app.teardown_appcontext
def close_database(exception):
    db = g.pop('database', None)
    if db is not None:
        db.close()


def _check_identifier(identifier):
    if not re.match(r"^[0-9a-z]{8}$", identifier):
        abort(400)


def _upload(identifier):
    get_database().set_data(identifier, request.files['file'].read())
    return jsonify({})


def _download(identifier):
    try:
        response = make_response(get_database().get_data(identifier))
        response.headers.set('Content-Type', 'application/octet-stream')
        return response
    except KeyError:
        abort(404)


@app.route('/')
def homepage():
    return send_from_directory('static', 'index.html')


@app.route('/api/v1', methods=['POST'])
def v1_upload():
    return _upload(LEGACY_IDENTIFIER)


@app.route('/api/v1', methods=['GET'])
def v1_download():
    return _download(LEGACY_IDENTIFIER)


@app.route('/api/v2/<identifier>', methods=['POST'])
def v2_upload(identifier):
    _check_identifier(identifier)
    return _upload(identifier)


@app.route('/api/v2/<identifier>', methods=['GET'])
def v2_download(identifier):
    _check_identifier(identifier)
    return _download(identifier)


if __name__ == '__main__':
    app.run(host='0.0.0.0')
