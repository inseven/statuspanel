#!/usr/bin/env python3

import argparse

import apns


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("token")
    options = parser.parse_args()

    client = apns.APNS(use_sandbox=True)
    client.send_keepalive(device_tokens=[options.token])


if __name__ == "__main__":
    main()
