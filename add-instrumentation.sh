#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[add-instrumentation] Enabling local libxmtp instrumentation..."

ensure_modern_rust() {
  # Require a cargo new enough to support edition 2024 (Rust 1.81+).
  local required="1.81.0"

  if command -v cargo >/dev/null 2>&1; then
    local version
    version="$(cargo --version 2>/dev/null | awk '{print $2}')"
    if [ -n "${version}" ]; then
      # If version >= required, we're good.
      if printf '%s\n%s\n' "$required" "$version" | sort -V | head -n1 | grep -qx "$required"; then
        return 0
      fi
    fi
  fi

  echo "[add-instrumentation] Installing/updating Rust toolchain via rustup..." >&2

  if ! command -v rustup >/dev/null 2>&1; then
    if command -v curl >/dev/null 2>&1; then
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || {
        echo "error: failed to install rustup via curl" >&2
        echo "hint: see https://rustup.rs for manual installation instructions" >&2
        exit 1
      }
    elif command -v wget >/dev/null 2>&1; then
      wget -qO- https://sh.rustup.rs | sh -s -- -y || {
        echo "error: failed to install rustup via wget" >&2
        echo "hint: see https://rustup.rs for manual installation instructions" >&2
        exit 1
      }
    else
      echo "error: cargo is too old and neither curl nor wget is available to install rustup" >&2
      echo "hint: install curl or wget, then re-run this script, or install Rust manually from https://rustup.rs" >&2
      exit 1
    fi
  fi

  if [ -f "${HOME}/.cargo/env" ]; then
    # shellcheck disable=SC1090
    . "${HOME}/.cargo/env"
  fi
  export PATH="${HOME}/.cargo/bin:${PATH}"

  rustup install stable >/dev/null 2>&1 || rustup update stable >/dev/null 2>&1 || true

  if ! command -v cargo >/dev/null 2>&1; then
    echo "error: cargo is still not available after rustup installation" >&2
    exit 1
  fi

  local new_version
  new_version="$(cargo --version 2>/dev/null | awk '{print $2}')"
  if [ -n "${new_version}" ]; then
    if ! printf '%s\n%s\n' "$required" "$new_version" | sort -V | head -n1 | grep -qx "$required"; then
      echo "error: cargo ${new_version} is still too old; need at least ${required} for edition 2024" >&2
      echo "hint: run 'rustup update stable' manually and re-run this script" >&2
      exit 1
    fi
  fi
}

ensure_python() {
  if command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
    return
  fi
  if command -v python >/dev/null 2>&1; then
    PYTHON=python
    return
  fi
  echo "error: python3 is not installed; cannot apply HPKE instrumentation patch" >&2
  echo "hint: on Ubuntu/Debian you can run:" >&2
  echo "  sudo apt update && sudo apt install -y python3" >&2
  exit 1
}

