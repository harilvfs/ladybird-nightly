#!/usr/bin/env bash

# usage: curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash
# flatpak:   curl -fsSL ... | bash -s -- --flatpak
# uninstall: curl -fsSL ... | bash -s -- --uninstall

set -euo pipefail

REPO="harilvfs/ladybird-nightly"
DEFAULT_INSTALL_DIR="$HOME/.local/ladybird-nightly"
UNINSTALL=0
FORCE_FLATPAK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    --flatpak)
      FORCE_FLATPAK=1
      shift
      ;;
    --help | -h)
      echo "Usage: install.sh [--flatpak] [--uninstall]"
      echo "  --flatpak     install the Flatpak instead of the package for this distro"
      echo "  --uninstall   remove the distro package, the Flatpak and local install files"
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

  # the installer puts the Flatpak in the user installation
  if command -v flatpak &>/dev/null && flatpak info --user org.ladybird.Ladybird &>/dev/null; then
    flatpak uninstall --user --noninteractive -y org.ladybird.Ladybird
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

DISTRO_ID=""
DISTRO_ID_LIKE=""
DISTRO_VERSION=""
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  DISTRO_ID="${ID:-}"
  DISTRO_ID_LIKE="${ID_LIKE:-}"
  DISTRO_VERSION="${VERSION_ID:-}"
fi

NATIVE_PREFIX=""
NATIVE_EXT=""
NATIVE_TYPE=""

# asset names are ladybird-nightly-<distro>-x86_64-<date>-<sha>.<ext>, as named by the packages workflow
if [[ "$DISTRO_ID" == "ubuntu" && "$DISTRO_VERSION" == "26.04" ]]; then
  NATIVE_PREFIX="ladybird-nightly-ubuntu-26.04-x86_64"
  NATIVE_EXT="deb"
  NATIVE_TYPE="deb"
elif [[ "$DISTRO_ID" == "fedora" && "$DISTRO_VERSION" == "44" ]]; then
  NATIVE_PREFIX="ladybird-nightly-fedora-44-x86_64"
  NATIVE_EXT="rpm"
  NATIVE_TYPE="rpm"
elif [[ "$DISTRO_ID" == "opensuse-tumbleweed" ]]; then
  NATIVE_PREFIX="ladybird-nightly-opensuse-tumbleweed-x86_64"
  NATIVE_EXT="rpm"
  NATIVE_TYPE="zypper"
elif [[ " $DISTRO_ID $DISTRO_ID_LIKE " == *" arch "* ]]; then
  NATIVE_PREFIX="ladybird-nightly-arch-x86_64"
  NATIVE_EXT="pkg.tar.zst"
  NATIVE_TYPE="pacman"
fi

if [[ "$FORCE_FLATPAK" -eq 1 ]]; then
  echo "Installing the Flatpak as requested."
elif [[ -z "$NATIVE_PREFIX" ]]; then
  echo "No native package for ${DISTRO_ID:-this distro} ${DISTRO_VERSION}, using the Flatpak instead."
else
  echo "Looking for a package built for $DISTRO_ID ${DISTRO_VERSION} ..."
fi

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

PACKAGE_URL=""
PACKAGE_TYPE=""

# newest first; use the first release that has a package for this distro
if [[ "$FORCE_FLATPAK" -eq 0 && -n "$NATIVE_PREFIX" ]]; then
  for tag in $TAGS; do
    url="https://github.com/${REPO}/releases/download/${tag}/${NATIVE_PREFIX}-${tag#packages-}.${NATIVE_EXT}"
    # one-byte range request: the signed download links do not accept HEAD requests
    if curl -fsSL -r 0-0 -o /dev/null "$url" 2>/dev/null; then
      PACKAGE_URL="$url"
      PACKAGE_TYPE="$NATIVE_TYPE"
      break
    fi
  done
  if [[ -z "$PACKAGE_URL" ]]; then
    echo "No native package found in recent releases, trying the Flatpak."
  fi
fi

# the Flatpak works on any distro, so it is also the fallback
if [[ -z "$PACKAGE_URL" ]]; then
  for tag in $TAGS; do
    url="https://github.com/${REPO}/releases/download/${tag}/ladybird-nightly-flatpak-x86_64-${tag#packages-}.flatpak"
    if curl -fsSL -r 0-0 -o /dev/null "$url" 2>/dev/null; then
      PACKAGE_URL="$url"
      PACKAGE_TYPE="flatpak"
      break
    fi
  done
fi

[[ -n "$PACKAGE_URL" ]] || {
  echo "error: no Ladybird nightly package was found in recent releases." >&2
  echo "The build for your distro may have failed, try again later." >&2
  exit 1
}

if [[ "$PACKAGE_TYPE" == "flatpak" ]]; then
  command -v flatpak &>/dev/null || {
    echo "error: this install needs Flatpak, which is not installed." >&2
    echo "Install it first: https://flatpak.org/setup/" >&2
    exit 1
  }
fi

PACKAGE_TMP=$(mktemp -d)
trap 'rm -rf "$PACKAGE_TMP"' EXIT
PACKAGE_FILE="$PACKAGE_TMP/$(basename "$PACKAGE_URL")"
echo "Downloading: $PACKAGE_URL"
curl -fSL --progress-bar -o "$PACKAGE_FILE" "$PACKAGE_URL"

# the Flatpak goes into the user installation, so only the distro packages need root
SUDO=()
if [[ "$PACKAGE_TYPE" != "flatpak" && "$(id -u)" -ne 0 ]]; then
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
  flatpak)
    # the bundle needs the KDE runtime from Flathub
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --user --noninteractive -y "$PACKAGE_FILE"
    ;;
esac

if [[ "$PACKAGE_TYPE" == "flatpak" ]]; then
  echo "Ladybird nightly installed as a Flatpak. Run it with: flatpak run org.ladybird.Ladybird"
else
  echo "Ladybird nightly installed from the distro package. Run it with: ladybird"
fi
