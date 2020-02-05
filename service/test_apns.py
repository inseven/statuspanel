#!/usr/bin/env python3

import argparse

import apns


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("token")
    parser.add_argument("--use-sandbox", action='store_true', default=False)
    options = parser.parse_args()

    print(options.token)

    client = apns.APNS(use_sandbox=options.use_sandbox)
    client.send_keepalive(device_tokens=[options.token])


if __name__ == "__main__":
    main()
