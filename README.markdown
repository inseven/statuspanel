# StatusPanel

## Getting Started

StatusPanel uses [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules), so before doing anything else, you'll need to do:

```bash
git submodule update --init
```

You'll also need to run this command if the submodules change.

## Components

StatusPanel comprises a number of different components:

- Device
- Service
- App

## Device


## Service

### Heroku

There are two apps in the Heroku pipeline:

- statuspanel-staging -- auto-deploys master
- statuspanel-production -- manual deploy from staging

### Installing Dependencies

    brew install pipenv
    pipenv install

N.B. Local instances are configured to use the staging Postgres instance. Ultimately, this should use a local Postgres instance, but in the short-term, it allows development.

### Running Locally

When running the service locally using the `heroku local` command, it uses the environment variables configured in `.env`. These are currently configured to use a local Postgres instance.

You can use the following command to create a suitably configured docker container for testing:

    docker run --name some-postgres -p 5432:5432 -e POSTGRES_PASSWORD=0EFDA2E7-9700-4F06-ADCB-55D8E38A37DF -d postgres

Once your docker container is running, you can run the local service as follows:

    pipenv run heroku local

### Tests

Local API tests make use of a named docker container (creating and deleting the container where appropriate), and the Flask test client:

    pipenv run python -m unittest discover --verbose --start-directory service/tests

Sometimes, it can be quite useful to run individual unit tests. This can be done as follows:

    pipenv run python service/tests/test_api.py --verbose TestAPI.test_index

Tests can also be run on the live environments by selecting the correct `.env` file. In this scenario, the Python `requests` client is used and tests are performed against the live databases.

It is encouraged to run the tests on staging prior to promoting to production.

Staging:

    PIPENV_DOTENV_LOCATION=.env.staging pipenv run python -m unittest discover --verbose --start-directory service/tests

Production:

    PIPENV_DOTENV_LOCATION=.env.production pipenv run python -m unittest discover --verbose --start-directory service/tests
