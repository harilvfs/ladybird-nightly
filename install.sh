#!/usr/bin/env bash

# usage: curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash
# uninstall: curl -fsSL ... | bash -s -- --uninstall

set -euo pipefail

REPO="harilvfs/ladybird-nightly"
DEFAULT_INSTALL_DIR="$HOME/.local/ladybird-nightly"
UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    --help | -h)
      echo "Usage: install.sh [--uninstall]"
      echo "  --uninstall   remove the distro package and local install files"
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

if [[ "$UNINSTALL" -eq 1 ]]; then
  echo "Uninstalling Ladybird nightly..."

  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    DISTRO_ID="${ID:-}"
    DISTRO_ID_LIKE="${ID_LIKE:-}"
    remove_package() {
      if [[ "$(id -u)" -ne 0 ]]; then
        command -v sudo &>/dev/null || {
          echo "error: sudo is required to remove the distro package." >&2
          exit 1
        }
        sudo "$@"
      else
        "$@"
      fi
    }

    if [[ " $DISTRO_ID $DISTRO_ID_LIKE " == *" arch "* ]] && command -v pacman &>/dev/null; then
      if pacman -Qq ladybird-nightly &>/dev/null; then
        remove_package pacman -R --noconfirm ladybird-nightly
      fi
    elif [[ "$DISTRO_ID" == "ubuntu" ]] && command -v dpkg-query &>/dev/null; then
      for package in ladybird-nightly ladybird; do
        if dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
          remove_package apt-get remove -y "$package"
          break
        fi
      done
    elif [[ "$DISTRO_ID" == "fedora" ]] && command -v rpm &>/dev/null && command -v dnf &>/dev/null; then
      for package in ladybird-nightly ladybird; do
        if rpm -q --quiet "$package"; then
          remove_package dnf remove -y "$package"
          break
        fi
      done
    elif [[ "$DISTRO_ID" == "opensuse-tumbleweed" ]] && command -v rpm &>/dev/null && command -v zypper &>/dev/null; then
      for package in ladybird-nightly ladybird; do
        if rpm -q --quiet "$package"; then
          remove_package zypper --non-interactive remove "$package"
          break
        fi
      done
    fi
  fi

  rm -rf "$DEFAULT_INSTALL_DIR"
  rm -f "$HOME/.local/bin/ladybird" "$HOME/.local/bin/lb"
  rm -f "$HOME/.local/share/applications/ladybird-nightly.desktop"
  rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/ladybird.png"
  echo "Removed local install files."
  echo "Done."
  exit 0
fi

command -v curl &>/dev/null || {
  echo "error: curl is required." >&2
  exit 1
}

OS="$(uname -s)"
ARCH="$(uname -m)"
[[ "$OS" == "Linux" ]] || {
  echo "error: only Linux is supported. Got: $OS" >&2
  exit 1
}
[[ "$ARCH" == "x86_64" ]] || {
  echo "error: only x86_64 is supported. Got: $ARCH" >&2
  exit 1
}
[[ -r /etc/os-release ]] || {
  echo "error: cannot identify this distribution." >&2
  exit 1
}

. /etc/os-release
DISTRO_ID="${ID:-}"
DISTRO_ID_LIKE="${ID_LIKE:-}"
DISTRO_VERSION="${VERSION_ID:-}"
ASSET_PREFIX=""
PACKAGE_EXT=""
PACKAGE_TYPE=""

# asset names are ladybird-nightly-<distro>-x86_64-<date>-<sha>.<ext>, as named by the packages workflow
if [[ "$DISTRO_ID" == "ubuntu" && "$DISTRO_VERSION" == "26.04" ]]; then
  ASSET_PREFIX="ladybird-nightly-ubuntu-26.04-x86_64"
  PACKAGE_EXT="deb"
  PACKAGE_TYPE="deb"
elif [[ "$DISTRO_ID" == "fedora" && "$DISTRO_VERSION" == "44" ]]; then
  ASSET_PREFIX="ladybird-nightly-fedora-44-x86_64"
  PACKAGE_EXT="rpm"
  PACKAGE_TYPE="rpm"
elif [[ "$DISTRO_ID" == "opensuse-tumbleweed" ]]; then
  ASSET_PREFIX="ladybird-nightly-opensuse-tumbleweed-x86_64"
  PACKAGE_EXT="rpm"
  PACKAGE_TYPE="zypper"
elif [[ " $DISTRO_ID $DISTRO_ID_LIKE " == *" arch "* ]]; then
  ASSET_PREFIX="ladybird-nightly-arch-x86_64"
  PACKAGE_EXT="pkg.tar.zst"
  PACKAGE_TYPE="pacman"
else
  echo "error: no Ladybird nightly package is available for $DISTRO_ID ${DISTRO_VERSION}." >&2
  echo "supported: Ubuntu 26.04, Fedora 44, openSUSE Tumbleweed, Arch Linux, and Arch-based distributions." >&2
  exit 1
fi

echo "Looking for a package built for $DISTRO_ID ${DISTRO_VERSION} ..."

# read the release tags from the public atom feed. unlike api.github.com it has no
# 60-requests-per-hour limit per IP, which can causes "403" errors from the API
FEED=$(curl -fsSL "https://github.com/${REPO}/releases.atom") || {
  echo "error: could not fetch the release list from github.com/${REPO}." >&2
  exit 1
}
TAGS=$(echo "$FEED" |
  grep -o 'releases/tag/packages-[0-9]*-[0-9a-f]*' |
  sed 's#releases/tag/##' |
  awk '!seen[$0]++' || true)

[[ -n "$TAGS" ]] || {
  echo "error: no package releases were found." >&2
  echo "The nightly package workflow may not have published one yet." >&2
  exit 1
}

# newest first; use the first release that has a package for this distro
PACKAGE_URL=""
for tag in $TAGS; do
  url="https://github.com/${REPO}/releases/download/${tag}/${ASSET_PREFIX}-${tag#packages-}.${PACKAGE_EXT}"
  # one-byte range request: the signed download links do not accept HEAD requests
  if curl -fsSL -r 0-0 -o /dev/null "$url" 2>/dev/null; then
    PACKAGE_URL="$url"
    break
  fi
done

[[ -n "$PACKAGE_URL" ]] || {
  echo "error: no package for $DISTRO_ID ${DISTRO_VERSION} was found in recent releases." >&2
  exit 1
}

PACKAGE_TMP=$(mktemp -d)
trap 'rm -rf "$PACKAGE_TMP"' EXIT
PACKAGE_FILE="$PACKAGE_TMP/$(basename "$PACKAGE_URL")"
echo "Downloading distro package: $PACKAGE_URL"
curl -fSL --progress-bar -o "$PACKAGE_FILE" "$PACKAGE_URL"

SUDO=()
if [[ "$(id -u)" -ne 0 ]]; then
  command -v sudo &>/dev/null || {
    echo "error: sudo is required to install a distro package." >&2
    exit 1
  }
  SUDO=(sudo)
fi

case "$PACKAGE_TYPE" in
  deb) "${SUDO[@]}" apt-get install -y "$PACKAGE_FILE" ;;
  rpm) "${SUDO[@]}" dnf install -y "$PACKAGE_FILE" ;;
  zypper) "${SUDO[@]}" zypper --non-interactive install --allow-unsigned-rpm "$PACKAGE_FILE" ;;
  pacman) "${SUDO[@]}" pacman -U --noconfirm "$PACKAGE_FILE" ;;
esac

echo "Ladybird nightly installed from the distro package. Run it with: ladybird"
