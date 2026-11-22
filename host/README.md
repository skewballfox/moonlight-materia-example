# Host files

Files that root must own, or that sit at a fixed path outside every
account's home. Materia installs a delegated component's files as the
account, in the account's home, so none of these can be part of a
component. Forma's manifest extension has no keys for them yet: udev
rules and kernel modules are out of scope for forma version 1. The
administrator installs them once.

| File | Installed as | Why root owns it |
|---|---|---|
| `bin/moonshine-bus-proxy` | `/usr/local/libexec/moonshine-bus-proxy`, `0755` | Its file label is the entry point of its SELinux domain. A copy the account could write would not carry that label. |
| `etc-moonshine/config.toml` | `/etc/moonshine/config.toml`, `root:moonshine 0640` | Moonshine's config, mounted read-only into its container. |
| `etc-moonshine/launch-steam` | `/etc/moonshine/launch-steam`, `root:moonshine 0750` | The account's user manager runs it on the host whenever moonshine starts a session. The bus proxy lets moonshine start only this path, so the container and the account must not be able to change it. |
| (directory) | `/etc/moonshine/state/`, `moonshine:moonshine 0750` | Moonshine's TLS key and paired clients. The account writes it. |
| `systemd-user/moonshine-session.service.d/stop-steam.conf` | `/etc/systemd/user/moonshine-session.service.d/stop-steam.conf` | A drop-in for a transient unit. Materia installs a `.conf` file as data, where systemd never reads it. |
| `udev/85-moonshine.rules` | `/etc/udev/rules.d/85-moonshine.rules` | Gives `/dev/uinput`, `/dev/uhid` and moonshine's pads to `moonshine-input`, and moves every virtual input device off the desktop seat. |
| `modules-load.d/moonshine.conf` | `/etc/modules-load.d/moonshine.conf` | Loads `uinput` and `uhid` at boot. |
| `firewalld/moonshine.xml` | `/etc/firewalld/services/moonshine.xml` | Moonshine's ports. |
| `scripts/games-disk.sh`, `scripts/steam-library.sh` | Run by hand, as root | Mount a games disk at `/var/mnt/games/<name>` and add its library to Steam. |

## Setting up a host

Run these as root, from this directory. On secureblue, run `restorecon`
from a login shell, not straight from `run0`.

1. **Root materia.** `/etc/materia/config.toml`:

   ```toml
   attributes = "file"

   [source]
   kind = "git"
   url = "https://git.example.invalid/you/forma-moonlight-example.git"

   [file]
   base_dir = "attributes"
   ```

2. **Forma.** `/etc/forma/config.toml` holds the limits the repository may
   not set:

   ```toml
   [paths]
   # Absolute paths the repository may name; /etc/moonshine is the
   # moonshine component's Relabel target
   allowed_roots = ["/var/lib/forma", "/var/home", "/etc/moonshine"]

   [accounts]
   id_range = { start = 900, end = 999 }
   home_base = "/var/home"

   [selinux]
   # The moonshine component ships SELinux modules
   allow_modules = true
   priority = 350

   [base_images]
   # The host's /etc/containers/policy.json also applies to the builder's
   # base image pulls. Fedora does not sign its base images: a host whose
   # policy rejects unsigned images (secureblue does) needs an entry for
   # registry.fedoraproject.org there, or "ignore" here.
   host_policy = "respect"
   ```

   The account is mapped to `user_u`, so the SELinux boolean
   `user_t_run_containers` must be on.

3. **The first update:** `materia update`. Forma, from the components'
   setup scripts, creates the account, the `moonshine-input` group, the
   builder and signer accounts and the account's materia, and installs the
   SELinux modules. `moonshine.service` fails to start until the next step
   is done.

4. **The other host files.**

   ```sh
   install -D -m 0755 bin/moonshine-bus-proxy /usr/local/libexec/moonshine-bus-proxy
   install -d -o root -g moonshine -m 0750 /etc/moonshine
   install -d -o moonshine -g moonshine -m 0750 /etc/moonshine/state
   install -o root -g moonshine -m 0640 etc-moonshine/config.toml /etc/moonshine/config.toml
   install -o root -g moonshine -m 0750 etc-moonshine/launch-steam /etc/moonshine/launch-steam
   install -D -m 0644 systemd-user/moonshine-session.service.d/stop-steam.conf \
       /etc/systemd/user/moonshine-session.service.d/stop-steam.conf
   install -m 0644 udev/85-moonshine.rules /etc/udev/rules.d/85-moonshine.rules
   install -m 0644 modules-load.d/moonshine.conf /etc/modules-load.d/moonshine.conf
   systemctl restart systemd-modules-load.service
   echo change | tee /sys/class/misc/uinput/uevent /sys/class/misc/uhid/uevent
   install -d -m 0755 /var/mnt/games
   restorecon -RF /etc/moonshine /usr/local/libexec/moonshine-bus-proxy /var/mnt/games
   install -m 0644 firewalld/moonshine.xml /etc/firewalld/services/moonshine.xml
   firewall-cmd --reload
   firewall-cmd --permanent --add-service=moonshine
   firewall-cmd --add-service=moonshine
   ```

5. **Restart moonshine:** `systemctl --user -M moonshine@ restart moonshine.service`.

## Steam between streams

While the Steam client updates, it draws nothing, and Moonlight drops the
stream. To let Steam update and download games outside a stream, run the
launcher in the account's user manager with no display. It uses Xvfb's
display instead:

```sh
systemd-run --user -M moonshine@ --wait --unit=moonshine-steam-update /etc/moonshine/launch-steam
```
