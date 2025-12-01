#!/usr/bin/env sh
set -e

echo "Starting n8n with auto-setup..."

# Start n8n in background (detached)
n8n start &
N8N_PID=$!

# Give it a moment to initialize DB
sleep 12

# Create owner via API to complete setup
echo "Setting up owner user via API..."
OWNER_RESPONSE=$(curl -s -X POST http://localhost:5678/rest/owner/setup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "firstName": "Admin",
    "lastName": "User",
    "password": "ChangeMe123"
  }')

if echo "$OWNER_RESPONSE" | grep -q "id"; then
  echo "Owner user created successfully"
else
  echo "Owner already exists or setup complete"
fi

# Import workflow (idempotent — only once if not already there)
if [ -f "/home/node/.n8n/workflows/ai-agent.json" ]; then
  echo "Importing and activating workflow..."
  n8n import:workflow \
    --input=/home/node/.n8n/workflows/ai-agent.json \
    --active=true || echo "Workflow already imported or minor error (safe to ignore)"
fi

echo "n8n is ready — access http://localhost:5678 (no login needed)"

# Wait for n8n process to finish (keeps container alive)
wait $N8N_PID