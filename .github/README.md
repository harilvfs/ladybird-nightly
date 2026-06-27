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
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash -s -- --dir ~/.local/ladybird
```

Then run:
```sh
ladybird
```

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash -s -- --uninstall
```

This removes the install directory (`~/.local/ladybird-nightly`) and the symlink (`~/.local/bin/ladybird`).

If you used a custom install path, pass it with `--dir`:
```sh
curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash -s -- --uninstall --dir ~/.local/ladybird
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

Crashes on Intel Haswell (4th gen, ~2013) and older CPUs with `SIGILL` in WebContent.
This should be upstream Ladybird issue. See [ladybird#8989](https://github.com/LadybirdBrowser/ladybird/issues/8989) [ladybird#3836](https://github.com/LadybirdBrowser/ladybird/issues/3836) [ladybird#10298](https://github.com/LadybirdBrowser/ladybird/issues/10298)
Builds should work fine if your CPUs are from ~2016 onwards.
