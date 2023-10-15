---
title: Architecture
---

# Architecture

StatusPanel is designed with a simple modular architecture to make individual components easily replaceable, reducing the dependence on a single party to provide hosting and hopefully future proofing the devices.

There are three primary components in the StatusPanel architecture:

- Client – publishes updates; typically a cellphone
- Service – pigeon-hole service; stores updates from clients for devices to pick up on their own schedule)
- Device – renders updates; lower-power network-attached display

Unlike many centralised systems, the service has no access to any user data–it simply serves as an asynchronous message exchange mechanism for delivering end-to-end encrypted updates from client to device. Key exchange occurs when initially pairing a device with a client.

## Device Registration

Device registration and key exchange (and optionally initial Wi-Fi configuration), is performed using a QR code. The QR code encodes a URL containing the device's public key and details and is of the format:

```
statuspanel:r2?id=<identifier>&pk=<public key>&t=<type>&s=<SSID>
```

This URL has a scheme of `statuspanel`, an empty host, and path of `r2`. The path refers to 'registration v2'.

### Query Parameters

| Parameter | Type                                         | Description                                                  | Required |
| --------- | -------------------------------------------- | ------------------------------------------------------------ | -------- |
| `id`      | Canonical UUID4                              | Identifier                                                   | Yes      |
| `pk`      | Base64 then URL encoded libsodium public key | Public Key                                                   | Yes      |
| `t`       | Int                                          | Type:<br />`0` – eInk Version 1<br />`1` – Feather TFT<br />`2` – Pimoroni Inky Impression 4 (using full colour PNG)<br />`3` – Pimoroni Inky Impression 4 (using 2BPP RLE) | Optional |
| `s`       | String                                       | SSID of ad-hoc Wi-Fi hotspot to connect to for initial configuration | Optional |

## Updates

```
GET https://api.statuspanel.io/api/v3/status/<device identifier>
```

Updates are returned as binary data with the following components

- Header – metadata about the image
- Index – offsets of the images in the data
- Images – update images themselves

### Header

| Field          | Type                   | Available            | Note                                                         |
| -------------- | ---------------------- | -------------------- | ------------------------------------------------------------ |
| `marker`       | Uint16 (Big Endian)    | Always               | 0xFF00                                                       |
| `headerLength` | UInt8                  | Always               | The header layout is expected to be append-only, meaning that the header length serves as a proxy for the data structure version. For example, `imageCount` is only available if `headerLength` is greater than 5.<br />It is safe to assume that `headerLength` will always greater than or equal to 5. |
| `wakeupTime`   | UInt16                 | Always               | Given as the number of minutes after midnight in device localtime at which the device should be updated. |
| `imageCount`   | UInt8                  | `headerLength` >= 5  | The number of distinct images in the update. By convention, clients currently expect two images: the first containing the most recent data to display, and the second containing a privacy image to display when in privacy mode. Future device updates might use update the 'privacy' button to toggle through the images leaving privacy policy to the client and allowing for more content images on smaller devices. |
| `flags`        | UInt16 (Little Endian) | `headerLength`  >= 8 | Bit-field specifying further attributes of the update:<br />`1` – Update uses PNG encoding |

#### Notes

- The current update format is not consistent in its use of endianness (e.g., `headerLength` is encoded in big endian, while `flags` are encoded in small endian). We plan to address this in a future update.
- To simplify update parsing, `flags` may be turned into a dedicated field describing the image encoding, with `0` indicating RLE, and `1` indicating PNG encoding.

### Index

The index is only included if `imageCount` is present in the header. It contains `imageCount` little endian encoded UInt32 offsets of the different images in the update.

| Field                  | Type                   | Available          |
| ---------------------- | ---------------------- | ------------------ |
| `offset[0]`            | UInt32 (Little Endian) | `headerLength` > 5 |
| ...                    | ...                    | ...                |
| `offset[imageCount-1]` | UInt32 (Little Endian) |                    |

### Images

Images are stored back-to-back, each starting at the offset defined in the index (or at offset 6 if `imageCount` is not present in the header).

Images are encrypted using a [libsodium sealed box](https://doc.libsodium.org/public-key_cryptography/sealed_boxes) using the device's public key that is provided to **client** at device registration time.

#### Encodings

##### RLE + 2BPP

```python
while let pixel = data.read() {
  if pixel == 255 {
    let count = data.read()
    let value = data.read()
    for _ in range(0, count) {
      yield value
    }
  } else {
    yield pixel
  }
}
```

Image values are as follows:

- `0` – black
- `1` – highlight color
- `2` – white

##### PNG

Raw data is encoded in PNG format.
