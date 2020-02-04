import datetime
import io
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import urllib

import dateutil.parser
import pytz
import requests

import docker
import path

sys.path.append(path.SERVICE_DIR)

import app


class DevelopmentClient(object):

    def __init__(self):
        self.container = docker.PostgresContainer()
        self.container.run()
        self.client = app.app.test_client()

    def get(self, url, *args, **kwargs):
        response = self.client.get(url, *args, **kwargs)
        response.content = response.data
        return response

    def post(self, url, *args, **kwargs):
        response = self.client.post(url, *args, **kwargs)
        response.content = response.data
        return response

    def upload(self, url, data):
        return self.post(url,
                         content_type="multipart/form-data",
                         buffered=True,
                         follow_redirects=False,
                         data={
                             'file': (io.BytesIO(data), "example.bin")
                         })

    def close(self):
        self.container.stop()


class RemoteClient(object):

    def __init__(self, base_url):
        self.base_url = base_url
        self.session = requests.Session()

    def get(self, url, *args, **kwargs):
        url = urllib.parse.urljoin(self.base_url, url)
        return self.session.get(url, allow_redirects=False, *args, **kwargs)

    def post(self, url, *args, **kwargs):
        url = urllib.parse.urljoin(self.base_url, url)
        return self.session.post(url, allow_redirects=False, *args, **kwargs)

    def upload(self, url, data):
        return self.post(url, files={'file': io.BytesIO(data)})

    def close(self):
        self.session.close()


class TestAPI(unittest.TestCase):

    def setUp(self):
        if "TEST_BASE_URL" in os.environ:
            self.client = RemoteClient(os.environ["TEST_BASE_URL"])
        else:
            self.client = DevelopmentClient()

    def tearDown(self):
        self.client.close()

    def test_index(self):
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200, "Fetching index succeeds")

    def _upload(self, url, data):
        return self.client.upload(url, data)

    def test_api_v2_get_no_identifier(self):
        response = self.client.get('/api/v2')
        self.assertEqual(response.status_code, 404, "Fetching missing identifier fails")

    def test_api_v2_get_missing_upload(self):
        response = self.client.get('/api/v2/01234567')
        self.assertEqual(response.status_code, 404, "Fetching missing upload fails")

    def test_api_v2_get_invalid_identifier(self):
        response = self.client.get('/api/v2/012345 7')
        self.assertEqual(response.status_code, 400, "Fetching invalid identifier fails")

    def test_api_v2_put_invalid_identifier_fails(self):
        data = os.urandom(307200)
        response = self._upload("/api/v2/bad", data)
        self.assertEqual(response.status_code, 400, "Upload fails")

    def test_api_v2_put_get_success(self):
        url = '/api/v2/abcdefgh'
        data = os.urandom(307200)
        response = self._upload(url, data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data, "Downloaded file matches uploaded file")

    def test_api_v2_put_get_different_identifiers_fails(self):
        data = os.urandom(307200)
        response = self._upload('/api/v2/abcdefgh', data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get('/api/v2/01234567')
        self.assertEqual(response.status_code, 404, "Getting the uploaded file succeeds")

    def test_api_v2_put_get_different_identifiers_fails(self):
        data = os.urandom(307200)
        response = self._upload('/api/v2/abcdefgh', data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get('/api/v2/01234567')
        self.assertEqual(response.status_code, 404, "Getting the uploaded file succeeds")

    def test_api_v2_put_get_multiple_success(self):
        url_1 = '/api/v2/abcdefgh'
        url_2 = '/api/v2/bcdefghi'
        data_1 = os.urandom(307200)
        data_2 = os.urandom(307200)

        response = self._upload(url_1, data_1)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self._upload(url_2, data_2)
        self.assertEqual(response.status_code, 200, "Upload succeeds")

        response = self.client.get(url_1)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data_1, "Downloaded file matches uploaded file")

        response = self.client.get(url_2)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data_2, "Downloaded file matches uploaded file")

    def test_api_v2_put_get_multiple_same_identifier_success(self):
        url = '/api/v2/abcdefgh'
        data_1 = os.urandom(207234)
        data_2 = os.urandom(307200)

        response = self._upload(url, data_1)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self._upload(url, data_2)
        self.assertEqual(response.status_code, 200, "Upload succeeds")

        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertNotEqual(response.content, data_1, "Downloaded file does not match first uploaded file")

        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data_2, "Downloaded file matches uploaded file")

    def test_api_v2_put_get_last_modified(self):
        url = '/api/v2/abcdefgh'
        data = os.urandom(307200)
        response = self._upload(url, data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data, "Downloaded file matches uploaded file")
        self.assertTrue('Last-Modified' in response.headers, "Last-Modified headers returned")
        last_modified_timestamp = dateutil.parser.parse(response.headers['Last-Modified']).timestamp()
        current_timestamp = datetime.datetime.utcnow().replace(tzinfo=pytz.utc).timestamp()
        self.assertTrue(abs(current_timestamp - last_modified_timestamp) < 60, "Last-Modified headers within 60s of now")

    def test_api_v2_upload_large_file_fails(self):
        data = os.urandom((1024 * 1024) + 1)  # A little over 1MB
        response = self._upload("/api/v2/bigfile1", data)
        self.assertEqual(response.status_code, 413, "Uploading large files fails")

    def _test_if_modified_since_header(self, url):
        data = os.urandom(307200)
        response = self._upload(url, data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, "Download succeeds")
        last_modified = response.headers['Last-Modified']

        response = self.client.get(url, headers={"If-Modified-Since": "Mon, 01 Jan 2001 00:00:00 GMT"})
        self.assertEqual(response.status_code, 200, "Downloads data modified after the date provided")

        response = self.client.get(url, headers={'If-Modified-Since': last_modified})
        self.assertEqual(response.status_code, 304, "Does not download data that has not changed")

    def test_api_v2_if_modified_since_header(self):
        self._test_if_modified_since_header('/api/v2/poiuytre')

    def test_api_v3_if_modified_since_header(self):
        self._test_if_modified_since_header('/api/v3/status/poiuytre')

    def test_api_v3_post_device(self):
        url = '/api/v3/device/'
        response = self.client.post(url, data={'token': '12345678'})
        self.assertEqual(response.status_code, 200, "Registering device succeeds")


if __name__ == "__main__":
    unittest.main()
