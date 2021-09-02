# Copyright (c) 2018-2021 Jason Morley, Tom Sutcliffe
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import logging
import os
import psycopg2
import psycopg2.extras

SECONDS_PER_WEEK = 60 * 60 * 24 * 7


class Metadata(object):
    SCHEMA_VERSION = "schema_version"


class Transaction(object):

    def __init__(self, connection, **kwargs):
        self.connection = connection
        self.kwargs = kwargs

    def __enter__(self):
        self.cursor = self.connection.cursor(**self.kwargs)
        return self.cursor

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is None and exc_val is None and exc_tb is None:
            self.connection.commit()
        else:
            self.connection.rollback()
        self.cursor.close()


def empty_migration(cursor):
    pass


def create_image_table(cursor):
    cursor.execute("CREATE TABLE data (id text NOT NULL, data bytea NOT NULL, UNIQUE(id))")


def add_modified_date(cursor):
    cursor.execute("ALTER TABLE data ADD COLUMN modified_date date NOT NULL DEFAULT CURRENT_DATE")


def rename_modified_date_and_correct_default_value(cursor):
    cursor.execute("ALTER TABLE data DROP COLUMN modified_date")
    cursor.execute("ALTER TABLE data ADD COLUMN last_modified timestamptz NOT NULL DEFAULT current_timestamp")


def create_devices_table(cursor):
    cursor.execute("CREATE TABLE devices (id SERIAL NOT NULL, token text NOT NULL, last_modified timestamptz NOT NULL DEFAULT current_timestamp, UNIQUE(id), UNIQUE(token))")


def add_devices_use_sandbox(cursor):
    cursor.execute("ALTER TABLE devices ADD COLUMN use_sandbox boolean NOT NULL DEFAULT FALSE")


class Database(object):

    SCHEMA_VERSION = 11

    MIGRATIONS = {
        1:  empty_migration,
        2:  create_image_table,
        3:  add_modified_date,
        4:  empty_migration,
        5:  empty_migration,
        6:  empty_migration,
        7:  empty_migration,
        8:  empty_migration,
        9:  rename_modified_date_and_correct_default_value,
        10: create_devices_table,
        11: add_devices_use_sandbox,
    }

    def __init__(self, database_url=None, readonly=False):

        if database_url is None:
            database_url = os.environ['DATABASE_URL']

        self.connection = psycopg2.connect(database_url)
        self.connection.set_session(readonly=readonly)

        # Migrations are disabled on readonly connections.
        if readonly:
            return

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
                cursor.execute("UPDATE data SET data = %s, last_modified = current_timestamp WHERE id = %s",
                               (psycopg2.Binary(value), key))
            else:
                cursor.execute("INSERT INTO data (id, data, last_modified) VALUES (%s, %s, current_timestamp)",
                               (key, psycopg2.Binary(value)))

    def get_data(self, key):
        with Transaction(self.connection) as cursor:
            cursor.execute("SELECT data, last_modified FROM data WHERE id = %s",
                           (key, ))
            result = cursor.fetchone()
            if result is None:
                raise KeyError(f"No data for key '{key}'")
            return result[0].tobytes(), result[1]

    def purge_stale_data(self, max_age):
        with Transaction(self.connection) as cursor:
            cursor.execute("DELETE FROM data WHERE last_modified < current_timestamp - %s", (max_age, ))

    def register_device(self, token, use_sandbox=False):
        with Transaction(self.connection) as cursor:
            cursor.execute("SELECT COUNT(*) FROM devices WHERE token = %s",
                           (token, ))
            result = cursor.fetchone()
            count = result[0]
            if count:
                cursor.execute("UPDATE devices SET use_sandbox = %s, last_modified = current_timestamp WHERE token = %s",
                               (use_sandbox, token))
            else:
                cursor.execute("INSERT INTO devices (token, use_sandbox, last_modified) VALUES (%s, %s, current_timestamp)",
                               (token, use_sandbox))

    def get_devices(self):
        with Transaction(self.connection, cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
            cursor.execute("""SELECT token, use_sandbox
                                FROM devices""")
            results = cursor.fetchall()
            return results

    def purge_stale_devices(self, max_age):
        with Transaction(self.connection) as cursor:
            cursor.execute("DELETE FROM devices WHERE last_modified < current_timestamp - (%s||' seconds')::interval", (max_age, ))

    def delete_device(self, token):
        with Transaction(self.connection) as cursor:
            cursor.execute("DELETE FROM devices WHERE token = %s", (token, ))

    def close(self):
        self.connection.close()
