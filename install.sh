#!/usr/bin/env bash

# usage: curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash
# or:    curl -fsSL ... | bash -s -- --dir /custom/path
#
# flags:
#   --dir <path>     custom install directory (default is: ~/.local/ladybird-nightly)
#   --tarball        force the distro-independent tarball instead of a distro package
#   --uninstall      remove Ladybird nightly and installed files
#   --help, -h       show usage

set -euo pipefail

REPO="harilvfs/ladybird-nightly"
DEFAULT_INSTALL_DIR="$HOME/.local/ladybird-nightly"

INSTALL_DIR="$DEFAULT_INSTALL_DIR"
FORCE_TARBALL=0
UNINSTALL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --dir=*)
      INSTALL_DIR="${1#--dir=}"
      shift
      ;;
    --tarball)
      FORCE_TARBALL=1
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    --help | -h)
      echo "Usage: install.sh [--dir <path>] [--tarball]"
      echo "  --dir         where to install Ladybird (default: $DEFAULT_INSTALL_DIR)"
      echo "  --tarball     force the distro-independent tarball"
      echo "  --uninstall   remove Ladybird nightly and installed files"
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

  rm -rf "$INSTALL_DIR"
  rm -f "$HOME/.local/bin/ladybird" "$HOME/.local/bin/lb"
  rm -f "$HOME/.local/share/applications/ladybird-nightly.desktop"
  rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/ladybird.png"
  echo "Removed $INSTALL_DIR and tarball installer files."
  echo "Done."
  exit 0
fi

command -v curl &>/dev/null || {
  echo "error: curl not found, please install it first." >&2
  exit 1
}
command -v tar &>/dev/null || {
  echo "error: tar not found, please install it first." >&2
  exit 1
}
command -v jq &>/dev/null || {
  echo "error: jq not found, please install it first." >&2
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

if ! ldconfig -p 2>/dev/null | grep -q libQt6Core; then
  echo "warning: Qt6 runtime libraries may not be installed."
  echo "If Ladybird fails to start, install them with:"
  echo "  Ubuntu:        sudo apt install qt6-base-dev"
  echo "  Arch:          sudo pacman -S qt6-base"
  echo "  Fedora:        sudo dnf install qt6-qtbase"
fi

# use packages only on supported distro releases
if [[ "$FORCE_TARBALL" -eq 0 && -r /etc/os-release ]]; then
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
  fi

  if [[ -n "$PACKAGE_PATTERN" ]]; then
    echo "Looking for a package built for $DISTRO_ID ${DISTRO_VERSION} ..."
    PACKAGE_URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases?per_page=30" |
      jq -r --arg re "$PACKAGE_PATTERN" '[.[] | .assets[] | select(.name | test($re)) | .browser_download_url][0] // empty' || true)

    if [[ -n "$PACKAGE_URL" ]]; then
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
      exit 0
    fi
    echo "No matching distro package was found; falling back to the tarball."
  fi
fi

echo "Fetching latest release info from github.com/$REPO ..."

RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name')

[[ -z "$TAG" || "$TAG" == "null" ]] && {
  echo "error: no release found in $REPO. The CI has not built one yet." >&2
  exit 1
}

echo "Latest release: $TAG"

ASSET_URL=$(echo "$RELEASE_JSON" |
  jq -r '.assets[] | select(.name | test("linux-x86_64.*\\.tar\\.gz")) | .browser_download_url' |
  head -1)

[[ -n "$ASSET_URL" ]] || {
  echo "error: no Linux x86_64 tarball found in release $TAG" >&2
  exit 1
}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

TARBALL="$TMP_DIR/ladybird.tar.gz"
echo "Downloading from: $ASSET_URL"
curl -fSL --progress-bar -o "$TARBALL" "$ASSET_URL"
echo "Download complete."

echo "Extracting to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
tar -xzf "$TARBALL" -C "$INSTALL_DIR" --strip-components=1
echo "Extracted."

LAUNCHER="$INSTALL_DIR/run-ladybird.sh"
[[ -f "$LAUNCHER" ]] || {
  echo "error: launcher script not found at $LAUNCHER package may be not work properly." >&2
  exit 1
}
chmod +x "$LAUNCHER"

