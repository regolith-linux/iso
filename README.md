# Regolith ISO Builder

This is a fork of Elementary's OS [build scripts]. Many thanks to elementary
crew for the great work!

## Build ISO

The following example uses Docker and assumes you have Docker correctly installed
and set up.

Clone this project & cd into it:

```bash
git clone https://github.com/regolith-linux/iso && cd iso
```

and then execute the followin docker command:

```bash
docker run \
    --rm \
    -it \
    --privileged \
    -v /proc:/proc \
    -v ${PWD}:/workspace \
    -w /workspace \
    ghcr.io/regolith-linux/ci-debian:bookworm-amd64 \
    sudo ./build.sh releases/3.2/ubuntu-noble.conf
```

This should generate the following files in `builds/amd64/`:

- `regolith-<VERSION>-<CODENAME>-<ARCH>.iso`
- `regolith-<VERSION>-<CODENAME>-<ARCH>.iso.contents`
- `regolith-<VERSION>-<CODENAME>-<ARCH>.iso.log`
- `regolith-<VERSION>-<CODENAME>-<ARCH>.iso.packages`
- `regolith-<VERSION>-<CODENAME>-<ARCH>.sha256sum`

## Examples

### Building for `arm64`

Set `ARCH=arm64` environment variable when executing `build.sh`.

```bash
docker run \
    ... \
    sudo ARCH=arm64 ./build.sh releases/3.2/ubuntu-noble.conf
```

[build scripts]: https://github.com/elementary/os
