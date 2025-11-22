#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[remove-instrumentation] Disabling local libxmtp instrumentation..."

UPSTREAM_BINDINGS="${ROOT_DIR}/node_modules/@xmtp/node-bindings.upstream"
CURRENT_BINDINGS="${ROOT_DIR}/node_modules/@xmtp/node-bindings"

if [ -L "${CURRENT_BINDINGS}" ]; then
  rm -f "${CURRENT_BINDINGS}"
fi

if [ -d "${UPSTREAM_BINDINGS}" ] && [ ! -e "${CURRENT_BINDINGS}" ]; then
  mv "${UPSTREAM_BINDINGS}" "${CURRENT_BINDINGS}"
fi

NODE_SDK_DIST="${ROOT_DIR}/node_modules/@xmtp/node-sdk/dist/index.js"
if [ -f "${NODE_SDK_DIST}.upstream" ]; then
  mv "${NODE_SDK_DIST}.upstream" "${NODE_SDK_DIST}"
fi

echo "[remove-instrumentation] Done. The repo now uses published XMTP packages again."

