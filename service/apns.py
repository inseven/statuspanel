import base64
import binascii
import os

import gobiko.apns


def encode_token(token):
    return binascii.hexlify(base64.b64decode(token)).decode('ascii')


class APNS(object):

    def __init__(self, use_sandbox=False):
        self._client = gobiko.apns.APNsClient(
            team_id="S4WXAUZQEV",
            bundle_id="uk.co.inseven.status-panel",
            auth_key_id="V5XKL2D8B9",
            auth_key=os.environ['JWT_PRIVATE_KEY'],
            use_sandbox=use_sandbox,
        )

    def send_keepalive(self, device_tokens):
        self._client.send_bulk_message(
            device_tokens,
            "Amiga Forever",
            content_available=True,
        )
