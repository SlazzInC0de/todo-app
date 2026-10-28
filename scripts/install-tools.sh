#!/usr/bin/env bash
# Installs the lab's command-line tools from their OFFICIAL release downloads into
# /usr/local/bin: kubectl, Helm, kind, OpenTofu and the GitHub CLI (pinned versions).
# Works on Linux, Windows WSL2 and macOS (Intel and Apple Silicon). No Homebrew needed.
# Anything already installed is skipped. Docker, Git and Node.js are installed separately
# (see the session handout's pre-work).
#
#   bash scripts/install-tools.sh
#   DRY_RUN=1 bash scripts/install-tools.sh    # show what would be downloaded
set -euo pipefail

KIND_VERSION="v0.33.0"
TOFU_VERSION="1.13.1"
HELM_VERSION="v3.22.1"
GH_VERSION="2.103.0"
DRY_RUN="${DRY_RUN:-0}"
BIN_DIR="/usr/local/bin"

case "${FORCE_OS:-$(uname -s)}" in
  Linux)  OS=linux ;;
  Darwin) OS=darwin ;;
  *) echo "Unsupported OS: $(uname -s). On Windows, run this inside WSL2 (Ubuntu)." >&2; exit 1 ;;
esac
case "${FORCE_ARCH:-$(uname -m)}" in
  x86_64)        ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {  # URL DEST
  if [ "$DRY_RUN" = "1" ]; then echo "  would download: $1"; return 0; fi
  curl -fsSL --retry 3 -o "$2" "$1"
}
put_bin() {  # SRC NAME
  if [ "$DRY_RUN" = "1" ]; then return 0; fi
  $SUDO mkdir -p "$BIN_DIR"
  $SUDO install -m 0755 "$1" "$BIN_DIR/$2"
  echo "  installed $2"
}
need() {  # NAME -> true if it must be installed
  [ "$DRY_RUN" = "1" ] && return 0
  if command -v "$1" >/dev/null 2>&1; then echo "  $1 already installed"; return 1; fi
  return 0
}

echo "Installing lab tools for ${OS}/${ARCH}"

if need kubectl; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "  would download: https://dl.k8s.io/release/<stable>/bin/${OS}/${ARCH}/kubectl"
  else
    v="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    fetch "https://dl.k8s.io/release/${v}/bin/${OS}/${ARCH}/kubectl" "$TMP/kubectl"
    put_bin "$TMP/kubectl" kubectl
  fi
fi

if need helm; then
  fetch "https://get.helm.sh/helm-${HELM_VERSION}-${OS}-${ARCH}.tar.gz" "$TMP/helm.tgz"
  if [ "$DRY_RUN" != "1" ]; then
    tar -xzf "$TMP/helm.tgz" -C "$TMP"
    put_bin "$TMP/${OS}-${ARCH}/helm" helm
  fi
fi

if need kind; then
  fetch "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-${OS}-${ARCH}" "$TMP/kind"
  put_bin "$TMP/kind" kind
fi

if need tofu; then
  fetch "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_${OS}_${ARCH}.tar.gz" "$TMP/tofu.tgz"
  if [ "$DRY_RUN" != "1" ]; then
    tar -xzf "$TMP/tofu.tgz" -C "$TMP" tofu
    put_bin "$TMP/tofu" tofu
  fi
fi

if need gh; then
  if [ "$OS" = darwin ]; then
    gh_pkg="gh_${GH_VERSION}_macOS_${ARCH}"
    fetch "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${gh_pkg}.zip" "$TMP/gh.zip"
    [ "$DRY_RUN" = "1" ] || unzip -q "$TMP/gh.zip" -d "$TMP"
  else
    gh_pkg="gh_${GH_VERSION}_linux_${ARCH}"
    fetch "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${gh_pkg}.tar.gz" "$TMP/gh.tgz"
    [ "$DRY_RUN" = "1" ] || tar -xzf "$TMP/gh.tgz" -C "$TMP"
  fi
  put_bin "$TMP/${gh_pkg}/bin/gh" gh
fi

[ "$DRY_RUN" = "1" ] && exit 0

echo
kubectl version --client 2>/dev/null | head -1
helm version --short
kind version
tofu version | head -1
gh --version | head -1
echo
echo "Next: sign in to GitHub so git push works (the 'workflow' scope is required for Block 2):"
echo "  gh auth login --scopes workflow && gh auth setup-git"
