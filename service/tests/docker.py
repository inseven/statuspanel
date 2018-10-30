import logging
import subprocess


def run():
    logging.debug("Creating docker Postgres container...")
    subprocess.run(["docker", "run",
                    "--name", "statuspanel-postgres-test",
                    "-p", "5432:5432",
                    "-e", "POSTGRES_PASSWORD=0EFDA2E7-9700-4F06-ADCB-55D8E38A37DF",
                    "-d", "postgres"], stdout=subprocess.PIPE)


def stop():
    logging.debug("Stopping docker Postgres container...")
    subprocess.run(["docker", "stop", "statuspanel-postgres-test"], stdout=subprocess.PIPE)


def rm():
    logging.debug("Destroying docker Postgres container...")
    subprocess.run(["docker", "rm", "statuspanel-postgres-test"], stdout=subprocess.PIPE)


class PostgresContainer(object):

    def run(self):
        run()

    def stop(self):
        stop()
        rm()

    def __enter__(self):
        self.run()

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.stop()
