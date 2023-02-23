# Architecture

StatusPanel is designed with a simple modular architecture to make individual components easily replaceable, reducing the dependence on a single party to provide hosting and hopefully future proofing the devices.

There are three primary components in the StatusPanel architecture:

- Client (publishes updates; typically a cellphone)
- Service (pigeon-hole service)
- Device (renders updates; low power ESP32 eInk)

Unlike many centralised systems, the service has no access to any user data–it simply serves as an asynchronous message exchange mechanism for delivering end-to-end encrypted updates from client to device. Key exchange occurs when initially pairing a device with a client.

## Update Format

_Data is encoded in big endian / network endian unless otherwise stated._

Updates are structured as follows:

**Header**

| Field          | Type   | Available         | Note                                                         |
| -------------- | ------ | ----------------- | ------------------------------------------------------------ |
| `headerLength` | UInt8  | _Always_          | The header layout is expected to be append-only, meaning that the header length serves as a proxy for the data structure version. For example, `imageCount` is only available if `headerLength` is greater than 5.<br />It is safe to assume that `headerLength` will always greater than or equal to 5. |
| `wakeupTime`   | UInt16 | _Always_          | Given as the number of minutes after midnight in device localtime at which the device should be updated. |
| `imageCount`   | UInt8  | headerLength  > 5 | The number of distinct images in the update. By convention, clients currently expect two images: the first containing the most recent data to display, and the second containing a privacy image to display when in privacy mode. Future device updates might use update the 'privacy' button to toggle through the images leaving privacy policy to the client and allowing for more content images on smaller devices. |

**Index**

The index is only included if `imageCount` is present in the header. It contains `imageCount` little endian encoded UInt32 offsets of the different images in the update.

| Field                  | Type                   | Available        |
| ---------------------- | ---------------------- | ---------------- |
| `offset[0]`            | UInt32 (Little Endian) | headerLength > 5 |
| ...                    | ...                    | ...              |
| `offset[imageCount-1]` | UInt32 (Little Endian) |                  |

**Images**

_If `imageCount` is not present in the header, it should be assumed that a single image is present in the update, located immediately after the header (beginning at offset 6) and the length of the remaining update data (update length - 6)._

| Field                  | Type         | Available        |
| ---------------------- | ------------ | ---------------- |
| `offset[0]`            | Image Format | headerLength > 5 |
| ...                    | ...          | ...              |
| `offset[imageCount-1]` | Image Format |                  |



## Attack Vectors

- DoS (systematically overwriting update payloads)
- Sending too much data to clients / Bomb? / Decryption Bomb?
- Service Misuse