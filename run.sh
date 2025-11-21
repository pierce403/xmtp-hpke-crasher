#!/bin/bash

# XMTP HPKE Error Reproduction Script Runner
# This script installs dependencies and runs the reproduction

set -e  # Exit on error

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  XMTP HPKE Error Reproduction - Setup & Run          ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is not installed"
    echo "Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

echo "✓ Node.js version: $(node --version)"
echo ""

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm is not installed"
    exit 1
fi

echo "✓ npm version: $(npm --version)"
echo ""

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
else
    echo "✓ Dependencies already installed"
    echo ""
fi

# Build the TypeScript
echo "🔨 Building TypeScript..."
npm run build
echo ""

# Run the reproduction script
echo "🚀 Running reproduction script..."
echo ""
node dist/repro.js
