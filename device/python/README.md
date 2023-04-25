# Python Firmware

Simple Python implementation of the StatusPanel device protocol.

Right now, only the Raspberry Pi and Pimoroni Inky displays are supported, but support for other devices and hardware can be added in the future.

## Installation

### Raspberry Pi

1. Install package dependencies:

   ```bash
   sudo apt-get install \
       python3-pip \
       python3-qrcode
   ```

2. Install Python dependencies:

   ```bash
    pip3 install --user pysodium
   ```

3. Install the Pimoroni Inky library:

   ```bash
   curl https://get.pimoroni.com/inky | bash
   ```

3. Run StatusPanel:

   ```bash
   python3 src/device.py
   ```
