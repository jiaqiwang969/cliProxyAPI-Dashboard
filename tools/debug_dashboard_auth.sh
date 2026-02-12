#!/bin/bash
# Debug script to check what's in localStorage and test current key

echo "🔍 CLIProxy Dashboard Debug Script"
echo "==================================="
echo ""

# Get current key from local storage (simulated - need to check in browser)
echo "📋 Instructions to check localStorage:"
echo "1. Open dashboard: http://localhost:8317/"
echo "2. Open DevTools (F12) → Console"
echo "3. Run: localStorage.getItem('mgmt_key')"
echo "4. Copy the key and test it below"
echo ""

# Test with different keys
echo "🧪 Testing authentication with different keys:"
echo ""

# Test new key
NEW_KEY="sk-mgmt-YzGSOKQNszGbie-UA4kg9kfymXEGz_sZujjOgHbTLxQXkSGz"
echo "➡️  Testing NEW key: ${NEW_KEY:0:20}..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $NEW_KEY" \
  http://localhost:8317/v0/management/config)
echo "   HTTP Status: $RESPONSE"
if [ "$RESPONSE" = "200" ]; then
  echo "   ✅ NEW key works!"
else
  echo "   ❌ NEW key failed"
fi
echo ""

# Test old key
OLD_KEY="sk-antigravity-management"
echo "➡️  Testing OLD key: ${OLD_KEY}"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $OLD_KEY" \
  http://localhost:8317/v0/management/config)
echo "   HTTP Status: $RESPONSE"
if [ "$RESPONSE" = "200" ]; then
  echo "   ✅ OLD key works!"
else
  echo "   ❌ OLD key failed"
fi
echo ""

# Check what's in localStorage via a test
echo "📝 To fix if localStorage has old key:"
echo "   1. Open Dev Tools (F12) → Console"
echo "   2. Run: localStorage.setItem('mgmt_key', '$NEW_KEY')"
echo "   3. Reload page"
echo ""

echo "✅ Debug complete!"
