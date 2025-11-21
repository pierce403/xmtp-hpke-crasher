#!/bin/bash
# Patch @xmtp/proto to fix missing .js extensions in ESM imports

echo "🔧 Patching @xmtp/proto ESM imports..."

PROTO_DIR="node_modules/@xmtp/proto/ts/dist/esm"

if [ -d "$PROTO_DIR" ]; then
    # Find all .js files and patch them
    find "$PROTO_DIR" -name "*.js" -type f -print0 | while IFS= read -r -d '' file; do
        # Add .js to any relative import that doesn't already have an extension
        # Matches: ./something or ../something but not ./something.js or ./something.ext
        perl -i -pe 's|(from\s+["\047])(\.\./[^"'\'']+?)(?<!\.js)(?<!\.json)(["\047])|\1\2.js\3|g' "$file"
        perl -i -pe 's|(from\s+["\047])(\./[^"'\'']+?)(?<!\.js)(?<!\.json)(["\047])|\1\2.js\3|g' "$file"
        
        # Fix protobufjs imports
        perl -i -pe 's|from\s+(["\047])protobufjs/minimal\1|from \1protobufjs/minimal.js\1|g' "$file"
    done
    
    echo "✅ Patched @xmtp/proto ESM imports"
else
    echo "⚠️  @xmtp/proto not found, skipping patch"
fi
