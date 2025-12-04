#!/usr/bin/env sh
set -e

echo "Starting n8n with auto-setup..."

# Start n8n in background (detached)
n8n start &
N8N_PID=$!

# Give it a moment to initialize DB
echo "Waiting DB initialization (8s)"
sleep 8

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
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    "Key" TEXT,
    "Value" TEXT
);
SQL

# 4. Import data from JSON file into the data table
jq -c '.[]' /home/node/config.json | while read -r row; do
    key_val=$(echo "$row" | jq -r '.Key')
    value_escaped=$(echo "$row" | jq -r '.Value // ""' | sed "s/'/''/g")

  sqlite3 /home/node/.n8n/database.sqlite >/dev/null <<SQL
INSERT OR REPLACE INTO "data_table_user_$TABLE_ID" ("Key", "Value")
VALUES ('${key_val//\'/\'\'}', '$value_escaped');
SQL
done


echo "Data Table 'Config' is now created and seeded."


####################################################################

# Import workflow (idempotent — only once if not already there)
if [ -f "/home/node/.n8n/workflows/ai-agent.json" ]; then
  echo "Importing and activating workflow..."
  n8n import:workflow \
    --input=/home/node/.n8n/workflows/ai-agent.json \
    --active=true || echo "Workflow already imported or minor error (safe to ignore)"
fi

echo "n8n is ready — access http://localhost:5678 — Login: admin@example.com — Password: ChangeMe123"

# Wait for n8n process to finish (keeps container alive)
wait $N8N_PID