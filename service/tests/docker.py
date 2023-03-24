# Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
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
