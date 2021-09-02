# StatusPanel

## Getting Started

StatusPanel uses [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules), so before doing anything else, you'll need to do:

```bash
git submodule update --init
```

You'll also need to run this command if the submodules change.

## Bill of Materials

| *Part*                                                                              | *Supplier*        | *Link*                                              | *Cost* | *Quantity* |
| ----------------------------------------------------------------------------------- | ----------------- | --------------------------------------------------- | ------ | ---------- |
| Tactile Button Switch (6 mm)                                                        | Adafruit          | https://www.adafruit.com/product/367                | $0.125 | 1          |
| Breadboard-friendly SPDT Slide Switch / E-Switch EG1218                             | Adafruit / Mouser | https://www.adafruit.com/product/805 / https://www.mouser.com/ProductDetail/E-Switch/EG1218                | $0.95  | 1          |
| Adafruit HUZZAH32 – ESP32 Feather Board                                             | Adafruit          | https://www.adafruit.com/product/3405               | $19.95 | 1          |
| 640x384, 7.5inch E-Ink display HAT for Raspberry Pi, yellow/black/white three-color | Waveshare         | https://www.waveshare.com/7.5inch-e-paper-hat-c.htm | $53.99 | 1          |
| Diffused 3mm LED                                                                    | Adafruit          | https://www.adafruit.com/product/4202               | $0.118 | 1          |

Possible future display:

- [Waveshare 1304×984, 12.48inch E-Ink display module, red/black/white three-color](https://www.waveshare.com/product/raspberry-pi/12.48inch-e-paper-module-b.htm)

It looks like Waveshare are phasing out the display we're currently using and replacing it with one of the same physical size, but a higher resolution.

## Components

StatusPanel comprises a number of different components:

- [Firmware](nodemcu/README.markdown)
- [PCB](#pcb)
- [Service](#service)

## PCB

The EagleCAD files make use of the following component libraries which are added to the project as submodules:

- pcb/libraries/SparkFun-Eagle-Libraries/SparkFun-LED.lbr

![Schematics](pcb/statuspanel.png)

![Tom's notes](images/pinout.jpg)

## Client

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

## Service

### Heroku

There are two apps in the Heroku pipeline:

- statuspanel-staging - auto-deploys master
- statuspanel-production - manual deploy from staging

These Heroku apps have a couple of slightly non-standard requirements (they require both Python and Node.js buildpacks, and some additional environment variables), so they can be configured locally using the `configure-heroku-app` script. For example,

```bash
./scripts/configure-heroku-app statuspanel-staging
```

### Dependencies

```bash
brew install pipenv
pipenv install
```

### Running Locally

When running the service locally using the `heroku local` command, it uses the environment variables configured in `.env`. These are currently configured to use a local Postgres instance.

You can use the following command to create a suitably configured docker container for testing:

```bash
docker run \
    --name some-postgres \
    -p 5432:5432 \
    -e POSTGRES_PASSWORD=0EFDA2E7-9700-4F06-ADCB-55D8E38A37DF \
    -d postgres
```

Once your docker container is running, you can run the local service as follows:

```
pipenv run heroku local
```

### Testing APNS

When testing APNS, it can be useful to configure the environment variables required to communicate with the production instance of APNS. This can be done by running the following commands:

```bash
export APNS_TEAM_ID=S4WXAUZQEV
export APNS_BUNDLE_ID=uk.co.inseven.status-panel
export ANPS_KEY_ID=V5XKL2D8B9
export APNS_KEY=`cat apns.p8`
```

N.B. This assumes the APNS private key is in `apns.p8` and these commands are executed from the root directory.

If you wish to test notification deployment, you will also need to pass the database URL when running the APNS periodic command:

```bash
pipenv run python3 service/task.py --database-url <database_url>
```

### Tests

Install the Python dependencies:

```bash
pipenv install
```

Local API tests make use of a named docker container (creating and deleting the container where appropriate), and the Flask test client:

```bash
pipenv run python -m unittest discover --verbose --start-directory service/tests
```

Sometimes, it can be quite useful to run individual unit tests. This can be done as follows:

```
pipenv run python service/tests/test_api.py --verbose TestAPI.test_index
```

Tests can also be run on the live environments by selecting the correct `.env` file. In this scenario, the Python `requests` client is used and tests are performed against the live databases.

It is encouraged to run the tests on staging prior to promoting to production.

Staging:

```bash
PIPENV_DOTENV_LOCATION=.env.staging pipenv run \
    python -m unittest discover \
    --verbose \
    --start-directory service/tests
```

Production:

```bash
PIPENV_DOTENV_LOCATION=.env.production pipenv run \
    python -m unittest discover \
    --verbose \
    --start-directory service/tests
```

# Command-line

It can sometimes be useful to make requests directly from the command-line during development. `curl` can be useful for this. For example,

```bash
curl --header "Content-Type: application/json" \
     --request POST \
     --data '{"token":"123456789"}' \
     http://127.0.0.1:5000/api/v3/device/
```
