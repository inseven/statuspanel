import functools
import logging
import os
import re

from flask import Flask, send_from_directory, request, redirect, abort, jsonify

import database

logging.info("Connecting to the database...")
db = database.Database()


app = Flask(__name__)
app.config['CONTENT_DIRECTORY'] = os.path.dirname(os.path.abspath(__file__))
app.config['UPLOADS_DIRECTORY'] = os.path.join(app.config['CONTENT_DIRECTORY'], "uploads")
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0

UPLOAD_FILENAME = "upload.jpg"


@app.route('/')
def homepage():
    return send_from_directory('static', 'index.html')


@app.route('/static/<path:path>')
def send_static(path):
    return send_from_directory('static', path)


@app.route('/api/v1', methods=['POST'])
def upload():
    try:
        if not os.path.exists(app.config['UPLOADS_DIRECTORY']):
            os.makedirs(app.config['UPLOADS_DIRECTORY'])
        file = request.files['file']
        file.save(os.path.join(app.config['UPLOADS_DIRECTORY'], UPLOAD_FILENAME))
    except Exception as e:
        abort(e)
    return jsonify({})


@app.route('/api/v1', methods=['GET'])
def download():
    abort(400)
    return send_from_directory(app.config['UPLOADS_DIRECTORY'], UPLOAD_FILENAME)


def check_identifier(identifier):
    if not re.match(r"^[0-9a-z]{8}$", identifier):
        abort(400)


@app.route('/api/v2/<identifier>', methods=['POST'])
def v2_upload(identifier):
    check_identifier(identifier)
    try:
        if not os.path.exists(app.config['UPLOADS_DIRECTORY']):
            os.makedirs(app.config['UPLOADS_DIRECTORY'])
        file = request.files['file']
        file.save(os.path.join(app.config['UPLOADS_DIRECTORY'], identifier))
    except Exception as e:
        abort(e)
    return jsonify({})


@app.route('/api/v2/<identifier>', methods=['GET'])
def v2_download(identifier):
    check_identifier(identifier)
    return send_from_directory(app.config['UPLOADS_DIRECTORY'], identifier)


if __name__ == '__main__':
    app.run(host='0.0.0.0')
