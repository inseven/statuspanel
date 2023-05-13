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

import contextlib
import datetime
import io
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
import unittest
import urllib

import dateutil.parser
import pytz
import requests


TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_DIR = os.path.dirname(TESTS_DIR)
WEB_SERVICE_DIR = os.path.join(SERVICE_DIR, "web", "src")
BUILD_DIR = os.path.join(SERVICE_DIR, "build")

sys.path.append(WEB_SERVICE_DIR)

import apns
import database


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


@contextlib.contextmanager
def chdir(path):
    pwd = os.getcwd()
    try:
        os.chdir(path)
        yield path
    except:
        os.chdir(pwd)


class TestAPI(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        if "USE_SYSTEM_SERVICE" in os.environ and os.environ["USE_SYSTEM_SERVICE"] == "1":
            return
        subprocess.check_call(["docker", "compose",
                               "-f", os.path.join(BUILD_DIR, "docker-compose.yaml"),
                               "-f", os.path.join(SERVICE_DIR, "docker-compose-test.yaml"),
                               "up", "-d"])
        time.sleep(1)

    @classmethod
    def tearDownClass(cls):
        if "USE_SYSTEM_SERVICE" in os.environ and os.environ["USE_SYSTEM_SERVICE"] == "1":
            return
        subprocess.check_call(["docker", "compose",
                               "-f", os.path.join(BUILD_DIR, "docker-compose.yaml"),
                               "-f", os.path.join(SERVICE_DIR, "docker-compose-test.yaml"),
                               "stop"])

    def setUp(self):
        self.client = RemoteClient(os.environ["TEST_BASE_URL"])

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

    def test_api_v2_lower_uuid_identifier_put_get_success(self):
        identifier = str(uuid.uuid4()).lower()
        url = '/api/v2/' + identifier
        data = os.urandom(307200)
        response = self._upload(url, data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data, "Downloaded file matches uploaded file")

    def test_api_v3_lower_uuid_identifier_put_get_success(self):
        identifier = str(uuid.uuid4()).lower()
        url = '/api/v3/status/' + identifier
        data = os.urandom(307200)
        response = self._upload(url, data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data, "Downloaded file matches uploaded file")

    def test_api_v2_upper_uuid_identifier_put_get_success(self):
        identifier = str(uuid.uuid4()).upper()
        url = '/api/v2/' + identifier
        data = os.urandom(307200)
        response = self._upload(url, data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data, "Downloaded file matches uploaded file")

    def test_api_v3_upper_uuid_identifier_put_get_success(self):
        identifier = str(uuid.uuid4()).upper()
        url = '/api/v3/status/' + identifier
        data = os.urandom(307200)
        response = self._upload(url, data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data, "Downloaded file matches uploaded file")

    def test_api_v3_case_insensitive_uuid_identifier_put_get_success(self):
        identifier = str(uuid.uuid4())
        data = os.urandom(307200)
        response = self._upload('/api/v3/status/' + identifier.upper(), data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get('/api/v3/status/' + identifier.lower())
        self.assertEqual(response.status_code, 200, "Getting the uploaded file succeeds")
        self.assertEqual(response.content, data, "Downloaded file matches uploaded file")

    def _test_put_get_last_modified(self, url):
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

    def test_api_v2_put_get_last_modified(self):
        self._test_put_get_last_modified('/api/v2/abcdefgh')

    def test_api_v3_put_get_last_modified(self):
        self._test_put_get_last_modified('/api/v3/status/abcdefgh')

    def _test_upload_large_file_fails(self, url):
        data = os.urandom((1024 * 1024) + 1)  # A little over 1MB
        response = self._upload(url, data)
        # TODO: Large uploads fail with 503 and 524 errors on staging and production #75
        #       https://github.com/jbmorley/statuspanel/issues/75
        self.assertTrue(response.status_code in [413, 524, 503, 520],
                        "Uploading large file encountered unexpected status (%s)" % response.status_code)

    def test_api_v2_upload_large_file_fails(self):
        self._test_upload_large_file_fails("/api/v2/bigfile1")

    def test_api_v3_upload_large_file_fails(self):
        self._test_upload_large_file_fails("/api/v3/status/bigfile1")

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

    def test_api_v2_get_cross_origin_header(self):
        url = '/api/v2/abcdefgh'
        data = os.urandom(307200)
        response = self._upload(url, data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get(url)
        self.assertEqual(response.headers["Access-Control-Allow-Origin"], "*")

    def test_api_v3_get_cross_origin_header(self):
        url = '/api/v3/status/abcdefgh'
        data = os.urandom(307200)
        response = self._upload(url, data)
        self.assertEqual(response.status_code, 200, "Upload succeeds")
        response = self.client.get(url)
        self.assertEqual(response.headers["Access-Control-Allow-Origin"], "*")

    def test_api_v3_post_device_no_sandbox_implicit(self):
        url = '/api/v3/device/'
        token = '2EDvBde5PThia/q/zS0aSWe4kbnhjEiE9C+q3ykf7cU='
        response = self.client.post(url, json={'token': token})
        self.assertEqual(response.status_code, 200, "Registering device succeeds")
        db = database.Database(readonly=True)
        self.assertTrue({"token": apns.encode_token(token), "use_sandbox": False} in db.get_devices())

    def test_api_v3_post_device_no_sandbox_explicit(self):
        url = '/api/v3/device/'
        token = '2EDvBde5PThia/q/zS0aSWe4kbnhjEiE9C+q3ykf7cU='
        response = self.client.post(url, json={'token': token, 'use_sandbox': False})
        self.assertEqual(response.status_code, 200, "Registering device succeeds")
        db = database.Database(readonly=True)
        self.assertTrue({"token": apns.encode_token(token), "use_sandbox": False} in db.get_devices())

    def test_api_v3_post_device_use_sandbox(self):
        url = '/api/v3/device/'
        token = '2EDvBde5PThia/q/zS0aSWe4kbnhjEiE9C+q3ykf7cU='
        response = self.client.post(url, json={'token': token, 'use_sandbox': True})
        self.assertEqual(response.status_code, 200, "Registering device succeeds")
        db = database.Database(readonly=True)
        self.assertTrue({"token": apns.encode_token(token), "use_sandbox": True} in db.get_devices())


if __name__ == "__main__":
    unittest.main()
