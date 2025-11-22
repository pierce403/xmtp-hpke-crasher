#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[add-instrumentation] Enabling local libxmtp instrumentation..."

if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo (Rust) is not installed; cannot build local @xmtp/node-bindings" >&2
  echo "hint: on Debian/Ubuntu you can run:" >&2
  echo "  sudo apt update && sudo apt install -y cargo rustc build-essential pkg-config libssl-dev" >&2
  echo "or install via rustup (recommended): https://rustup.rs" >&2
  exit 1
fi

if ! command -v yarn >/dev/null 2>&1; then
  echo "[add-instrumentation] yarn not found; attempting to install globally via npm..." >&2
  if command -v npm >/dev/null 2>&1; then
    if npm install -g yarn; then
      echo "[add-instrumentation] yarn installed successfully." >&2
    else
      echo "error: failed to install yarn with 'npm install -g yarn'" >&2
      echo "hint: you may need to re-run with sudo, e.g.:" >&2
      echo "  sudo npm install -g yarn" >&2
      echo "or on Node 18+: enable corepack and use yarn:" >&2
      echo "  corepack enable && corepack prepare yarn@stable --activate" >&2
      exit 1
    fi
  else
    echo "error: yarn is not installed and npm is not available to install it" >&2
    echo "hint: install Node.js and npm first, then either:" >&2
    echo "  npm install -g yarn" >&2
    echo "or on Node 18+: enable corepack and use yarn:" >&2
    echo "  corepack enable && corepack prepare yarn@stable --activate" >&2
    exit 1
  fi
fi

LIBXMTP_DIR="${ROOT_DIR}/libxmtp"

if [ ! -d "${LIBXMTP_DIR}" ] || [ ! -d "${LIBXMTP_DIR}/bindings_node" ]; then
  echo "[add-instrumentation] libxmtp not found locally; fetching it..." >&2
  if command -v git >/dev/null 2>&1; then
    if [ -f "${ROOT_DIR}/.gitmodules" ] && git -C "${ROOT_DIR}" config -f .gitmodules --get-regexp '^submodule\.libxmtp\.' >/dev/null 2>&1; then
      echo "[add-instrumentation] Initializing libxmtp git submodule..." >&2
      git -C "${ROOT_DIR}" submodule update --init --recursive libxmtp
    fi
    if [ ! -d "${LIBXMTP_DIR}/bindings_node" ]; then
      echo "[add-instrumentation] Cloning libxmtp repository into ./libxmtp..." >&2
      git -C "${ROOT_DIR}" clone https://github.com/xmtp/libxmtp.git libxmtp
    fi
  else
    echo "error: libxmtp directory is missing and git is not installed, cannot fetch libxmtp" >&2
    echo "hint: install git (e.g. 'sudo apt install -y git') and re-run this script" >&2
    exit 1
  fi
fi

echo "[add-instrumentation] Building @xmtp/node-bindings from vendored libxmtp..."
pushd "${ROOT_DIR}/libxmtp/bindings_node" >/dev/null
yarn install
yarn build:clean
yarn build:test
yarn build:finish

echo "[add-instrumentation] Ensuring dist/version.json exists..."
mkdir -p dist
cat > dist/version.json <<'EOF'
{
  "branch": "instrumented-local",
  "version": "1.7.0-dev",
  "date": "1970-01-01T00:00:00Z"
}
EOF
popd >/dev/null

echo "[add-instrumentation] Wiring Node to use local @xmtp/node-bindings..."
mkdir -p "${ROOT_DIR}/node_modules/@xmtp"

UPSTREAM_DIR="${ROOT_DIR}/node_modules/@xmtp/node-bindings"
if [ -e "${UPSTREAM_DIR}" ] && [ ! -L "${UPSTREAM_DIR}" ] && [ ! -e "${UPSTREAM_DIR}.upstream" ]; then
  mv "${UPSTREAM_DIR}" "${UPSTREAM_DIR}.upstream"
fi

rm -f "${UPSTREAM_DIR}"
ln -s ../../libxmtp/bindings_node "${UPSTREAM_DIR}"

NODE_SDK_DIST="${ROOT_DIR}/node_modules/@xmtp/node-sdk/dist/index.js"

if [ -f "${NODE_SDK_DIST}" ] && [ ! -f "${NODE_SDK_DIST}.upstream" ]; then
  cp "${NODE_SDK_DIST}" "${NODE_SDK_DIST}.upstream"
fi

echo "[add-instrumentation] Patching @xmtp/node-sdk for new bindings signatures..."
if [ -f "${NODE_SDK_DIST}" ]; then
  perl -i -pe 's/getInboxIdForIdentifier\$1\(host, isSecure, identifier\);/getInboxIdForIdentifier\$1(host, undefined, isSecure, identifier);/' "${NODE_SDK_DIST}" || true
  perl -0pi -e 's/return createClient\$1\(host, isSecure, dbPath, inboxId, identifier, dbEncryptionKey, historySyncUrl, deviceSyncWorkerMode, logOptions, undefined, options\?\.debugEventsEnabled, options\?\.appVersion\);/\/\/ patched for local bindings\n    return createClient\$1(host, undefined, isSecure, dbPath, inboxId, identifier, dbEncryptionKey, historySyncUrl, deviceSyncWorkerMode, logOptions, undefined, options?.debugEventsEnabled, options?.appVersion, undefined, undefined, undefined, undefined);/' "${NODE_SDK_DIST}" || true
fi

echo "[add-instrumentation] Done. Now run, for example:"
echo "  ./run.sh --recv"
