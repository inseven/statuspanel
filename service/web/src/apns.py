# Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
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

import base64
import binascii
import os

import gobiko.apns


def encode_token(token):
    return binascii.hexlify(base64.b64decode(token)).decode('ascii')


class BadTokens(Exception):

    def __init__(self, tokens):
        super(BadTokens, self).__init__()
        self.tokens = tokens


class APNS(object):

    def __init__(self, use_sandbox=False):
        self._client = gobiko.apns.APNsClient(
            team_id=os.environ['APNS_TEAM_ID'],
            bundle_id=os.environ['APNS_BUNDLE_ID'],
            auth_key_id=os.environ['APNS_KEY_ID'],
            auth_key=os.environ['APNS_KEY'],
            use_sandbox=use_sandbox,
        )

    def send_keepalive(self, device_tokens):
        bad_registration_ids = []
        bad_tokens = []
        try:
            self._client.send_bulk_message(
                device_tokens,
                "Amiga Forever",
                content_available=True,
            )
        except gobiko.apns.exceptions.PartialBulkMessage as e:
            # If we encounter an error, we attempt to send a message to each device individually
            # to provide greater visibility of the individual errors.
            bad_registration_ids = e.bad_registration_ids
            print(f"Failed to bulk send notifications to device tokens: {e.bad_registration_ids}")
        if bad_registration_ids:
            for device_token in bad_registration_ids:
                print(f"Trying to send message to '{device_token}'...")
                try:
                    self._client.send_message(
                        device_token,
                        "Amiga Forever",
                        content_available=True,
                    )
                    print("Success!")
                except (gobiko.apns.exceptions.BadDeviceToken, gobiko.apns.exceptions.Unregistered):
                    print(f"Failed to send notification to bad device token '{device_token}'.")
                    bad_tokens.append(device_token)
                except Exception as e:
                    print("Ignoring exception %s" % (e, ))
        if bad_tokens:
            raise BadTokens(tokens=bad_tokens)
