[![Nightly Linux Build](https://github.com/harilvfs/ladybird-nightly/actions/workflows/build-linux.yml/badge.svg)](https://github.com/harilvfs/ladybird-nightly/actions/workflows/build-linux.yml)

# ladybird-nightly

Automated nightly builds of [Ladybird Browser](https://github.com/LadybirdBrowser/ladybird) for Linux x86_64.

> [!WARNING]
> **Unofficial.** This is not affiliated with the Ladybird project in any way. Ladybird is pre-alpha software only suitable for developer use.
>
> Also, please don't use this repo's issue tab for reporting any bugs related to Ladybird do that on the official repo. https://github.com/LadybirdBrowser/ladybird
>
> Instead, you can report bugs related to the install script or contribute any fixes related to this repo.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash
```

Custom install path:
```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash -s -- --dir ~/.local/ladybird # place your desire dir
```

Then run:
```sh
ladybird   # with terminal output
lb         # silent (no output for Rofi / daily use)
```

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash -s -- --uninstall
```

The `uninstall` flag removes the install directory along side other file's that was installed on your system. 

If you used a custom install path, pass it with `--dir`:
```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash -s -- --uninstall --dir ~/.local/ladybird # place your actual dir
```

## Runtime requirements (Linux)

```sh
# Ubuntu/Debian
sudo apt install qt6-base-dev

# Arch
sudo pacman -S qt6-base

# Fedora
sudo dnf install qt6-qtbase
```

## Known Issues

### SSL / HTTPS not working (error 77)

Ladybird uses a Landlock sandbox that only allows filesystem access to `/etc/ssl` for SSL certificates. On distros like **Arch Linux**, **openSUSE**, and **NixOS**, the cert files under `/etc/ssl/` are symlinks pointing to `/etc/ca-certificates/` path *outside* the sandbox. The kernel resolves the symlink and
blocks access to the real file, causing all HTTPS requests to fail with this error:

```
Request::handle_complete_state: Unable to map error (77): "Problem with the SSL CA cert (path? access rights?)"
```

The install script now fix this automatically by placing a real copy of the cert bundle at `/etc/ssl/ladybird-ca-bundle.crt`. If you see this error, re-run the installer or manually fix it:

```sh
sudo cp ~/.local/ladybird-nightly/ca-bundle-sandbox.crt /etc/ssl/ladybird-ca-bundle.crt
```

This is an upstream Ladybird issue. See [ladybird#8303](https://github.com/LadybirdBrowser/ladybird/issues/8303).

### SIGILL crash on older CPUs

Crashes on Intel Haswell (4th gen, ~2013) and older CPUs with `SIGILL` in WebContent.
This should be upstream Ladybird issue. See [ladybird#8989](https://github.com/LadybirdBrowser/ladybird/issues/8989) [ladybird#3836](https://github.com/LadybirdBrowser/ladybird/issues/3836) [ladybird#10298](https://github.com/LadybirdBrowser/ladybird/issues/10298).
Builds should work fine if your CPUs are from ~2016 onwards.
