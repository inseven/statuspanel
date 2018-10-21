import os
import pytest
import shutil
import sys
import tempfile
import requests
import urllib

TESTS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVICE_DIR = os.path.dirname(TESTS_DIR)
ROOT_DIR = os.path.dirname(SERVICE_DIR)
IMAGES_DIR = os.path.join(ROOT_DIR, "images")


class Client(object):

    def __init__(self, base_url):
        self.base_url = base_url
        self.session = requests.Session()

    def get(self, url, *args, **kwargs):
        url = urllib.parse.urljoin(self.base_url, url)
        return self.session.get(url, allow_redirects=False, *args, **kwargs)

    def post(self, url, *args, **kwargs):
        url = urllib.parse.urljoin(self.base_url, url)
        return self.session.post(url, allow_redirects=False, *args, **kwargs)


@pytest.fixture
def client():
    return Client(os.environ["TEST_BASE_URL"])


def test_index(client):
    response = client.get('/')
    assert response.status_code == 200, "Fetching index succeeds"


# def test_api_v1_get_empty(client):
#     response = client.get('/api/v1')
#     assert response.status_code == 404, "Fetching missing upload fails"


def upload(client, url, path):
    image_path = os.path.join(IMAGES_DIR, "paisley.png")
    return client.post(url, files={'file': open(path, 'rb')})


def test_api_v1_put_get_success(client):
    image_path = os.path.join(IMAGES_DIR, "paisley.png")
    response = upload(client, '/api/v1', image_path)
    assert response.status_code == 200, "Upload succeeds"
    response = client.get('/api/v1')
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    with open(image_path, 'rb') as fh:
        assert response.content == fh.read(), "Downloaded file matches uploaded file"


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
    image_path = os.path.join(IMAGES_DIR, "paisley.png")
    response = upload(client, '/api/v2/bad', image_path)
    assert response.status_code == 400, "Upload fails"


def test_api_v2_put_get_success(client):
    url = '/api/v2/abcdefgh'
    image_path = os.path.join(IMAGES_DIR, "paisley.png")
    response = upload(client, url, image_path)
    assert response.status_code == 200, "Upload succeeds"
    response = client.get(url)
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    with open(image_path, 'rb') as fh:
        assert response.content == fh.read(), "Downloaded file matches uploaded file"


def test_api_v2_put_get_different_identifiers_fails(client):
    image_path = os.path.join(IMAGES_DIR, "paisley.png")
    response = upload(client, '/api/v2/abcdefgh', image_path)
    assert response.status_code == 200, "Upload succeeds"
    response = client.get('/api/v2/01234567')
    assert response.status_code == 404, "Getting the uploaded file succeeds"


def test_api_v2_put_get_multiple_success(client):
    url_1 = '/api/v2/abcdefgh'
    url_2 = '/api/v2/bcdefghi'
    image_path_1 = os.path.join(IMAGES_DIR, "paisley.png")
    image_path_2 = os.path.join(IMAGES_DIR, "red.png")

    response = upload(client, url_1, image_path_1)
    assert response.status_code == 200, "Upload succeeds"
    response = upload(client, url_2, image_path_2)
    assert response.status_code == 200, "Upload succeeds"

    response = client.get(url_1)
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    with open(image_path_1, 'rb') as fh:
        assert response.content == fh.read(), "Downloaded file matches uploaded file"

    response = client.get(url_2)
    assert response.status_code == 200, "Getting the uploaded file succeeds"
    with open(image_path_2, 'rb') as fh:
        assert response.content == fh.read(), "Downloaded file matches uploaded file"
