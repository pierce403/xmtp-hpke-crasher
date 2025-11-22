#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo (Rust) is not installed; skipping local @xmtp/node-bindings build" >&2
  echo "hint: install Rust from https://rustup.rs if you want deep HPKE instrumentation" >&2
  exit 1
fi

if ! command -v yarn >/dev/null 2>&1; then
  echo "error: yarn is not installed; skipping local @xmtp/node-bindings build" >&2
  echo "hint: install yarn (e.g. 'npm install -g yarn') if you want deep HPKE instrumentation" >&2
  exit 1
fi

echo "[use-local-node-bindings] Building @xmtp/node-bindings from vendored libxmtp..."
pushd "${ROOT_DIR}/libxmtp/bindings_node" >/dev/null
yarn install
yarn build:clean
yarn build:test
yarn build:finish

echo "[use-local-node-bindings] Generating dist/version.json for node-sdk..."
mkdir -p dist
cat > dist/version.json <<'EOF'
{
  "branch": "instrumented-local",
  "version": "1.7.0-dev",
  "date": "1970-01-01T00:00:00Z"
}
EOF

popd >/dev/null

echo "[use-local-node-bindings] Wiring Node to use local bindings..."
mkdir -p "${ROOT_DIR}/node_modules/@xmtp"

UPSTREAM_DIR="${ROOT_DIR}/node_modules/@xmtp/node-bindings"
if [ -e "${UPSTREAM_DIR}" ] && [ ! -L "${UPSTREAM_DIR}" ]; then
  mv "${UPSTREAM_DIR}" "${UPSTREAM_DIR}.upstream"
fi

rm -f "${UPSTREAM_DIR}"
ln -s ../../libxmtp/bindings_node "${UPSTREAM_DIR}"

echo "[use-local-node-bindings] Patching @xmtp/node-sdk to use new getInboxIdForIdentifier signature..."
NODE_SDK_DIST="${ROOT_DIR}/node_modules/@xmtp/node-sdk/dist/index.js"
if [ -f "${NODE_SDK_DIST}" ]; then
  perl -i -pe 's/getInboxIdForIdentifier\$1\(host, isSecure, identifier\);/getInboxIdForIdentifier\$1(host, undefined, isSecure, identifier);/' "${NODE_SDK_DIST}" || true
fi

echo "[use-local-node-bindings] Done."
echo "Next run your usual repro, e.g.:"
echo "  ./run.sh --recv"
