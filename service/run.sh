#!/bin/bash

docker compose up --build

# We're storing the Postgres data in a docker volume:
#
# docker volume create postgres_data
#
# This is explicitly named in our docker compose file and auto-mounted as part of the up process.
# This volume MUST be backed up.
#
# It looks like it's safe to call the create command multiple times; it seems to be idempotent.
#
# Build:
#
# docker compose build
#
# Run:
#
# docker compose up [--build]
#
# Run tests:
#
# TEST_BASE_URL=http://localhost:5000 ./scripts/test-service.sh
# TEST_BASE_URL=http://localhost:5000 DATABASE_URL=postgresql://hello_flask:hello_flask@localhost:5432/hello_flask_dev ./scripts/test-service.sh
#
# These tests require the Postgres ports to be exposed locally, which can be done with the docker-container-test.yaml
# overlay configuration.
#
# Questions:
# - Do I actually need an env file anymore? I guess I do if it's not to be committed into the source tree.
# - How are these environment settings deployed?
