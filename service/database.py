import os
import postgres


class Database(object):

    def __init__(self):
        self.db = postgres.Postgres(os.environ['DATABASE_URL'])
