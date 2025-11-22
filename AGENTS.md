# Agent Context - XMTP HPKE Error Reproduction

## Project Purpose

This repository exists to **reproduce and debug** the OpenMLS HPKE decryption error that occurs in the XMTP Agent SDK. It's a minimal reproduction case for reporting upstream to the XMTP team.

## What We're Investigating

**The Problem**: XMTP Agent SDK silently swallows HPKE decryption errors instead of emitting them to the application layer. This makes it impossible for developers to detect, log, or handle these failures.

**The Error**:
```json
{"level":"ERROR","message":"failed to create group from welcome...: OpenMLS HPKE error: Decryption failed."}
{"level":"WARN","message":"[received] message error, swallowing to continue stream"}
```

## Current Status

✅ **Successfully reproduced** the HPKE error  
✅ **Identified root cause** (error swallowing in Node.js bindings)  
✅ **Created debugging tools** (heartbeat, verbose logging, debug mode)  
✅ **Documented findings** in README.md  
✅ **Prepared upstream issue** template

## Key Files

- **`src/repro.ts`** - Main reproduction script
- **`run.sh`** - Wrapper script with three modes (default, `--recv`, `<address>`)
- **`README.md`** - Documentation with "HPKE Error Findings" section
- **`TODO.md`** - Next steps and investigation paths
- **`.agent/README.md`** - This file (agent context)

## How to Use

### Reproduce HPKE Error
```bash
# Terminal 1: Start receiver
./run.sh --recv

# Terminal 2: Send message from client with stale keys
# (e.g., XMTP mobile app that hasn't synced)
```

### Standard Communication Test
```bash
./run.sh
# Creates local sender + receiver, sends "poke"
```

### Send to External Address
```bash
./run.sh 0x1234567890123456789012345678901234567890
```

## Debug Features

1. **`XMTP_FORCE_DEBUG=true`** - Enabled by default, shows internal SDK logs
2. **Heartbeat logging** - Prints every 5s to confirm process is alive
3. **Enhanced error logging** - Captures full error objects including nested `cause`

## Known Issues

- The SDK **intentionally swallows** HPKE errors (see `bindings_node::conversations`)
- Errors only visible with debug logging enabled
- No way for applications to detect/handle these failures
- Silent message delivery failures

## Next Steps

See **`TODO.md`** for detailed next steps. Priority items:
1. File upstream issue
2. Decide if deeper instrumentation is needed
3. Implement workarounds (auto-retry, installation monitoring)

## For Future Agents

When working on this repo:
- **Don't remove** the debug logging tools (heartbeat, verbose errors)
- **Keep** `XMTP_FORCE_DEBUG=true` enabled in run.sh
- **Update** TODO.md as you make progress
- **Document** any new findings in README.md
- The goal is to **make HPKE errors visible**, not to fix them ourselves

## Dependencies

- `@xmtp/agent-sdk@^0.0.7` - The package we're debugging
- `@xmtp/node-sdk@^4.4.0` - Contains Rust bindings (where error is swallowed)
- Uses XMTP `dev` environment (testnet) by default

## Architecture

```
Application (src/repro.ts)
    ↓
Agent SDK (@xmtp/agent-sdk)
    ↓
Node SDK (@xmtp/node-sdk)
    ↓
Rust Bindings (bindings_node::conversations) ← ERROR SWALLOWED HERE
    ↓
MLS Core (xmtp_mls::groups::welcome_sync) ← ERROR ORIGINATES HERE
    ↓
OpenMLS (HPKE decryption)
```

The error is caught in the Rust→Node.js bindings layer and logged as "swallowing to continue stream" instead of being propagated upward.
