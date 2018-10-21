import io
import os
import pytest
import shutil
import subprocess
import sys
import tempfile

import docker
import path

sys.path.append(path.SERVICE_DIR)

import app


@pytest.fixture
def client():
    app.app.config['TESTING'] = True  # Disable error caching during request handling
    with docker.PostgresContainer():
        yield app.app.test_client()


def test_index(client):
    response = client.get('/')
    assert response.status_code == 200, "Fetching index succeeds"


def test_api_v1_get_empty(client):
    response = client.get('/api/v1')
    assert response.status_code == 404, "Fetching missing upload fails"


def upload(client, url, data):
    return client.post(url,
                       content_type="multipart/form-data",
                       buffered=True,
                       follow_redirects=False,
                       data={
                           'file': (io.BytesIO(data), "example.bin")
                       })


def test_api_v1_put_get_success(client):
    data = os.urandom(307200)
    response = upload(client, '/api/v1', data)
    assert response.status_code == 200, "Upload succeeds"
    response = client.get('/api/v1')
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    assert response.data == data, "Downloaded file matches uploaded file"


def test_api_v2_get_no_identifier(client):
    response = client.get('/api/v2')
    assert response.status_code == 404, "Fetching missing identifier fails"


def test_api_v2_get_missing_upload(client):
    response = client.get('/api/v2/01234567')
    assert response.status_code == 404, "Fetching missing upload fails"


def test_api_v2_get_invalid_identifier(client):
    response = client.get('/api/v2/012345 7')
    assert response.status_code == 400, "Fetching invalid identifier fails"


def test_api_v2_put_invalid_identifier_fails(client):
    data = os.urandom(307200)
    response = upload(client, '/api/v2/bad', data)
    assert response.status_code == 400, "Upload fails"


def test_api_v2_put_get_success(client):
    url = '/api/v2/abcdefgh'
    data = os.urandom(307200)
    response = upload(client, url, data)
    assert response.status_code == 200, "Upload succeeds"
    response = client.get(url)
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    assert response.data == data, "Downloaded file matches uploaded file"


def test_api_v2_put_get_different_identifiers_fails(client):
    data = os.urandom(307200)
    response = upload(client, '/api/v2/abcdefgh', data)
    assert response.status_code == 200, "Upload succeeds"
    response = client.get('/api/v2/01234567')
    assert response.status_code == 404, "Getting the uploaded file succeeds"


def test_api_v2_put_get_multiple_success(client):
    url_1 = '/api/v2/abcdefgh'
    url_2 = '/api/v2/bcdefghi'
    data_1 = os.urandom(307200)
    data_2 = os.urandom(307200)

    response = upload(client, url_1, data_1)
    assert response.status_code == 200, "Upload succeeds"
    response = upload(client, url_2, data_2)
    assert response.status_code == 200, "Upload succeeds"

    response = client.get(url_1)
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    assert response.data == data_1, "Downloaded file matches uploaded file"

    response = client.get(url_2)
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    assert response.data == data_2, "Downloaded file matches uploaded file"


def test_api_v2_put_get_multiple_same_identifier_success(client):
    url = '/api/v2/abcdefgh'
    data_1 = os.urandom(207234)
    data_2 = os.urandom(307200)

    response = upload(client, url, data_1)
    assert response.status_code == 200, "Upload succeeds"
    response = upload(client, url, data_2)
    assert response.status_code == 200, "Upload succeeds"

    response = client.get(url)
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    assert response.data != data_1, "Downloaded file matches uploaded file"

    response = client.get(url)
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    assert response.data == data_2, "Downloaded file matches uploaded file"
