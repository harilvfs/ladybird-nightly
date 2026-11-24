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
command -v jq &>/dev/null || {
  echo "error: jq is required." >&2
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
PACKAGE_PATTERN=""
PACKAGE_TYPE=""

if [[ "$DISTRO_ID" == "ubuntu" && "$DISTRO_VERSION" == "26.04" ]]; then
  PACKAGE_PATTERN='ubuntu-26\.04-x86_64.*\.deb$'
  PACKAGE_TYPE="deb"
elif [[ "$DISTRO_ID" == "fedora" && "$DISTRO_VERSION" == "44" ]]; then
  PACKAGE_PATTERN='fedora-44-x86_64.*\.rpm$'
  PACKAGE_TYPE="rpm"
elif [[ " $DISTRO_ID $DISTRO_ID_LIKE " == *" arch "* ]]; then
  PACKAGE_PATTERN='arch-x86_64.*\.pkg\.tar\.zst$'
  PACKAGE_TYPE="pacman"
else
  echo "error: no Ladybird nightly package is available for $DISTRO_ID ${DISTRO_VERSION}." >&2
  echo "supported: Ubuntu 26.04, Fedora 44, Arch Linux, and Arch-based distributions." >&2
  exit 1
fi

echo "Looking for a package built for $DISTRO_ID ${DISTRO_VERSION} ..."
RELEASES_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases?per_page=30") || {
  echo "error: could not fetch package release information." >&2
  exit 1
}
PACKAGE_URL=$(echo "$RELEASES_JSON" |
  jq -r --arg re "$PACKAGE_PATTERN" '[.[] | .assets[] | select(.name | test($re)) | .browser_download_url][0] // empty')

[[ -n "$PACKAGE_URL" ]] || {
  echo "error: no matching distro package was found in recent releases." >&2
  echo "The nightly package workflow may not have published one yet." >&2
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
  pacman) "${SUDO[@]}" pacman -U --noconfirm "$PACKAGE_FILE" ;;
esac

echo "Ladybird nightly installed from the distro package. Run it with: ladybird"
