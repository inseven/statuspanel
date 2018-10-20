import logging
import os
import postgres
import psycopg2


class Metadata(object):
    SCHEMA_VERSION = "schema_version"
    
    
def create_database(database):
    logging.info("Creating database...")


class Database(object):

    SCHEMA_VERSION = 1
    
    MIGRATIONS = {
        1: create_database
    }

    def __init__(self):
        self.db = postgres.Postgres(os.environ['DATABASE_URL'])
        
        # Create the metadata table (used for versioning).
        self.db.run("CREATE TABLE IF NOT EXISTS metadata (key TEXT NOT NULL, value INT, UNIQUE(key))")
        
        # Create the initial version if necessary.
        # If this statement fails, we can safely assume that there's already a version
        # present in the database.
        try:
            logging.info("Attempting to set initial schema_version...")
            self.set_metadata(Metadata.SCHEMA_VERSION, 0)
        except psycopg2.IntegrityError:
            logging.info("schema_version key already exists")
        
    def set_metadata(self, key, value):
        self.db.run("INSERT INTO metadata VALUES (%(key)s, %(value)d)", {"key": key, "value": value})

    def migrate(self):
        pass
