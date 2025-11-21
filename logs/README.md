# Logs Directory

This directory contains execution logs from the XMTP HPKE error reproduction script.

## Log File Format

Log files are automatically generated when running `./run.sh` with the following naming convention:

```
run_YYYYMMDD_HHMMSS.log
```

For example: `run_20251121_060709.log`

## Log Contents

Each log file includes:

### 1. System Information
- Operating system and distribution
- Kernel version
- Architecture (x86_64, arm64, etc.)
- Hostname
- Timestamp when execution started

### 2. Package Information
- Project name and version
- Node.js version
- npm version
- List of all installed dependencies and their versions

### 3. Build Output
- TypeScript compilation output
- Any build errors or warnings

### 4. Reproduction Script Output
- All console output from the XMTP reproduction script
- Phase-by-phase execution logs
- Installation IDs created
- Messages sent/received
- Any HPKE decryption errors (AgentError 1002)
- Error stack traces if the script fails

### 5. Execution Summary
- Finish timestamp
- Exit code
- Success/failure status

## Purpose

These logs are essential for:
- **Debugging** - Complete record of what happened during each run
- **Bug Reports** - Share comprehensive execution details with the XMTP team
- **Comparison** - Compare different runs to identify patterns
- **Evidence** - Proof of successful reproduction of the HPKE error

## Retention

Log files are not automatically cleaned up. You may want to periodically review and delete old logs to save disk space.

To clean all logs:
```bash
rm logs/run_*.log
```

## Git Ignore

All `.log` files in this directory are gitignored. Only this README is tracked in version control.
