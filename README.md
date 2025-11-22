# XMTP HPKE Error Reproduction Repository

A minimal Node.js/TypeScript repository to reproduce the OpenMLS HPKE decryption error (`AgentError 1002`) in the XMTP Agent SDK.

## 🐛 Issue Description

This repository reproduces an **OpenMLS HPKE decryption error** that occurs when XMTP clients attempt to decrypt messages. The SDK **silently swallows** this error, making it nearly impossible to detect without debug logging enabled.

## 🎯 Current Reproduction Strategy

The most reliable way to reproduce this error:

1. **Start receiver in listening mode**:
   ```bash
   ./run.sh --recv
   ```
   
2. **Send a message from an external XMTP client** (e.g., mobile app) to the displayed address

3. **Observe the error** in the debug logs:
   ```
   💓 [2025-11-22T11:49:47.894Z] Waiting for messages... (RSS: 305MB)
   {"timestamp":"2025-11-22T11:49:49.055727Z","level":"ERROR","message":"failed to create group from welcome created at 1763812188937084000: OpenMLS HPKE error: Decryption failed.","target":"xmtp_mls::groups::welcome_sync"}
   {"timestamp":"2025-11-22T11:49:49.055757Z","level":"WARN","message":"[received] message error, swallowing to continue stream","inbox_id":"e02851912f1f970056ff326cc791f3b1cf7265c77e65e9f77dc056d93f965275","error":"Group(UnwrapWelcome(Hpke(DecryptionFailed)))","target":"bindings_node::conversations"}
   💓 [2025-11-22T11:49:52.900Z] Waiting for messages... (RSS: 305MB)
   ```

### Platform-Specific Behavior

⚠️ **This error appears reliably on GB10 systems** but has not been observed on other platforms yet. The root cause of this platform-specific behavior is still under investigation.

## Expected vs. Actual Behavior

- **Expected**: The agent emits an `'error'` event when HPKE decryption fails, allowing the application to handle it
- **Actual**: The error is caught in the Rust→Node.js bindings and logged as "swallowing to continue stream" - it never reaches the application layer


## ⚠️ Known Issues

### ESM Import Resolution Error

The `@xmtp/agent-sdk@^0.0.7` package has a dependency (`@xmtp/proto`) with incomplete ES module support. The proto package's `index.js` imports files without `.js` extensions, which causes Node.js ESM resolution to fail.

**Workaround Implemented**: This repository includes a `postinstall` script (`scripts/patch-proto.sh`) that automatically patches the `@xmtp/proto` package after `npm install` by adding `.js` extensions to all relative imports. This allows the reproduction script to run successfully using `ts-node`.

**Usage**: Simply run `npm install` and the patch will be applied automatically. To run the script, use:
```bash
npm run dev  # or
npx ts-node src/repro.ts
```

## 📋 Requirements

- Node.js 18+ 
- npm or yarn

## 🚀 Quick Start

### Easiest Way: Use the run.sh Script

```bash
./run.sh
```

This single command will:
- ✓ Check for Node.js and npm
- ✓ Install dependencies if needed
- ✓ Build the TypeScript
- ✓ Run the reproduction script

### Alternative: Manual Steps

#### 1. Install Dependencies

```bash
npm install
```

#### 2. Configure Environment (Optional)

The default configuration uses the XMTP dev (testnet) environment. To customize:

```bash
cp .env.example .env
# Edit .env if needed
```

Available options:
- `XMTP_ENV`: `dev` (default, recommended) or `production`
- `DEBUG`: `true` (default) for verbose logging

#### 3. Run the Reproduction Script

```bash
npm start
```

This will:
- Clean any previous build
- Compile TypeScript to JavaScript
- Execute the reproduction script

#### Other Commands

```bash
# Build only
npm run build

# Run compiled script
node dist/repro.js

# Clean build artifacts and databases
npm run clean

# Receiver-only mode (listen for messages)
./run.sh --recv

# Send to specific address
./run.sh 0x1234...
```

## 🔬 Optional: deeper HPKE instrumentation (Rust)

By default this repo uses the published XMTP SDKs from npm, which already reproduce the HPKE error on a clean system (no Rust toolchain required).

If you also want low‑level HPKE logs from the underlying Rust `libxmtp` implementation, you can opt into a local build of `@xmtp/node-bindings`:

1. Ensure you have Rust (`cargo`) and `yarn` installed.
2. From the repo root, run:

   ```bash
   ./scripts/use-local-node-bindings.sh
   ```

   This builds `@xmtp/node-bindings` from the vendored `libxmtp/` workspace and symlinks it into `node_modules/@xmtp/node-bindings` so your existing `./run.sh` flows use the instrumented Rust code.

3. Run the usual receiver repro:

   ```bash
   ./run.sh --recv
   ```

With this enabled, HPKE failures during welcome decryption will emit extra structured logs from `xmtp_mls::groups::mls_ext::welcome_wrapper`, in addition to the existing Node‑level error that is currently being swallowed.

## 🔍 HPKE Error Findings

### Issue Summary

We successfully reproduced an **OpenMLS HPKE decryption error** that occurs when a client with a stale installation attempts to send messages. The SDK **silently swallows this error** by design, making it difficult to debug.

### How to Reproduce

1. **Start receiver in listening mode**:
   ```bash
   ./run.sh --recv
   ```
   This will output an address like: `Listening for messages on: 0x...`

