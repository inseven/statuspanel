import os
import pytest
import shutil
import sys
import tempfile

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_DIR = os.path.dirname(TESTS_DIR)

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
    assert(response.status_code == 200, "Fetching index succeeds")


def test_api_v1_get_empty(client):
    response = client.get('/api/v1')
    print(response.status_code)
    assert(response.status_code == 200, "Fetching missing upload fails correctly")
