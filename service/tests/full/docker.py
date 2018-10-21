import logging
import subprocess


def run():
    logging.info("Creating docker Postgres container...")
    subprocess.run(["docker", "run",
                    "--name", "statuspanel-postgres-test",
                    "-p", "5432:5432",
                    "-e", "POSTGRES_PASSWORD=0EFDA2E7-9700-4F06-ADCB-55D8E38A37DF",
                    "-d", "postgres"])


def stop():
    logging.info("Stopping docker Postgres container...")
    subprocess.run(["docker", "stop", "statuspanel-postgres-test"])


def rm():
    logging.info("Destroying docker Postgres container...")
    subprocess.run(["docker", "rm", "statuspanel-postgres-test"])


class PostgresContainer(object):

    def __enter__(self):
        run()

    def __exit__(self, exc_type, exc_val, exc_tb):
        stop()
        rm()
