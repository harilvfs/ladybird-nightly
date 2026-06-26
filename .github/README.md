# ladybird-nightly

Automated nightly builds of [Ladybird Browser](https://github.com/LadybirdBrowser/ladybird) for Linux x86_64.

> [!WARNING]
> **Unofficial.** Not affiliated with the Ladybird project. Ladybird is pre-alpha software.

<--
## Install

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/ladybird-nightly/main/install.sh | bash
```

Custom install path:
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/ladybird-nightly/main/install.sh | bash -s -- --dir ~/.local/ladybird
```

Then run:
```bash
ladybird
```

-->

## How it works

- Runs daily at 02:00 UTC via GitHub Actions
- Checks the latest commit SHA on `LadybirdBrowser/ladybird` master branch
- Skips the build if nothing changed since the last release
- Builds with `clang-21`, `cmake --preset default`, Qt6 frontend
- Packages binaries + libraries + resources into a tarball
- Publishes as a GitHub Release tagged `nightly-YYYYMMDD-SHORTSHA`

## Runtime requirements (Linux)

```bash
# Ubuntu/Debian
sudo apt install qt6-base-dev

# Arch
sudo pacman -S qt6-base

# Fedora
sudo dnf install qt6-qtbase
```
