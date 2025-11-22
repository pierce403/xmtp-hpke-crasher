#!/bin/bash

# XMTP Agent Simple Message Test Runner
# This script installs dependencies and runs the test

set -e  # Exit on error

# Create logs directory if it doesn't exist
mkdir -p logs

# Generate log filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="logs/run_${TIMESTAMP}.log"

# Function to log to both console and file
log() {
    echo "$@" | tee -a "$LOGFILE"
}

# Start logging
log "╔═══════════════════════════════════════════════════════╗"
log "║  XMTP Agent Simple Message Test - Setup & Run        ║"
log "╚═══════════════════════════════════════════════════════╝"
log ""
log "🕐 Started at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
log "📁 Log file: $LOGFILE"
log ""

# System Information
log "═══════════════════════════════════════════════════════"
log "SYSTEM INFORMATION"
log "═══════════════════════════════════════════════════════"
log "Operating System: $(uname -s)"
log "Kernel Version: $(uname -r)"
log "Architecture: $(uname -m)"
log "Hostname: $(hostname)"
if [ -f /etc/os-release ]; then
    log "Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
fi
log ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    log "❌ Error: Node.js is not installed"
    log "Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node --version)
log "✓ Node.js version: $NODE_VERSION"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    log "❌ Error: npm is not installed"
    exit 1
fi

NPM_VERSION=$(npm --version)
log "✓ npm version: $NPM_VERSION"
log ""

# Package Information
log "═══════════════════════════════════════════════════════"
log "PACKAGE INFORMATION"
log "═══════════════════════════════════════════════════════"
if [ -f package.json ]; then
    PROJECT_NAME=$(node -p "require('./package.json').name" 2>/dev/null || echo "unknown")
    PROJECT_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "unknown")
    log "Project: $PROJECT_NAME"
    log "Version: $PROJECT_VERSION"
fi
log ""

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    log "📦 Installing dependencies..."
    npm install 2>&1 | tee -a "$LOGFILE"
    log ""
else
    log "✓ Dependencies already installed"
    log ""
fi

# Show installed package versions
log "═══════════════════════════════════════════════════════"
log "INSTALLED DEPENDENCIES"
log "═══════════════════════════════════════════════════════"
if [ -f package.json ]; then
    log "Dependencies:"
    node -p "Object.entries(require('./package.json').dependencies || {}).map(([k,v]) => '  ' + k + ': ' + v).join('\n')" 2>/dev/null | tee -a "$LOGFILE" || true
    log ""
    log "Dev Dependencies:"
    node -p "Object.entries(require('./package.json').devDependencies || {}).map(([k,v]) => '  ' + k + ': ' + v).join('\n')" 2>/dev/null | tee -a "$LOGFILE" || true
fi
log ""

# Run the test script using ts-node (handles ESM/CommonJS issues)
log "🚀 Running test script with ts-node..."
log ""
# Parse arguments
RECV_ONLY="false"
RECEIVER_ADDRESS=""

if [ "$1" == "--recv" ]; then
    RECV_ONLY="true"
elif [ -n "$1" ]; then
    RECEIVER_ADDRESS="$1"
fi

RECV_ONLY="$RECV_ONLY" RECEIVER_ADDRESS="$RECEIVER_ADDRESS" XMTP_FORCE_DEBUG="true" npx ts-node src/repro.ts 2>&1 | tee -a "$LOGFILE"

# Capture exit code
EXIT_CODE=${PIPESTATUS[0]}

log ""
log "═══════════════════════════════════════════════════════"
log "EXECUTION COMPLETE"
log "═══════════════════════════════════════════════════════"
log "🕐 Finished at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
log "📊 Exit code: $EXIT_CODE"
log "📁 Full log saved to: $LOGFILE"
log ""

if [ $EXIT_CODE -eq 0 ]; then
    log "✅ Script completed successfully"
else
    log "❌ Script failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
