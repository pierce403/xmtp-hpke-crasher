#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[add-instrumentation] Enabling local libxmtp instrumentation..."

if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo (Rust) is not installed; cannot build local @xmtp/node-bindings" >&2
  exit 1
fi

if ! command -v yarn >/dev/null 2>&1; then
  echo "error: yarn is not installed; cannot build local @xmtp/node-bindings" >&2
  exit 1
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

