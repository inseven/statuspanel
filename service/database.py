import logging
import os
import postgres
import psycopg2


class Metadata(object):
    SCHEMA_VERSION = "schema_version"


def empty_migration(cursor):
    logging.error("Running empty migration...")


class Transaction(object):

    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        self.cursor = self.connection.cursor()
        return self.cursor

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is None and exc_val is None and exc_tb is None:
            self.connection.commit()
        else:
            self.connection.rollback()
        self.cursor.close()


class Database(object):

    SCHEMA_VERSION = 1

    # TODO: Ensure the migration structure is correct.
    MIGRATIONS = {
        1: empty_migration
    }

    def __init__(self):
        self.connection = psycopg2.connect(os.environ['DATABASE_URL'])

        # Create the metadata table (used for versioning).
        with Transaction(self.connection) as cursor:
            cursor.execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT NOT NULL, value INT, UNIQUE(key))")

        # Create the initial version if necessary.
        try:
            with Transaction(self.connection) as cursor:
                cursor.execute("INSERT INTO metadata VALUES (%s, %s)",
                               (Metadata.SCHEMA_VERSION, 0))
        except psycopg2.IntegrityError:
            logging.error("schema_version key already exists")

        # Perform a migration if necessary.
        with Transaction(self.connection) as cursor:
            cursor.execute("SELECT value FROM metadata WHERE key=%s",
                           (Metadata.SCHEMA_VERSION, ))
            result = cursor.fetchone()
            schema_version = result[0]
            logging.error(f"Current schema at version {schema_version}")
            for i in range(schema_version + 1, self.SCHEMA_VERSION + 1):
                logging.error(f"Performing migration to version {i}...")
                self.MIGRATIONS[i](cursor)
            cursor.execute("UPDATE metadata SET value=%s WHERE key=%s",
                           (self.SCHEMA_VERSION, Metadata.SCHEMA_VERSION))
            logging.error(f"Updated schema to version {self.SCHEMA_VERSION}")

    def migrate(self):
        pass
