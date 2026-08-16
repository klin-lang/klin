#!/usr/bin/env bash
# Install Klin on Linux from the latest GitHub Release tarball (issue 131).
# No Homebrew / apt / snap. Layout matches discovery in lib/project.dart:
# binary + stdlib/ + templates/ in one directory (symlink into PATH).
set -euo pipefail

REPO="${KLIN_INSTALL_REPO:-klin-lang/klin}"
PREFIX="${KLIN_PREFIX:-$HOME/.local}"
LIBDIR="${PREFIX}/lib/klin"
BINDIR="${PREFIX}/bin"
BASE="https://github.com/${REPO}/releases/latest/download"

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) asset="klin-linux-amd64" ;;
  aarch64|arm64) asset="klin-linux-arm64" ;;
  *)
    echo "unsupported arch: $arch (need x86_64 or aarch64)" >&2
    exit 1
    ;;
esac

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

echo "downloading ${asset}.tar.gz …"
curl -fsSL -o "${tmpdir}/${asset}.tar.gz" "${BASE}/${asset}.tar.gz"
curl -fsSL -o "${tmpdir}/${asset}.sha256" "${BASE}/${asset}.sha256"

(
  cd "$tmpdir"
  sha256sum -c "${asset}.sha256"
  tar -xzf "${asset}.tar.gz"
)

mkdir -p "$LIBDIR" "$BINDIR"
# Replace previous install contents (keep LIBDIR itself).
rm -rf "${LIBDIR}/stdlib" "${LIBDIR}/templates" "${LIBDIR}/klin"
cp -a "${tmpdir}/klin" "${tmpdir}/stdlib" "${tmpdir}/templates" "$LIBDIR/"

ln -sfn "${LIBDIR}/klin" "${BINDIR}/klin"

echo "installed: ${BINDIR}/klin -> ${LIBDIR}/klin"
echo "stdlib/ + templates/ live beside the binary under ${LIBDIR}"
if ! command -v klin >/dev/null 2>&1; then
  echo "add to PATH: export PATH=\"${BINDIR}:\$PATH\"" >&2
fi
"${BINDIR}/klin" --version
echo "note: klin run needs gcc or clang on PATH; --emit-c does not"
echo "note: there is no apt / .deb / snap package yet"
