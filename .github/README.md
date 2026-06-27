# ladybird-nightly

Automated nightly builds of [Ladybird Browser](https://github.com/LadybirdBrowser/ladybird) for Linux x86_64.

> [!WARNING]
> **Unofficial.** This is not affiliated with the Ladybird project in any way. Ladybird is pre-alpha software only suitable for developer use.
>
> Also, please don't use this repo's issue tab for reporting any bugs related to Ladybird do that on the official repo. https://github.com/LadybirdBrowser/ladybird
>
> Instead, you can report bugs related to the install script or contribute any fixes related to this repo.

<!--

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/ladybird-nightly/main/install.sh | bash
```

Custom install path:
```sh
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/ladybird-nightly/main/install.sh | bash -s -- --dir ~/.local/ladybird
```

Then run:
```sh
ladybird
```

-->

## Runtime requirements (Linux)

```sh
# Ubuntu/Debian
sudo apt install qt6-base-dev

# Arch
sudo pacman -S qt6-base

# Fedora
sudo dnf install qt6-qtbase
```
