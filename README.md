# XMTP HPKE Error Reproduction Repository

A minimal Node.js/TypeScript repository to reproduce the OpenMLS HPKE decryption error (`AgentError 1002`) in the XMTP Agent SDK.

## 🐛 Issue Description

This repository reproduces a critical bug where the XMTP Agent SDK crashes with an HPKE decryption error when:
- An agent identity has multiple conflicting or stale installations on the network
- Messages are received while the agent is streaming conversations

**Error Signature:**
```
Decryption failed (AgentError 1002)
OpenMLS HPKE error during conversation streaming
```

## 🎯 Reproduction Strategy

The script simulates the real-world scenario where a wallet has created multiple installations over time (e.g., from different devices or reinstallations) by:

1. **Creating Stale Installations**: Initialize the receiver agent 3 times, each time:
   - Start the agent (creates new installation on network)
   - Wait for network registration
   - Stop the agent
   - **Delete the local `.db3` database** (forces new Installation ID on next startup)

2. **Final Receiver Setup**: Initialize receiver a 4th time and keep it running

3. **Trigger Error**: Initialize sender and send multiple messages to the receiver

4. **Expected Result**: The receiver should encounter HPKE decryption errors when trying to decrypt messages sent to the stale installation IDs

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
```

## 📊 What to Expect

### Script Phases

The reproduction script executes in 5 phases:

#### **Phase 1: Creating Stale Installations**
```
--- Stale Installation 1/3 ---
🚀 Initializing Receiver (Stale #1)...
   Wallet Address: 0x...
   🔑 Installation ID: abc123...
   ⏳ Waiting for network registration...
   🛑 Stopping agent...
   🗑️  Deleting database to create stale installation...
```

Repeats 3 times to create multiple stale installations on the XMTP network.

#### **Phase 2: Initializing Final Receiver Instance**
```
🚀 Initializing Receiver (FINAL)...
   Wallet Address: 0x...
   🔑 Installation ID: def456...
📡 Receiver listening for messages...
```

This is the "live" receiver that will attempt to decrypt incoming messages.

#### **Phase 3: Initializing Sender**
```
🚀 Initializing Sender...
   Wallet Address: 0x...
   🔑 Installation ID: ghi789...
```

#### **Phase 4: Sending Messages**
```
📤 Sending 8 messages from Sender to Receiver...
   Sending message 1...
   ✅ Message 1 sent: "Test message 1/8 - Testing HPKE decryption..."
```

Messages are sent with 1-second delays between each.

#### **Phase 5: Cleanup**
```
🛑 Stopping agents...
   ✅ Sender stopped
   ✅ Receiver stopped
```

### Success Criteria

The reproduction is **successful** if one or more of the following occurs:

✅ **HPKE Decryption Error** logged in receiver:
```
❌ ERROR in Receiver (FINAL): OpenMLS HPKE error
Error code: 1002
```

✅ **Agent Crash** - The receiver agent crashes during message processing

✅ **Unhandled Rejection** related to decryption failures

## 🔍 Debugging

### Enable Verbose Logging

Set `DEBUG=true` in `.env` (enabled by default)

### Check Database Files

The script creates two database files:
- `receiver.db3` - Receiver agent's local storage
- `sender.db3` - Sender agent's local storage

These are automatically cleaned by `npm run clean`.

### Manual Cleanup

```bash
# Remove all database files
rm -f *.db3 *.db3-shm *.db3-wal

# Remove build output
rm -rf dist
```

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
└── README.md           # This file
```

## 🔧 Technical Details

### Why This Reproduces the Error

1. **Multiple Installation IDs**: Each time we delete the database and reinitialize, the SDK creates a **new Installation ID** for the same wallet address

2. **Stale Installations on Network**: The XMTP network retains all installation IDs associated with a wallet address

3. **Message Routing**: When the sender sends a message, the network may attempt to deliver it to **all installations** (including stale ones)

4. **HPKE Decryption Failure**: The current "live" receiver installation cannot decrypt messages encrypted for the **stale installation IDs** it no longer has keys for

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
