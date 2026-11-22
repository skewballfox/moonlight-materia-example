# Moonlight streaming host

A materia repository for one host, `streambox`. It runs **moonshine**, a
Moonlight streaming server, with Steam as its one app, on an NVIDIA GPU.
Every container runs rootless, as the service account `moonshine`, which
builds its own images.

## Layout

```
MANIFEST.toml                    the host streambox and its role, streaming
attributes/streambox.toml        per-host values: driver version, moonshine
                                 commit, render node
components/
  moonshine-root/                runs as root: sets up the moonshine account
    moonshine-root-setup.sh
    moonshine-root-cleanup.sh
  nvidia-driver/                 NVIDIA userspace as an image volume
    nvidia-driver.build.gotmpl
    nvidia-driver.volume
    build/nvidia-driver.Dockerfile
  moonshine/                     moonshine, Xvfb, the bus proxy, Steam's image
    moonshine.container.gotmpl
    moonshine-xvfb.container
    moonshine-*.volume
    moonshine-bus-proxy.service
    moonshine.build.gotmpl, steam.build.gotmpl, xvfb.build.gotmpl
    build/                       Containerfiles for moonshine, Steam and Xvfb
host/                            files root installs once, outside materia
```

## How it runs

`moonshine` and `nvidia-driver` set `[Settings] User = "moonshine"`, so they
run as that account (materia's "Delegated Components"). `moonshine-root`
sets none: root materia runs it, and it holds the scripts that set up the
account.

1. Root materia syncs this repository, resolves the attributes, and stages
   both components for the account.
2. It runs `moonshine-root-setup.sh` as root. The script creates the account and
   the `moonshine-input` group, and starts the account's materia server.
3. Root materia asks the account's materia to update. That materia renders
   the templates, installs the Quadlets and units in the account's home,
   builds the images and starts `moonshine.service`.

Some files must be owned by root, such as the udev rules, the SELinux
policy and moonshine's launcher. They are in [`host/`](host/README.md),
with the steps to set up a host.

## Per-host values

`attributes/streambox.toml`, read with materia's `file` engine:

| Attribute | Component | What it is |
|---|---|---|
| `nv_version` | `nvidia-driver` | The loaded NVIDIA kernel module, `cat /sys/module/nvidia/version`. The driver image must match it. |
| `moonshine_commit` | `moonshine` | The commit of moonshine's `patches` branch to build. |
| `render_node` | `moonshine` | The NVIDIA card's render node. |

## Updating

- **A new NVIDIA driver:** set `nv_version`. After the account rebuilds the
  driver image, remove the volume as the account, `podman volume rm
  nvidia-driver-vol`, because it keeps the image it was created from. Until
  then `moonshine.service` refuses to start.
- **A new moonshine:** set `moonshine_commit`. Whether materia starts a
  `.build` unit again when its file changes is not checked; if it does not,
  `systemctl --user -M moonshine@ restart moonshine-build.service`.

## About this example

Adapted from corectl's `moonshine/` and `Wolf/`. Nothing here has run; the
templates render with stand-in values. `[Settings] User` comes from
materia's delegation change, materia PR 63. `moonshine_commit` is a
placeholder.

`forma-moonlight-example` is this repository with forma added. Its `main`
is this `main` plus one commit.

Branches, each one commit on `main`, for places where materia's design is
still open and the choice changes this repository:

| Branch | Open question | What changes |
|---|---|---|
| `trigger/no-component-scripts` | Whether materia gets host-wide hooks | No lifecycle scripts in the components. The account setup becomes a host script that a hook, or the administrator, runs. |
| `trigger/root-companion` | Whether one component's work may be split between two materia instances (PR 63 discussion) | A root component, `moonshine-root`, holds the setup scripts. `moonshine` holds only what the account runs. |
| `run-as-user` | Whether materia takes the delegation change at all | No `[Settings] User`. The account runs its own materia, which reads this repository. |