SANDBOX_CERT="/etc/ssl/ladybird-ca-bundle.crt"
NEED_SANDBOX_CERT=false

# landlock needs a real cert file under /etc/ssl
NEED_SANDBOX_CERT=true
for cert_path in /etc/ssl/cert.pem /etc/ssl/certs/ca-certificates.crt; do
  if [[ -f "$cert_path" && ! -L "$cert_path" ]]; then
    NEED_SANDBOX_CERT=false
    break
  fi
done

if $NEED_SANDBOX_CERT; then
  if [[ -w /etc/ssl/ ]] 2>/dev/null || sudo -n true 2>/dev/null; then
    echo "Installing SSL cert bundle for Landlock sandbox..."
    sudo cp "$INSTALL_DIR/ca-bundle-sandbox.crt" "$SANDBOX_CERT"
    echo "Installed: $SANDBOX_CERT"
  elif command -v sudo &>/dev/null; then
    echo ""
    echo "HTTPS requires a real cert file under /etc/ssl/ for the Ladybird sandbox."
    echo "Please enter your password to install it:"
    sudo cp "$INSTALL_DIR/ca-bundle-sandbox.crt" "$SANDBOX_CERT"
    echo "Installed: $SANDBOX_CERT"
  else
    echo ""
    echo "warning: could not install SSL cert for Ladybird sandbox (no sudo)."
    echo "HTTPS sites may not load. To fix manually, run:"
    echo "  sudo cp '$INSTALL_DIR/ca-bundle-sandbox.crt' '$SANDBOX_CERT'"
  fi
fi

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$LAUNCHER" "$LOCAL_BIN/ladybird"
echo "Symlinked: $LOCAL_BIN/ladybird -> $LAUNCHER"

# lb hides terminal output
ln -sf "$LAUNCHER" "$LOCAL_BIN/lb"
echo "Symlinked: $LOCAL_BIN/lb -> $LAUNCHER"

# install the icon before writing the desktop entry
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
mkdir -p "$ICON_DIR"
ICON_URL="https://raw.githubusercontent.com/$REPO/main/icons/ladybird.png"
if curl -fsSL -o "$ICON_DIR/ladybird.png" "$ICON_URL"; then
  echo "Installed: $ICON_DIR/ladybird.png"
else
  echo "warning: could not download ladybird icon. Desktop entry may show a generic icon."
fi

# rofi desktop entry
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
cat >"$DESKTOP_DIR/ladybird-nightly.desktop" <<EOF
[Desktop Entry]
Name=Ladybird (Nightly)
Comment=Truly independent web browser
Exec="$LAUNCHER" %u
TryExec="$LAUNCHER"
Icon=$ICON_DIR/ladybird.png
Type=Application
Categories=Network;WebBrowser;
Terminal=false
StartupWMClass=Ladybird
EOF
echo "Installed: $DESKTOP_DIR/ladybird-nightly.desktop"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
  echo ""
  echo "warning: $LOCAL_BIN is not in your PATH."
  echo "Add this to your shell config:"
  echo "  bash ~/.bashrc or zsh ~/.zshrc:"
  echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo "  fish ~/.config/fish/config.fish:"
  echo "    set -gx PATH \$HOME/.local/bin \$PATH"
  echo ""
  echo "Then restart your shell."
fi

echo ""
echo "Ladybird nightly installed!"
echo "Build info: $(cat "$INSTALL_DIR/BUILD_INFO" 2>/dev/null | head -3 || echo 'N/A')"
echo ""
echo "Run it with:  ladybird or lb"
echo "Or directly: $LAUNCHER"
echo ""
echo "Deprecated: theme environment overrides are no longer needed. Set appearance in Ladybird's settings."
echo "Legacy Qt theme overrides for older builds:"
echo "  bash ~/.bashrc or zsh ~/.zshrc:"
echo '    export QT_QPA_PLATFORMTHEME=qt6ct'
echo '    export QT_STYLE_OVERRIDE=kvantum'
echo "  fish ~/.config/fish/config.fish:"
echo "    set -gx QT_QPA_PLATFORMTHEME qt6ct"
echo "    set -gx QT_STYLE_OVERRIDE kvantum"
echo ""
echo "Warning: this unofficial Ladybird nightly may have issues. Use at your own risk."