ensure_modern_rust
ensure_python
apply_hpke_instrumentation_patch() {
  local file="${LIBXMTP_DIR}/xmtp_mls/src/groups/mls_ext/welcome_wrapper.rs"
  if [ ! -f "${file}" ]; then
    echo "[add-instrumentation] welcome_wrapper.rs not found, skipping HPKE patch" >&2
    return
  fi

  if grep -q "HPKE unwrap_welcome starting (instrumented v2)" "${file}"; then
    echo "[add-instrumentation] HPKE instrumentation already applied" >&2
    return
  fi

  echo "[add-instrumentation] Patching HPKE instrumentation into welcome_wrapper.rs..." >&2
  "${PYTHON}" - "${file}" <<'PY'
import sys
path = sys.argv[1]
text = open(path, "r").read()

if "HPKE unwrap_welcome starting (instrumented v2)" in text:
    sys.exit(0)

if "use hex;" not in text:
    text = text.replace(
        "use thiserror::Error;\nuse tls_codec",
        "use thiserror::Error;\nuse hex;\nuse tls_codec",
        1,
    )

text = text.replace(
"""    error!(
        wrapped_welcome_len = wrapped_welcome.len(),
        wrapped_welcome_metadata_len = wrapped_welcome_metadata.len(),
        private_key_len = private_key.len(),
        wrapper_algorithm = ?wrapper_algorithm,
        "HPKE unwrap_welcome starting"
    );""",
"""    let wrapped_welcome_hex = hex::encode(wrapped_welcome);
    let wrapped_welcome_metadata_hex = hex::encode(wrapped_welcome_metadata);
    let private_key_prefix_hex = hex::encode(&private_key[..private_key.len().min(16)]);
    error!(
        wrapped_welcome_len = wrapped_welcome.len(),
        wrapped_welcome_metadata_len = wrapped_welcome_metadata.len(),
        private_key_len = private_key.len(),
        wrapped_welcome_hex = %wrapped_welcome_hex,
        wrapped_welcome_metadata_hex = %wrapped_welcome_metadata_hex,
        private_key_prefix_hex = %private_key_prefix_hex,
        wrapper_algorithm = ?wrapper_algorithm,
        "HPKE unwrap_welcome starting (instrumented v2)"
    );""",
)

text = text.replace(
"""            error!(
                ?e,
                kem_output_len = ciphertext.kem_output.as_ref().len(),
                ciphertext_len = ciphertext.ciphertext.as_ref().len(),
                private_key_len = private_key.len(),
                wrapper_algorithm = ?wrapper_algorithm,
                "HPKE unwrap_welcome setup_receiver failed"
            );""",
"""            error!(
                ?e,
                kem_output_len = ciphertext.kem_output.as_ref().len(),
                ciphertext_len = ciphertext.ciphertext.as_ref().len(),
                private_key_len = private_key.len(),
                kem_output_hex = %hex::encode(ciphertext.kem_output.as_ref()),
                ciphertext_hex = %hex::encode(ciphertext.ciphertext.as_ref()),
                wrapper_algorithm = ?wrapper_algorithm,
                "HPKE unwrap_welcome setup_receiver failed"
            );""",
)

text = text.replace(
"""            error!(
                ?e,
                kem_output_len = ciphertext.kem_output.as_ref().len(),
                ciphertext_len = ciphertext.ciphertext.as_ref().len(),
                private_key_len = private_key.len(),
                wrapper_algorithm = ?wrapper_algorithm,
                "HPKE unwrap_welcome failed to open welcome"
            );""",
"""            error!(
                ?e,
                kem_output_len = ciphertext.kem_output.as_ref().len(),
                ciphertext_len = ciphertext.ciphertext.as_ref().len(),
                private_key_len = private_key.len(),
                kem_output_hex = %hex::encode(ciphertext.kem_output.as_ref()),
                ciphertext_hex = %hex::encode(ciphertext.ciphertext.as_ref()),
                wrapper_algorithm = ?wrapper_algorithm,
                "HPKE unwrap_welcome failed to open welcome"
            );""",
)

text = text.replace(
"""                error!(
                    ?e,
                    kem_output_len = ciphertext.kem_output.as_ref().len(),
                    metadata_len = wrapped_welcome_metadata.len(),
                    private_key_len = private_key.len(),
                    wrapper_algorithm = ?wrapper_algorithm,
                    "HPKE unwrap_welcome failed to open welcome_metadata"
                );""",
"""                error!(
                    ?e,
                    kem_output_len = ciphertext.kem_output.as_ref().len(),
                    metadata_len = wrapped_welcome_metadata.len(),
                    private_key_len = private_key.len(),
                    kem_output_hex = %hex::encode(ciphertext.kem_output.as_ref()),
                    metadata_hex = %hex::encode(wrapped_welcome_metadata),
                    wrapper_algorithm = ?wrapper_algorithm,
                    "HPKE unwrap_welcome failed to open welcome_metadata"
                );""",
)

open(path, "w").write(text)
PY
}

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
# Apply HPKE instrumentation patch before building bindings
apply_hpke_instrumentation_patch
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

echo "[add-instrumentation] Ensuring package.json exports ./version.json..."
PKG_JSON="${PWD}/package.json"
if [ -f "${PKG_JSON}" ]; then
  if ! grep -q '"./version.json"' "${PKG_JSON}"; then
    perl -0pi -e 's/"exports":\s*\{\s*"\.":\s*\{\s*"types":\s*"\.\/dist\/index\.d\.ts",\s*"default":\s*"\.\/dist\/index\.js"\s*\}\s*\}/"exports": {\n    \".\": {\n      \"types\": \"\.\/dist\/index\.d\.ts\",\n      \"default\": \"\.\/dist\/index\.js\"\n    },\n    \"\.\/version.json\": \"\.\/dist\/version.json\"\n  }/s' "${PKG_JSON}" || true
  fi
fi

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
