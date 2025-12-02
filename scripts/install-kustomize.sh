#!/usr/bin/env bash
set -euo pipefail

VERSION="${KUSTOMIZE_VERSION:-5.4.2}"
OS="linux"
ARCH="amd64"
INSTALL_DIR="${INSTALL_DIR:-./bin}"

mkdir -p "${INSTALL_DIR}"
TARGET="${INSTALL_DIR}/kustomize"

if [[ -x "${TARGET}" ]]; then
  current_version="$(${TARGET} version --short 2>/dev/null | head -n1 | sed 's/kustomize\///')"
  if [[ "${current_version}" == "v${VERSION}" || "${current_version}" == "${VERSION}" ]]; then
    echo "kustomize v${VERSION} already installed at ${TARGET}" >&2
    exit 0
  fi
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

url="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${VERSION}/kustomize_v${VERSION}_${OS}_${ARCH}.tar.gz"
echo "Downloading kustomize v${VERSION} from ${url}" >&2
curl -sSL "${url}" | tar -C "${tmpdir}" -xz
mv "${tmpdir}/kustomize" "${TARGET}"
chmod +x "${TARGET}"

echo "Installed $("${TARGET}" version --short) to ${TARGET}" >&2
