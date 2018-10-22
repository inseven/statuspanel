# Status Panel

## Service

### Heroku

There are two apps in the Heroku pipeline:

- statuspanel-staging -- auto-deploys master
- statuspanel-production -- manual deploy from staging

### Running Locally

Install the dependencies:

    brew install pipenv
    pipenv install

Run the service:

    pipenv run heroku local

This is configured to use the staging Postgres instance. Ultimately, this should use a local Postgres instance, but in the short-term, it allows development.

### Tests

Install the test dependencies:

    brew install pipenv
    pipenv install

Run the tests:

    pipenv run python3 -m pytest -v service/tests/full

Run the integration tests:

	pipenv run python3 -m pytest -v service/tests/smoke
