# Service

The StatusPanel service provides two pieces of functionality:

- updates – the [iOS app](../ios/README.markdown) posts encrypted content updates that device fetches and displays on its next update
- background notifications – the service sends regular background push notifications to wake up the iOS app and ask it to publish updated content

## Infrastructure

StatusPanel is hosted using Docker behind an nginx reverse proxy. Deployment is performed using an Ansible playbook located in the 'ansible' directory.

The production service is hosted on a DigitalOcean droplet and backups are achieved by enabling droplet backups.

## Development

### Installing Dependencies

StatusPanel uses a shared script for installing and managing dependencies. Follow the instructions [here](/README.markdown#installing-dependencies).

### Running Locally

```bash
cd service
docker compose up --build
```

If you need to inspect the database, you can expose it with the overlay configuration file:

```
docker-compose -f docker-compose.yaml -f docker-compose-test.yaml up --build
```

The database will now be available at 'postgresql://hello_flask:hello_flask@localhost:5432/hello_flask_dev'.

### Testing APNS

When testing APNS, it can be useful to configure the environment variables required to communicate with the production instance of APNS. This can be done by running the following commands:

```bash
export APNS_TEAM_ID=S4WXAUZQEV
export APNS_BUNDLE_ID=uk.co.inseven.status-panel
export ANPS_KEY_ID=V5XKL2D8B9
export APNS_KEY=`cat apns.p8`
```

N.B. This assumes the APNS private key is in `apns.p8` and these commands are executed from the root directory.

### Tests

Install the Python dependencies:

```bash
cd service/tests
pipenv sync
```

The full test suite can be run as follows:

```bash
scripts/test-service.sh
```

Tests will automatically start and stop Docker.

Sometimes, it can be quite useful to run individual unit tests. This can be done as follows:

```bash
cd service/tests
pipenv run python test_api.py --verbose TestAPI.test_index
```

The necessary environment variables that tell the tests where to find the service and database are stored in 'service/tests/.env'

### Command-line

It can sometimes be useful to make requests directly from the command-line during development. `curl` can be useful for this. For example,

```bash
curl --header "Content-Type: application/json" \
     --request POST \
     --data '{"token":"123456789"}' \
     http://127.0.0.1:5000/api/v3/device/
```

