# iOS App

The iOS app handles all the heavy lifting of StatusPanel; it's responsible for connecting to your calendar and renders the content to be displayed on the device. This allows us to take advantage of the existing comprehensive graphics libraries of iOS (and hopefully Android in the future), keeping the device and service as simple as possible.

## Development

### Installing dependencies

StatusPanel uses a shared script for installing and managing dependencies. You can find details of this [here](/README.markdown#installing-dependencies).

### Configuration

API keys for data sources (TfL, National Rail, ... etc) are stored in a separate JSON configuration file so we can keep them out of the GitHub repository to reduce the risk of casual abuse. In order to perform a local build of the app and for local testing, you'll need to create your own copy of this file.

Create `ios/StatusPanel/configuration.json` with the following contents, populating the relevant API keys where appropriate:

```json
{
    "national-rail-api-token": "...",
    "tfl-api-id": "...",
    "tfl-api-key": "..."
}
```

You can obtain development API keys at:

- [National Rail Live Departure Boards](https://realtime.nationalrail.co.uk/OpenLDBWSRegistration/Registration)
- [Transport for London](https://api.tfl.gov.uk/)

### Build Numbers

The iOS app uses auto-generated build numbers that attempt to encode the build timestamp, along with some details of the commit used. They follow the format:

```
YYmmddHHMMxxxxxxxx
```

- `YY` -- two-digit year
- `mm` -- month
- `dd` -- day
- `HH` -- hours (24h)
- `MM` -- minutes
- `xxxxxxxx` -- zero-padded integer representation of a 6-character commit SHA

These can be quickly decoded using the `build-tools` script:

```
% scripts/build-tools/build-tools parse-build-number 210727192100869578
2021-07-27 19:21:00 (UTC)
0d44ca
```

### Managing Certificates

Builds use a base64 encoded [PKCS 12](https://en.wikipedia.org/wiki/PKCS_12) certificate and private key container, specified in the `IOS_CERTIFICATE_BASE64` environment variable (with the password given in the `IOS_CERTIFICATE_PASSWORD` environment variable). This loosely follows the GitHub approach to [managing certificates](https://docs.github.com/en/actions/guides/installing-an-apple-certificate-on-macos-runners-for-xcode-development).

Keychain Access can be used to export your certificate and private key in the PKCS 12 format, and the base64 encoded version is generated as follows:

```bash
base64 build_certificate.p12 | pbcopy
```

This, along with the password used to protect the certificate, can then be added to the GitHub project secrets.

#### Inspecting Certificates

Unlike `.cer` files (which can be viewed using [Quick Look](https://support.apple.com/en-gb/guide/mac-help/mh14119/mac)), macOS doesn't make it particularly easy to work with `.p12` PCKS 12 files; only Keychain Access is able to open these files and they will be automatically added to your keychain. If you want to double-check what's in a PCKS 12 file before adding it to your GitHub secrets, you can do this using `openssl`:

```bash
openssl pkcs12 -info -nodes -in build_certificate.p12
```

### Builds

In order to make continuous integration easy the `scripts/build.sh` script builds the full project, including submitting the macOS app for notarization. In order to run this script (noting that you probably don't want to use it for regular development cycles), you'll need to configure your environment accordingly, by setting the following environment variables:

- `IOS_CERTIFICATE_BASE64` – base64 encoded PKCS 12 certificate for iOS App Store builds (see above for details)
- `IOS_CERTIFICATE_PASSWORD` – password used to protect the iOS certificate
- `APPLE_API_KEY` – base64 encoded App Store Connect API key (see https://appstoreconnect.apple.com/access/api)
- `APPLE_API_KEY_ID` – App Store Connect API key id (see https://appstoreconnect.apple.com/access/api)
- `APPLE_API_KEY_ISSUER_ID` – App Store connect API key issuer id (see https://appstoreconnect.apple.com/access/api)
- `APP_CONFIGURATION` – JSON blob containing the [app configuration](#configuration)
- `GITHUB_TOKEN` -- [GitHub token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) used to create the release

The script (like Fastlane) will look for and source an environment file in the Fastlane directory (`Fastlane/.env`) which you can add your local details to. This file is, of course, in `.gitignore`. For example,

```bash
# Certificate store
export IOS_CERTIFICATE_BASE64=
export IOS_CERTIFICATE_PASSWORD=

# Developer account
export APPLE_API_KEY=
export APPLE_API_KEY_ID=
export APPLE_API_KEY_ISSUER_ID=

# Configuration
export APP_CONFIGURATION=

# GitHub (only required if publishing releases locally)
export GITHUB_TOKEN=
```

Once you've added your environment variables to this, run the script from the root of the project directory as follows:

```bash
./scripts/build.sh
```

### Custom Emoji

The iOS client has support for custom Emoji. Simply place a file following the appropriate naming convention in the fonts folder.

Files are named as follows:

```
fonts/<font name>/U+<unicode code>.png
```

All codes are zero-padded to 4 digits. For example, 'left double quotation mark', `“`, unicode code 201C, for font named 'font6x10', is located at `fonts/font6x10/U+201C.png` and `é` is at `fonts/font6x10/U+00E9.png`.

By default the font6x10 font is rendered at 2x scale, if you want to provide a custom character at that higher resolution (ie using 18x20 as the basis rather than 6x10 scaled to 200%) append `@2` on the end of the name: `fonts/font6x10/U+201C@2.png`.

```
      ◀─1px─▶ ◀─────────────5px──────────────▶
     ┌───────┬────────────────────────────────┐
   ▲ │     ▲ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │   8px │                                │
   │ │     │ │                                │
10px │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     │ │                                │
   │ │     ▼ │                                │
   │ │       └────────────────────────────────┼ ─ ─ Baseline
   │ │        ◀─────────────5px──────────────▶│
   │ │                                        │
   ▼ │                                        │
     └────────────────────────────────────────┘
     ◀──────────────────6px─────────────────▶
```

Specifically:

- 1 pixel padding to the left
- 2 pixels below the baseline

An additional one pixel is added between lines so it is safe to use the whole vertical space if you want. Further, Emoji are variable width, so you can made wide Emoji.

N.B. Typically Emoji are square, and will hang just below the baseline (c.f., g and 🙃). It is therefore perfectly acceptable to have a 9x9 character, in a 10 x 10 image, or an 18 x 18 character in a 20 x 20 image (at 2x).

Unicode Character Table seems to be a good resource for getting unicode code points: https://unicode-table.com/en/sets/top-emoji/.
