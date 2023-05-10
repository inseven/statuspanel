FROM python:3.10.7-slim-buster

WORKDIR /tmp
RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install -r requirements.txt

# Install and configure cron.
RUN apt-get update
RUN apt-get -y install cron
RUN crontab -l | { cat; echo "* * * * * bash -c 'echo Foo'"; } | crontab -
