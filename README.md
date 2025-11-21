# XMTP HPKE Error Reproduction Repository

A minimal Node.js/TypeScript repository to reproduce the OpenMLS HPKE decryption error (`AgentError 1002`) in the XMTP Agent SDK.

## 🐛 Issue Description
This repository reproduces an issue where the XMTP Agent SDK may hang or fail during message exchange.

## Expected Behavior
- **Success**: The script runs through all phases, the sender sends a "poke" message, and the receiver successfully receives it. The script prints "✅ SUCCESS: Received "poke" message! Test passed." and exits with code 0.
- **Failure**: The script crashes with an `AgentError` (specifically HPKE decryption error) or times out waiting for the message.


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