2. **Send a message from a client with stale keys**:
   - Use an XMTP client that hasn't synced with the receiver's latest installation
   - Send a message to the address from step 1

3. **Observe the silent failure**:
   With `XMTP_FORCE_DEBUG=true` (enabled by default in `run.sh`), you'll see:
   ```json
   {"timestamp":"...","level":"ERROR","message":"failed to create group from welcome created at ...: OpenMLS HPKE error: Decryption failed.","target":"xmtp_mls::groups::welcome_sync"}
   {"timestamp":"...","level":"WARN","message":"[received] message error, swallowing to continue stream","inbox_id":"...","error":"Group(UnwrapWelcome(Hpke(DecryptionFailed)))","target":"bindings_node::conversations"}
   ```

### Key Findings

1. **Error is Intentionally Swallowed**: The Node.js bindings catch the HPKE error and log "swallowing to continue stream" instead of propagating it to the application layer.

2. **No Agent Error Event**: The error never reaches the `agent.on('error', ...)` handler, making it impossible for applications to detect and handle this failure.

3. **Silent Failure Mode**: Messages fail to decrypt, but the agent continues running without surfacing the issue.

### Debugging Tools Added

This repository includes tools to help debug these issues:

- **Heartbeat Logging**: When running in `--recv` mode, the script prints a heartbeat every 5 seconds to confirm the process is alive
- **Verbose Error Logging**: Enhanced error handlers that print the full error object structure, including nested `cause` properties
- **Debug Mode**: `XMTP_FORCE_DEBUG=true` is enabled by default to show internal SDK logs

### Recommended Solutions

1. **Short-term**: Enable `XMTP_FORCE_DEBUG` in production to capture these errors in logs
2. **Medium-term**: File an issue upstream requesting that HPKE errors emit an 'error' event
3. **Long-term**: The SDK should provide a way to handle or retry failed decryptions gracefully

### Related Code

- Error swallowing happens in: `bindings_node::conversations` (Rust → Node.js bindings)
- Original error source: `xmtp_mls::groups::welcome_sync` (Rust core)

## 🏗️ Project Structure

```
xmtp-hpke-crasher/
├── src/
│   └── repro.ts          # Main reproduction script
├── dist/                 # Compiled JavaScript (generated)
├── .env                  # Environment configuration
├── .env.example          # Example environment file
├── .gitignore           # Git ignore rules
├── package.json         # Project dependencies and scripts
├── tsconfig.json        # TypeScript configuration
├── README.md           # This file
```

## 🎯 Reproduction Strategy

The script simplifies the interaction to the bare minimum:
1. **Receiver Setup**: Initialize a receiver agent.
2. **Sender Setup**: Initialize a sender agent.
3. **Messaging**: Send a "poke" message from sender to receiver.
4. **Verification**: Wait for the receiver to process the message.

## 📊 What to Expect

### Script Phases

The reproduction script executes in 2 phases:

#### **Phase 1: Receiver Initialization**
```
🚀 Initializing Receiver...
   Wallet Address: 0x...
   🔑 Installation ID: def456...
� Receiver listening for messages...
```

#### **Phase 2: Sender Initialization & Messaging**
```
🚀 Initializing Sender...
   Wallet Address: 0x...
   🔑 Installation ID: ghi789...
🤝 Creating conversation with 0x...
📤 Sending "poke" message...
✅ "poke" message sent
```

### Success Criteria

The reproduction is **successful** if:

✅ **Message Received**:
```
📩 Receiver got message: "poke"
✅ SUCCESS: Received "poke" message! Test passed.
```

### Failure Criteria

The reproduction **fails** (reproduces the bug) if:

❌ **Hang**: The script hangs indefinitely at `agent.start()` or while waiting for the message.
❌ **Crash**: The script crashes with an `AgentError` or other exception.

## 🔧 Technical Details

### Why This Reproduces the Error
This minimal setup isolates the core agent-to-agent communication. If this fails or hangs, it indicates a fundamental issue with:
1. **Network Connectivity**: Inability to connect to XMTP nodes.
2. **Agent Initialization**: Issues with the `Agent.create` or `agent.start` process.
3. **Message Delivery**: Problems with the message delivery pipeline.

### Key SDK Concepts

- **Agent**: The XMTP client instance
- **Installation**: A unique instance of the agent tied to a device/database
- **Installation ID**: Unique identifier for each installation
- **HPKE**: Hybrid Public Key Encryption used by XMTP for message encryption

## 📦 Dependencies

- `@xmtp/agent-sdk@^0.0.7` - XMTP Agent SDK (the package being tested)
- `ethers@^6.13.0` - Ethereum wallet utilities
- `dotenv@^16.4.0` - Environment variable management
- `typescript@^5.3.0` - TypeScript compiler

## 🐛 Reporting Results

When reporting results from this reproduction:

1. **Copy the full console output** - All phases provide valuable diagnostic information
2. **Note the Installation IDs** - Compare stale vs. final installation IDs
3. **Include error stack traces** - The script logs detailed error information
4. **Specify timing** - Note when the error occurs (during which message, phase, etc.)

## 📝 License

Apache 2.0

## 🤝 Contributing

This is a minimal reproduction repository. If you find ways to improve the reproduction or discover related issues, please document them.

---

**Note**: This repository uses randomly generated wallets and the XMTP dev (testnet) environment. No real private keys or mainnet operations are involved.
