FROM python:3.10.7-slim-buster

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /tmp
RUN pip install --upgrade pip
COPY requirements.txt .
RUN pip install -r requirements.txt
