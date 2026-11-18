# Regolith ISO Builder

This is a fork of Elementary's ISO build scripts and there's still a ton of work left to do.

For now this _should_ build an ISO, no branding yet, not specific settings, no garantees that it will even boot or install. You've been warned.

## Prerequisites

- [Vagrant](https://www.vagrantup.com/) (>= 2.2.10)
- A backend for Vagrant. Most people will probably want to install [Virtualbox](https://www.virtualbox.org) (tested with version >= 6.1.10).

## Build ISO

1. `vagrant up`
2. `vagrant ssh`

Then, inside the box:

3. `cp -r /vagrant builder`
4. `cd builder`
5. `sudo ./build`

this should leave an ISO file and two checksum files in `builds/amd64/`.

## Minimal Debian 13 root filesystem

`bin/regolith-minimal-rootfs` produces the payload of a minimal Regolith
installer for Debian 13 (trixie, amd64): a root filesystem with only what
Regolith needs, as one uncompressed tar archive. It needs no root rights
and no user namespaces, so it runs in an ordinary CI job.

```
bin/regolith-minimal-rootfs plan --sources FILE
bin/regolith-minimal-rootfs build --sources FILE --output PATH
```

`FILE` is a deb822 sources file; every stanza names `file:`, `http:` or
`https:` archives and a `Signed-By` keyring, and those archives are the
only package sources used. [`minimal/trixie.sources`](minimal/trixie.sources)
lists the public Debian and Regolith archives. It expects the Debian keyring
from the `debian-archive-keyring` package and the Regolith one at
`/usr/share/keyrings/regolith-archive-keyring.gpg`:

```
wget -qO - https://archive.regolith-desktop.com/regolith.key \
  | gpg --dearmor | sudo tee /usr/share/keyrings/regolith-archive-keyring.gpg > /dev/null
```

With only `file:` archives (a local mirror), no network access is needed.

`plan` prints the selected packages (`name version`, one per line, byte
order). The set starts from the Regolith sessions, lightdm, the kernel,
systemd, GRUB EFI, NetworkManager, sudo, login, apt and the archive
keyrings, plus every Essential package, and follows only Pre-Depends and
Depends, except that the Recommends of Regolith's session, i3, sway and
window-manager packages (and of `regolith-desktop`) are followed too. Each
package is taken at its newest version in the sources, so the sources must
not include suites that apt would not pick from by default (backports,
experimental).

`build` installs that set with `mmdebstrap --mode=fakechroot`, runs
[`minimal/customize-rootfs`](minimal/customize-rootfs) on the result and
replaces `PATH` only once the archive is complete; on any error `PATH` is
left as it was. The image points apt at the Debian and Regolith archives
([`minimal/includes`](minimal/includes/etc/apt/sources.list.d)), keeps a
placeholder identity (hostname `regolith`, empty machine id, no users) and
boots to lightdm; partitioning, the bootloader, users and locale are left
to the installer.

Both subcommands need `mmdebstrap`, `fakechroot`, `fakeroot`, `apt` and
`python3`. `plan` runs on any Debian or Ubuntu system. `build` runs the
machine's own programs and fakechroot library against the image's C
library, so it needs the same glibc release as Debian 13 and refuses to
start otherwise: build on Debian 13, or on any other system (Ubuntu
included) in a `debian:trixie` container, which needs no privileges:

```
sudo apt-get install --no-install-recommends mmdebstrap fakechroot fakeroot apt python3 debian-archive-keyring
bin/regolith-minimal-rootfs build --sources minimal/trixie.sources --output regolith-trixie-rootfs.tar
```
