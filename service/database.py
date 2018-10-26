import logging
import os
import postgres
import psycopg2


class Metadata(object):
    SCHEMA_VERSION = "schema_version"


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


def empty_migration(cursor):
    logging.info("Running empty migration...")


def create_image_table(cursor):
    cursor.execute("CREATE TABLE data (id text NOT NULL, data bytea NOT NULL, UNIQUE(id))")


def add_modified_date(cursor):
    cursor.execute("ALTER TABLE data ADD COLUMN modified_date date NOT NULL DEFAULT CURRENT_DATE")


class Database(object):

    SCHEMA_VERSION = 3

    # TODO: Ensure the migration structure is correct.
    MIGRATIONS = {
        1: empty_migration,
        2: create_image_table,
        3: add_modified_date
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
            logging.info("schema_version key already exists")

        self.migrate()

    def migrate(self):
        with Transaction(self.connection) as cursor:
            cursor.execute("SELECT value FROM metadata WHERE key=%s",
                           (Metadata.SCHEMA_VERSION, ))
            result = cursor.fetchone()
            schema_version = result[0]
            logging.info(f"Current schema at version {schema_version}")
            if schema_version >= self.SCHEMA_VERSION:
                return
            for i in range(schema_version + 1, self.SCHEMA_VERSION + 1):
                logging.info(f"Performing migration to version {i}...")
                self.MIGRATIONS[i](cursor)
            cursor.execute("UPDATE metadata SET value=%s WHERE key=%s",
                           (self.SCHEMA_VERSION, Metadata.SCHEMA_VERSION))
            logging.info(f"Updated schema to version {self.SCHEMA_VERSION}")

    def set_data(self, key, value):
        with Transaction(self.connection) as cursor:
            cursor.execute("SELECT COUNT(*) FROM data WHERE id = %s",
                           (key, ))
            result = cursor.fetchone()
            count = result[0]
            if count:
                cursor.execute("UPDATE data SET data = %s WHERE id = %s",
                               (psycopg2.Binary(value), key))
            else:
                cursor.execute("INSERT INTO data (id, data) VALUES (%s, %s)",
                               (key, psycopg2.Binary(value)))

    def get_data(self, key):
        with Transaction(self.connection) as cursor:
            cursor.execute("SELECT data FROM data WHERE id = %s",
                           (key, ))
            result = cursor.fetchone()
            if result is None:
                raise KeyError(f"No data for key '{key}'")
            return result[0].tobytes()

    def close(self):
        self.connection.close()
