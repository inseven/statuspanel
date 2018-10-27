# Status Panel

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

Unit tests:

    pipenv run python3 -m pytest -v service/tests/full

Live smoke tests; these are run against https://staging.statuspanel.io, and should be run before promoting to production:

    pipenv run python3 -m pytest -v service/tests/smoke

You can run the smoke tests on different environments by selecting the correct `.env` file. For example,

    PIPENV_DOTENV_LOCATION=.env.production pipenv run python3 -m pytest -v service/tests/smoke
