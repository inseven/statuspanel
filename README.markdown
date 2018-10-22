# Status Panel

## Service

### Heroku

There are two apps in the Heroku pipeline:

- statuspanel-staging -- auto-deploys master
- statuspanel-production -- manual deploy from staging

### Installing Dependencies

    brew install pipenv
    pipenv install

### Running Locally

    pipenv run heroku local

This is configured to use the staging Postgres instance. Ultimately, this should use a local Postgres instance, but in the short-term, it allows development.

### Tests

Unit tests:

    pipenv run python3 -m pytest -v service/tests/full

Integration tests:

	pipenv run python3 -m pytest -v service/tests/smoke
