#!/bin/bash -e

# Enable I2C and SPI.
cat <<EOF>> "${ROOTFS_DIR}/boot/config.txt"
dtparam=i2c_arm=on
dtparam=spi=on
EOF

# Autoload the I2C device (enabled in stage1/00-boot-files/files/config.txt).
cat <<EOF>> "${ROOTFS_DIR}/etc/modules"
i2c-dev
EOF

# Install Pimoroni Inky library.
on_chroot <<EOF
cd /opt
git clone --depth 1 https://github.com/pimoroni/inky.git
cd inky
./install.sh
EOF

# Install StatusPanel Python dependencies.
on_chroot <<EOF
pip3 install pysodium
EOF

# Install StatusPanel.
install -d "${ROOTFS_DIR}/opt/statuspanel"
install -m 755 files/device.py "${ROOTFS_DIR}/opt/statuspanel/"

# Install the StatusPanel service.
cat <<EOF> "${ROOTFS_DIR}/etc/systemd/system/statuspanel.service"
[Unit]

Description=StatusPanel
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/statuspanel/device.py
User=root

[Install]
WantedBy=multi-user.target
EOF

on_chroot <<EOF
systemctl enable statuspanel.service
EOF
