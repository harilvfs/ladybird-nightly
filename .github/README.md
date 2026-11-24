[![Nightly Linux Build](https://github.com/harilvfs/ladybird-nightly/actions/workflows/build-linux.yml/badge.svg)](https://github.com/harilvfs/ladybird-nightly/actions/workflows/build-linux.yml)
[![Latest Release](https://img.shields.io/github/v/release/harilvfs/ladybird-nightly)](https://github.com/harilvfs/ladybird-nightly/releases) [![Downloads](https://img.shields.io/github/downloads/harilvfs/ladybird-nightly/total)](https://github.com/harilvfs/ladybird-nightly/releases)

# Ladybird Nightly

**Unofficial, automated nightly builds of the [Ladybird browser](https://github.com/LadybirdBrowser/ladybird) for Linux x86_64.**

Ladybird has [officially entered alpha](https://ladybird.org/posts/alpha/), with downloads for macOS and Linux. This independent project builds Linux x86_64 nightlies from upstream `master`. The daily CI pipeline provides ready-to-run builds without requiring you to compile Ladybird yourself.

> [!NOTE]
> **Unofficial nightly build.** This project is not affiliated with or endorsed by Ladybird. Some websites may not work and the browser may crash. Security is not guaranteed. Use at your own risk, and avoid using it for sensitive browsing.
>
> Report browser bugs to [Ladybird](https://github.com/LadybirdBrowser/ladybird) or use its in-browser site reporting. Use this repository's issues for problems with these nightly builds, packaging, or the installer.
>
> These nightlies are separate builds from Ladybird's official releases and may differ from them.

## Install

### Automatic install

The installer selects a distro package on supported systems and uses the tarball elsewhere:

```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash
```

To force the compiled distro-independent build, pass `--tarball`:

```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash -s -- --tarball
```

Then run:
```sh
ladybird   # with terminal output
lb         # silent (no output good for Rofi and daily use)
```

The installer automatically uses a distro package on Ubuntu 26.04, Fedora 44, and Arch Linux or Arch-based systems. These packages are published as prereleases on the [releases page](https://github.com/harilvfs/ladybird-nightly/releases); you do not need to download or install them manually.

> [!WARNING]
> Packages are tested on the mainline target distributions: Ubuntu 26.04, Fedora 44, and Arch Linux. Although Ubuntu is based on Debian, the Ubuntu package may not work on Debian because Debian releases can have older Qt and glibc versions. Compatibility with Ubuntu-based, Fedora-based, and Arch-based distributions is not guaranteed.

The Ubuntu and Fedora packages follow Ladybird upstream's build dependencies. Upstream does not directly support Arch, so I maintain the Arch dependency mapping and packaging. The Arch package currently works, but upstream changes may require updates. I will keep working to maintain compatibility, though it may not always work.

On other systems, the installer uses the compiled distro-independent tarball build. It has not been tested on distributions such as openSUSE or NixOS, on BSD, or on every other Linux distribution, so I cannot guarantee it will work there yet. If you run into an installation or runtime issue, please [open an issue](https://github.com/harilvfs/ladybird-nightly/issues), especially if you are using a derivative distribution. Include your distro, version, and the error you encountered.

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash -s -- --uninstall
```

The `--uninstall` flag removes the tarball files and any installed Ladybird distro package it detects. If you used a custom install directory, pass it with `--dir`:

```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash -s -- --uninstall --dir ~/.local/ladybird # place your actual dir
```

## Runtime requirements (Linux)

```
# Ubuntu
sudo apt install qt6-base-dev

# Arch
sudo pacman -S qt6-base

# Fedora
sudo dnf install qt6-qtbase
```

## Dark Theme (Linux)

> ⚠️ **Deprecated:** Ladybird now manages its own appearance and theme. Change it in Ladybird's appearance settings. The Qt theme environment overrides below are kept for reference and may no longer work.

Older builds used the Qt frontend on Linux. To make those builds respect your system's Qt theme, add these to your shell config:

> [!NOTE]
> Make sure you have `qt6ct` and `kvantum` installed and configured to use a dark theme.
> 
> This override is optional; if your system doesn't default to Qt6, this may help you!

**bash** `~/.bashrc` or **zsh** `~/.zshrc`:

```sh
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=kvantum
```

**fish** `~/.config/fish/config.fish`:

```fish
set -gx QT_QPA_PLATFORMTHEME qt6ct
set -gx QT_STYLE_OVERRIDE kvantum
```

then restart your shell.

Alternatively, you can set these system-wide by adding the following to `/etc/environment`:

```
QT_QPA_PLATFORMTHEME=qt6ct
QT_STYLE_OVERRIDE=kvantum
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

## Why this exists

- This project offers Linux x86_64 nightlies built from upstream `master`.
- It makes it easier to try upstream changes without setting up a local build environment.

## Build Status

Nightly builds may occasionally fail due to upstream changes in Ladybird or its dependencies. Features may be incomplete, and crashes or compatibility issues are possible.

If the latest release is older than a few days, the build is likely broken. I will try to get it fixed as soon as possible.
