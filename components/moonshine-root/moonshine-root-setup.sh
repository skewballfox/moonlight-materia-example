#!/bin/sh
# SetupScript of the moonshine-root component. Root materia runs it as root,
# with every other component's scripts, before it asks the account's
# materia to update. It creates the moonshine account, which moonshine and
# nvidia-driver both run as, and starts the account's materia server.
# Safe to run again.
set -eu

account=moonshine
staging=/var/lib/materia/delegate/accounts/$account

getent group moonshine-input > /dev/null || groupadd --system moonshine-input
if ! getent passwd "$account" > /dev/null; then
    useradd --system --create-home --home-dir "/var/home/$account" \
        --groups render,moonshine-input "$account"
    # A system account gets no subordinate IDs, and rootless Podman needs
    # them. The range must not overlap one in /etc/subuid or /etc/subgid.
    usermod --add-subuids 524288-589823 --add-subgids 524288-589823 "$account"
fi

# Materia creates the staging directory root-only and never changes it.
# The account reads it through its group.
chgrp "$account" "$staging"

# The account's materia reads the staging directory. Its configuration
# stays outside the account's home, so the account cannot change it. No
# server.update_interval: root materia decides when the account updates.
install -d -m 0755 /etc/materia/accounts
cat > "/etc/materia/accounts/$account.toml" << CONFIG
attributes = "file"

[source]
kind = "local"
url = "file://$staging"

[file]
base_dir = "attributes"
load_all_vaults = true
CONFIG

# One unit for every account, started only where a configuration exists
cat > /etc/systemd/user/materia-account.service << 'UNIT'
[Unit]
Description=Materia server for this account
ConditionPathExists=/etc/materia/accounts/%u.toml
# Materia reaches Podman through its API socket
Wants=podman.socket
After=podman.socket

[Service]
Environment=MATERIA_CONFIG=/etc/materia/accounts/%u.toml
ExecStart=/usr/bin/materia server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
UNIT
systemctl --global enable materia-account.service

loginctl enable-linger "$account"
systemctl start "user@$(id -u "$account").service"
systemctl --user -M "$account@" daemon-reload
systemctl --user -M "$account@" start materia-account.service
