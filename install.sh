#!/usr/bin/env bash

# usage: curl -fsSL https://raw.githubusercontent.com/harilvfs/ladybird-nightly/main/install.sh | bash
# or:    curl -fsSL ... | bash -s -- --dir /custom/path
#
# flags:
#   --dir <path>     custom install directory (default: ~/.local/ladybird-nightly)
#   --uninstall      remove Ladybird nightly and the symlink
#   --help, -h       show usage information

set -euo pipefail

REPO="harilvfs/ladybird-nightly"
DEFAULT_INSTALL_DIR="$HOME/.local/ladybird-nightly"

INSTALL_DIR="$DEFAULT_INSTALL_DIR"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --dir=*) INSTALL_DIR="${1#--dir=}"; shift ;;
    --uninstall)
      echo "Uninstalling Ladybird nightly..."
      rm -rf "$INSTALL_DIR"
      rm -f "$HOME/.local/bin/ladybird"
      echo "Removed $INSTALL_DIR"
      echo "Removed $HOME/.local/bin/ladybird"
      echo "Done."
      exit 0
      ;;
    --help|-h)
      echo "Usage: install.sh [--dir <path>]"
      echo "  --dir         where to install Ladybird (default: $DEFAULT_INSTALL_DIR)"
      echo "  --uninstall   remove Ladybird nightly and the symlink"
      exit 0
      ;;
    *) echo "error: unknown argument: $1" >&2; echo "Run with --help for usage." >&2; exit 1 ;;
  esac
done

command -v curl &>/dev/null || { echo "error: curl not found, please install it first." >&2; exit 1; }
command -v tar  &>/dev/null || { echo "error: tar not found, please install it first." >&2; exit 1; }
command -v jq   &>/dev/null || { echo "error: jq not found, please install it first." >&2; exit 1; }

OS="$(uname -s)"
ARCH="$(uname -m)"
[[ "$OS" == "Linux" ]]    || { echo "error: only Linux is supported. Got: $OS" >&2; exit 1; }
[[ "$ARCH" == "x86_64" ]] || { echo "error: only x86_64 is supported. Got: $ARCH" >&2; exit 1; }

if ! ldconfig -p 2>/dev/null | grep -q libQt6Core; then
  echo "warning: Qt6 runtime libraries may not be installed."
  echo "If Ladybird fails to start, install them with:"
  echo "  Ubuntu/Debian: sudo apt install qt6-base-dev"
  echo "  Arch:          sudo pacman -S qt6-base"
  echo "  Fedora:        sudo dnf install qt6-qtbase"
fi

echo "Fetching latest release info from github.com/$REPO ..."

RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name')

[[ -z "$TAG" || "$TAG" == "null" ]] && { echo "error: no release found in $REPO. The CI has not built one yet." >&2; exit 1; }

echo "Latest release: $TAG"

ASSET_URL=$(echo "$RELEASE_JSON" \
  | jq -r '.assets[] | select(.name | test("linux-x86_64.*\\.tar\\.gz")) | .browser_download_url' \
  | head -1)

[[ -n "$ASSET_URL" ]] || { echo "error: no Linux x86_64 tarball found in release $TAG" >&2; exit 1; }

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
[[ -f "$LAUNCHER" ]] || { echo "error: launcher script not found at $LAUNCHER package may be not work properly." >&2; exit 1; }
chmod +x "$LAUNCHER"

SANDBOX_CERT="/etc/ssl/ladybird-ca-bundle.crt"
NEED_SANDBOX_CERT=false

# Ladybird's Landlock sandbox only allows /etc/ssl for certs.
# if the system's cert files are symlinks to /etc/ca-certificates/
# (Arch, openSUSE, NixOS) or don't exist, HTTPS will fail silently.
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

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$LOCAL_BIN"; then
  echo ""
  echo "warning: $LOCAL_BIN is not in your PATH."
  echo "Add this to your shell config (~/.bashrc, ~/.zshrc, etc.):"
  echo '  export PATH="$HOME/.local/bin:$PATH"'
  echo "Then restart your shell or run: source ~/.bashrc"
fi

echo ""
echo "Ladybird nightly installed!"
echo "Build info: $(cat "$INSTALL_DIR/BUILD_INFO" 2>/dev/null | head -3 || echo 'N/A')"
echo ""
echo "Run it with:  ladybird"
echo "Or directly: $LAUNCHER"
echo ""
echo "Note: this is pre-alpha software not ready for production usecase expect crashes and missing features."
