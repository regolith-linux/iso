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
