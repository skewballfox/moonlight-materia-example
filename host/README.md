# Host files

Files that root must own, or that sit at a fixed path outside every
account's home. Materia installs a delegated component's files as the
account, in the account's home, so none of these can be part of a
component. The administrator installs them once.

| File | Installed as | Why root owns it |
|---|---|---|
| `selinux/` | SELinux modules, installed with `semodule` | Policy for the bus proxy and the container types. |
| `bin/moonshine-bus-proxy` | `/usr/local/libexec/moonshine-bus-proxy`, `0755` | Runs in its own SELinux domain. Neither the account nor a container should be able to change it. |
| `etc-moonshine/config.toml` | `/etc/moonshine/config.toml`, `root:moonshine 0640` | Moonshine's config, mounted read-only into its container. |
| `etc-moonshine/launch-steam` | `/etc/moonshine/launch-steam`, `root:moonshine 0750` | The account's user manager runs it on the host whenever moonshine starts a session. The bus proxy lets moonshine start only this path, so the container and the account must not be able to change it. |
| (directory) | `/etc/moonshine/state/`, `moonshine:moonshine 0750` | Moonshine's TLS key and paired clients. The account writes it. |
| `systemd-user/moonshine-session.service.d/stop-steam.conf` | `/etc/systemd/user/moonshine-session.service.d/stop-steam.conf` | A drop-in for a transient unit. Materia installs a `.conf` file as data, where systemd never reads it. |
| `udev/85-moonshine.rules` | `/etc/udev/rules.d/85-moonshine.rules` | Gives `/dev/uinput`, `/dev/uhid` and moonshine's pads to `moonshine-input`, and moves every virtual input device off the desktop seat. |
| `modules-load.d/moonshine.conf` | `/etc/modules-load.d/moonshine.conf` | Loads `uinput` and `uhid` at boot. |
| `firewalld/moonshine.xml` | `/etc/firewalld/services/moonshine.xml` | Moonshine's ports. |
| `scripts/moonshine-account.sh` | Run by hand, as root, or from a setup hook | Creates the moonshine account and starts its materia. |
| `scripts/games-disk.sh`, `scripts/steam-library.sh` | Run by hand, as root | Mount a games disk at `/var/mnt/games/<name>` and add its library to Steam. |

## Setting up a host

Run these as root, from this directory. On secureblue, run `semodule` and
`restorecon` from a login shell, not straight from `run0`.

1. **Root materia.** `/etc/materia/config.toml`:

   ```toml
   attributes = "file"

   [source]
   kind = "git"
   url = "https://git.example.invalid/you/materia-moonlight-example.git"

   [file]
   base_dir = "attributes"
   ```

2. **Base image pulls.** The account builds its own images, so its Podman
   pulls `registry.fedoraproject.org/fedora-minimal`. Fedora does not sign
   that image. A host whose `/etc/containers/policy.json` rejects unsigned
   images (secureblue does) needs an entry for that registry. The
   Containerfiles pin the image by digest either way.

3. **The account.** No component creates it. Either run
   `scripts/moonshine-account.sh` once, before the first update, or let
   materia run it for each new component from a host-wide hook. Hooks are
   a proposal; materia does not have them yet:

   ```toml
   # /etc/materia/config.toml
   [executor.hooks]
   setup = ["/usr/local/sbin/moonshine-account"]
   ```

   with the script installed as `/usr/local/sbin/moonshine-account`. Then
   `materia update`. `moonshine.service` fails to start until the next two
   steps are done.

4. **SELinux.** The account runs as `unconfined_u`, Fedora's default for a
   new user, and the policy is written for that. The `.cil` types build on
   container-selinux's udica templates, loaded in the same transaction.

   ```sh
   build=$(mktemp -d)
   cp selinux/* /usr/share/udica/templates/base_container.cil \
       /usr/share/udica/templates/net_container.cil "$build/"
   make -s -C "$build" -f /usr/share/selinux/devel/Makefile moonshine.pp
   semodule -i "$build/moonshine.pp" "$build"/*.cil
   rm -rf "$build"
   ```

5. **The other host files.**

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
   restorecon -RF /etc/moonshine /var/mnt/games
   install -m 0644 firewalld/moonshine.xml /etc/firewalld/services/moonshine.xml
   firewall-cmd --reload
   firewall-cmd --permanent --add-service=moonshine
   firewall-cmd --add-service=moonshine
   ```

6. **Restart moonshine:** `systemctl --user -M moonshine@ restart moonshine.service`.

## Steam between streams

While the Steam client updates, it draws nothing, and Moonlight drops the
stream. To let Steam update and download games outside a stream, run the
launcher in the account's user manager with no display. It uses Xvfb's
display instead:

```sh
systemd-run --user -M moonshine@ --wait --unit=moonshine-steam-update /etc/moonshine/launch-steam
```
