FROM ubuntu:20.04

RUN apt-get update
RUN DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata
RUN apt-get install -y --no-install-recommends wget unzip git make python3-serial srecord bc xz-utils gcc ccache vim-tiny python3-setuptools python3 python3-pip gperf python3-pip python3-dev flex bison build-essential libssl-dev libffi-dev libncurses5-dev libncursesw5-dev libreadline-dev zip

RUN ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /opt

RUN rm -rf /root
RUN ln -s /tmp /root

RUN apt-get clean && rm -rf /var/lib/apt/lists/*
