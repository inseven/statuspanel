# Service

The StatusPanel service provides two pieces of functionality:

- updates – the [iOS app](../ios/README.markdown) posts encrypted content updates that device fetches and displays on its next update
- background notifications – the service sends regular background push notifications to wake up the iOS app and ask it to publish updated content

## Infrastructure

The StatusPanel service is currently hosted using [Heroku](https://heroku.com). There are two apps in the pipeline:

- [statuspanel-staging](https://staging.statuspanel.io) - auto-deploys master
- [statuspanel-production](https://api.statuspanel.io) - manual deploy from staging

The environments for these can be set up using the `configure-heroku-app`:

```bash
scripts/configure-heroku-app statuspanel-staging
```

## Development

### Installing Dependencies

Just like the other components of StatusPanel, you'll first want to install the dependencies:

```bash
git submodule update --init --recursive
scripts/install-dependencies.sh
```

### Running Locally

When running the service locally using the `heroku local` command, it uses the environment variables configured in `.env`. These are currently configured to use a local Postgres instance.

You can use the following command to create a suitably configured docker container for testing:

```bash
docker run \
    --name some-postgres \
    -p 5432:5432 \
    -e POSTGRES_PASSWORD=0EFDA2E7-9700-4F06-ADCB-55D8E38A37DF \
    -d postgres
```

Once your docker container is running, you can run the local service as follows:

```bash
pipenv run heroku local
```

### Testing APNS

When testing APNS, it can be useful to configure the environment variables required to communicate with the production instance of APNS. This can be done by running the following commands:

```bash
export APNS_TEAM_ID=S4WXAUZQEV
export APNS_BUNDLE_ID=uk.co.inseven.status-panel
export ANPS_KEY_ID=V5XKL2D8B9
export APNS_KEY=`cat apns.p8`
```

N.B. This assumes the APNS private key is in `apns.p8` and these commands are executed from the root directory.

If you wish to test notification deployment, you will also need to pass the database URL when running the APNS periodic command:

```bash
pipenv run python3 service/task.py --database-url <database_url>
```

### Tests

Install the Python dependencies:

```bash
pipenv install
```

Local API tests make use of a named docker container (creating and deleting the container where appropriate), and the Flask test client:

```bash
pipenv run python -m unittest discover --verbose --start-directory service/tests
```

Sometimes, it can be quite useful to run individual unit tests. This can be done as follows:

```bash
pipenv run python service/tests/test_api.py --verbose TestAPI.test_index
```

Tests can also be run on the live environments by selecting the correct `.env` file. In this scenario, the Python `requests` client is used and tests are performed against the live databases.

It is encouraged to run the tests on staging prior to promoting to production.

Staging:

```bash
PIPENV_DOTENV_LOCATION=.env.staging pipenv run \
    python -m unittest discover \
    --verbose \
    --start-directory service/tests
```

Production:

```bash
PIPENV_DOTENV_LOCATION=.env.production pipenv run \
    python -m unittest discover \
    --verbose \
    --start-directory service/tests
```

### Command-line

It can sometimes be useful to make requests directly from the command-line during development. `curl` can be useful for this. For example,

```bash
curl --header "Content-Type: application/json" \
     --request POST \
     --data '{"token":"123456789"}' \
     http://127.0.0.1:5000/api/v3/device/
```

