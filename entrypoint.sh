#!/usr/bin/env sh
set -e


####################################################################

CONTAINER_ALREADY_STARTED="CONTAINER_ALREADY_STARTED_PLACEHOLDER"
if [ ! -e $CONTAINER_ALREADY_STARTED ]; then
    touch $CONTAINER_ALREADY_STARTED
    echo "-- First container startup, n8n initialization in progress...  --"

# Import workflow (idempotent — only once if not already there)
if [ -f "/home/node/.n8n/workflows/ai-agent.json" ]; then
  echo "Importing and activating workflow..."
  n8n import:workflow \
    --input=/home/node/.n8n/workflows/ai-agent.json \
    --active=true 2>&1 | grep -v "Could not find workflow" | grep -v "Could not remove webhooks" | grep -v "at ActiveWorkflowManager" | grep -v "at ImportService" | grep -v "at ImportWorkflowsCommand" | grep -v "at CommandRegistry" | grep -v "Error: Could not find workflow" || true
  echo "Workflow import completed"
fi

####################################################################
###################### Import Credentials ##########################
####################################################################

echo "Creating credentials from config.json..."

# Extract credentials from config.json
JIRA_LOGIN=$(jq -r '.[] | select(.Key == "CREDENTIAL_JIRA_LOGIN") | .Value' /home/node/config.json)
JIRA_PASSWORD=$(jq -r '.[] | select(.Key == "CREDENTIAL_JIRA_PASSWORD") | .Value' /home/node/config.json)

if [ -n "$JIRA_LOGIN" ] && [ -n "$JIRA_PASSWORD" ]; then
  # Create credential JSON file for n8n CLI import (must be a plain array)
  cat > /tmp/jira-credentials.json <<EOF
[
  {
    "id": "jira-basic-auth-credential",
    "name": "JIRA Basic Auth",
    "type": "httpBasicAuth",
    "data": {
      "user": "$JIRA_LOGIN",
      "password": "$JIRA_PASSWORD"
    }
  }
]
EOF

  echo "Importing JIRA credentials via n8n CLI..."
  n8n import:credentials --input=/tmp/jira-credentials.json 2>&1 | grep -v "Could not find credential" || true

  # Cleanup
  rm -f /tmp/jira-credentials.json

  echo "JIRA Basic Auth credential imported successfully"
else
  echo "JIRA credentials not found in config.json, skipping credential creation"
fi

####################################################################

echo "Starting n8n to complete setup..."

# Start n8n in background (detached)
n8n start &
N8N_PID=$!

# Give it a moment to initialize DB
echo "Waiting DB initialization (10s)"
sleep 10

# Create owner via API to complete setup
echo "Setting up default owner user via API..."
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

####################################################################
########################### Import Data Table ######################
####################################################################

echo "Creating and seeding Data Table 'Config' ..."

# Fixed table ID (use this for consistency; change if you want a different UUID)
TABLE_ID="SUPERAIUNIQUEIDYEAAAAH"

# Auto-detect project ID (from 'project' table; fallback to empty if none)
PROJECT_ID=$(sqlite3 /home/node/.n8n/database.sqlite "SELECT id FROM project LIMIT 1;" 2>/dev/null || echo "")

# 1. Register the data_table in SQLITE DB
sqlite3 /home/node/.n8n/database.sqlite >/dev/null <<SQL
INSERT OR REPLACE INTO data_table (id, name, projectId, createdAt, updatedAt) VALUES ('$TABLE_ID', 'Config', '$PROJECT_ID', datetime('now'), datetime('now'));
SQL

# 2. Register columns
sqlite3 /home/node/.n8n/database.sqlite >/dev/null <<SQL
INSERT OR REPLACE INTO data_table_column (id, name, type, "index", dataTableId, createdAt, updatedAt)
VALUES
  ('keyid', 'Key', 'string', 0, '$TABLE_ID', datetime('now'), datetime('now')),
  ('valueid', 'Value', 'string', 1, '$TABLE_ID', datetime('now'), datetime('now'));
SQL

# 3. Create the actual data table
sqlite3 /home/node/.n8n/database.sqlite >/dev/null <<SQL
CREATE TABLE IF NOT EXISTS "data_table_user_$TABLE_ID" (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    createdAt TEXT DEFAULT (datetime('now')),
    updatedAt TEXT DEFAULT (datetime('now')),
    "Key" TEXT,
    "Value" TEXT
);
SQL

# 4. Import data from JSON file into the data table (excluding CREDENTIAL_* fields)
jq -c '.[]' /home/node/config.json | while read -r row; do
    key_val=$(echo "$row" | jq -r '.Key')

    # Skip keys starting with "CREDENTIAL_"
    if echo "$key_val" | grep -q "^CREDENTIAL_"; then
        continue
    fi

    value_escaped=$(echo "$row" | jq -r '.Value // ""' | sed "s/'/''/g")

  sqlite3 /home/node/.n8n/database.sqlite >/dev/null <<SQL
INSERT OR REPLACE INTO "data_table_user_$TABLE_ID" ("Key", "Value")
VALUES ('${key_val//\'/\'\'}', '$value_escaped');
SQL
done


echo "Data Table 'Config' is now created and seeded."



else
    echo "-- Not first container startup, skipping initialization and directly starting n8n... --"

    # Start n8n in background (detached)
    n8n start &
    N8N_PID=$!
fi


####################################################################

echo "n8n is ready — access http://localhost:5678 — Login: admin@example.com — Password: ChangeMe123"

# Wait for n8n process to finish (keeps container alive)
wait $N8N_PID
