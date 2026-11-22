# Moonlight streaming host

A materia repository for one host, `streambox`. It runs **moonshine**, a
Moonlight streaming server, with Steam as its one app, on an NVIDIA GPU.
Every container runs rootless, as the service account `moonshine`. Forma
creates the account, builds and signs every image, and confines the
account.

## Layout

```
MANIFEST.toml                    the host streambox and its role, streaming
attributes/streambox.toml        per-host values: the render node
components/
  moonshine-root/                runs as root: the scripts that call forma,
    moonshine-root-setup.sh      every [Forma] table, the Containerfiles and
    moonshine-root-cleanup.sh    the SELinux sources
    build/
    selinux/
  nvidia-driver/                 runs as the account: the driver volume
    nvidia-driver.volume
  moonshine/                     runs as the account: moonshine, Xvfb, the
    moonshine.container.gotmpl   bus proxy
    moonshine-xvfb.container
    moonshine-*.volume
    moonshine-bus-proxy.service
host/                            files root installs once, outside materia
```

## How it runs

`moonshine` and `nvidia-driver` set `[Settings] User = "moonshine"`, so
they run as that account (materia's "Delegated Components").
`moonshine-root` sets none: root materia runs it, and its `[Forma]` tables,
with those in the repository manifest, say what forma prepares for the
account.

**Forma rejects this layout.** It builds images only for a component that
sets `User` (`ImageWithoutUser`). Everything else plans.

1. Root materia syncs this repository, resolves the attributes, and stages
   both components for the account.
2. It runs `moonshine-root`'s setup script as root, which runs
   `forma apply moonshine-root`. Forma creates the account and the
   `moonshine-input` group, and the accounts that build and sign images. It
   maps the account to the SELinux user `user_u`, installs the component's
   SELinux modules, writes the account's image policy, and starts the
   account's materia.
3. Root materia asks the account's materia to update. That materia renders
   the templates, installs the Quadlets and units in the account's home,
   and starts `moonshine.service`.
4. Forma's builder builds the four images on their schedules, its signer
   signs them, and the account loads only signed images. The account
   cannot pull an image.

Some files must be owned by root, such as the udev rules and moonshine's
launcher. They are in [`host/`](host/README.md), with the steps to set up a
host.

## Per-host values

| Value | Where | What it is |
|---|---|---|
| `NV_VERSION` | `MANIFEST.toml`, the host's extension of `moonshine-root` | The loaded NVIDIA kernel module, `cat /sys/module/nvidia/version`. The driver image must match it. |
| `render_node` | `attributes/streambox.toml` | The NVIDIA card's render node. |

The driver version is a build argument, and forma reads build arguments
from the manifests, which materia does not template. So it cannot be an
attribute.

## Updating

- **Images:** forma rebuilds moonshine daily when its `patches` branch has
  moved, and the other images weekly. After a load, `podman auto-update`
  restarts the containers that use a new image.
- **A new NVIDIA driver:** set `NV_VERSION` for the host. After forma loads
  the new driver image, remove the volume as the account, `podman volume
  rm nvidia-driver-vol`, because it keeps the image it was created from.
  Until then `moonshine.service` refuses to start.

## About this example

This is `materia-moonlight-example` with forma added: its `main` is that
repository's `main` plus one commit. Nothing here has run, and neither has
forma's executor. On `main`, forma's planner accepts the repository: 37
steps, no problems and no warnings, planned with forma's test support
against an in-memory Fedora host.

Branches for places where the design is still open and the choice changes
this repository. The `trigger/*` branches are materia's open questions:
each is the materia example's branch of the same name plus the forma
commit. The others are forma's, one commit on `main`. A proposed key fails
forma's checks with `UnknownKey`.

| Branch | Open question | What changes |
|---|---|---|
| `trigger/no-component-scripts` | Whether materia gets host-wide hooks, or forma runs after materia | No lifecycle scripts in the components. A hook, or a forma run after each materia run, calls forma. |
| `trigger/root-companion` | Whether one component's work may be split between two materia instances | A root component, `moonshine-root`, holds the scripts and the `[Forma]` tables. Forma rejects it: it builds images only for a component that sets `User`. |
| `images/load-for` | Which account loads an image no Quadlet names | `LoadFor` on the Steam image |
| `images/account-images` | Same question | `Images` on the account |
| `host/forma-udev-keys` | Whether forma declares udev rules and kernel modules | The udev rules and modules move into the moonshine component, under proposed `[Forma]` keys. |

`run-as-user`, the materia example's branch for a materia without
delegation, has no forma counterpart: an account that reads the
repository itself could edit the `[Forma]` tables that root acts on.
