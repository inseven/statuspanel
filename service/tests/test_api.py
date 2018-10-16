import os
import pytest
import shutil
import sys
import tempfile

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_DIR = os.path.dirname(TESTS_DIR)
ROOT_DIR = os.path.dirname(SERVICE_DIR)
IMAGES_DIR = os.path.join(ROOT_DIR, "images")

sys.path.append(SERVICE_DIR)

import app


@pytest.fixture
def client():
    app.app.config['UPLOADS_DIRECTORY'] = tempfile.mkdtemp()
    app.app.config['TESTING'] = True  # Disable error caching during request handling
    client = app.app.test_client()
    yield client
    shutil.rmtree(app.app.config['UPLOADS_DIRECTORY'])


def test_index(client):
    response = client.get('/')
    assert response.status_code == 200, "Fetching index succeeds"


def test_api_v1_get_empty(client):
    response = client.get('/api/v1')
    assert response.status_code == 404, "Fetching missing upload fails correctly"


def test_api_v1_put_get_success(client):
    image_path = os.path.join(IMAGES_DIR, "paisley.png")
    response = client.post('/api/v1',
                           content_type="multipart/form-data",
                           buffered=True,
                           follow_redirects=True,
                           data={
                               'file': (open(image_path, 'rb'), 'paisley.png')
                           })
    assert response.status_code == 200, "Upload succeeds"
    response = client.get('/api/v1')
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    with open(image_path, 'rb') as fh:
        assert response.data == fh.read(), "Downloaded file matches uploaded file"
