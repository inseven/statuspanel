# Status Panel

## Service

### Heroku

There are two apps in the Heroku pipeline:

- statuspanel-staging
- statuspanel-production

### Running Locally

Install the dependencies:

    pipenv install

Run the service:

    pipenv run heroku local

This is configured to use the staging Postgres instance. Ultimately, this should use a local Postgres instance, but in the short-term, it allows development.

### Tests

Install the test dependencies:

    pip3 install -r service/tests/requirements.txt

Run the tests:

    python3 -m pytest -v service/tests/full

Run the integration tests:

	pipenv run python3 -m pytest -v service/tests/smoke
