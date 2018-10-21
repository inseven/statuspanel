import pytest
import sys

import docker
import path

sys.path.append(path.SERVICE_DIR)

import database


@pytest.fixture
def container():
    with docker.PostgresContainer() as container:
        yield container


def test_set_data(container):
    identifier = "cheese"
    with open(path.TEST_IMAGE_PATH, 'rb') as fh:
        contents = fh.read()
        db = database.Database()
        db.set_data(identifier, contents)


# TODO: Pass the database URL in for the docker instance.
def test_replace_data(container):
    identifier = "cheese"
    with open(path.TEST_IMAGE_PATH, 'rb') as fh:
        contents = fh.read()
        db = database.Database()
        db.set_data(identifier, contents)
        db.set_data(identifier, contents)
