# AI Dev Agent

All-in-one solution to automate coding/bug fixing based on Agile user stories. An n8n server orchestrates ticket reading from JIRA/Bitbucket, pulls the repo, fixes the issue using AI, and creates a pull request. Once ready, a notification is shared on Slack.

## 🚀 Features

- **Automated Workflow**: Reads tickets from JIRA/Bitbucket, processes them, and creates pull requests
- **AI-Powered**: Uses Claude AI to analyze and fix code issues
- **Git Integration**: Automatic cloning, branching, and pushing to repositories
- **Auto-Setup**: Creates admin user automatically on first run
- **Persistent Data**: All workflows, credentials, and settings persist across container restarts
- **Pre-configured Workflow**: AI agent workflow imported and activated automatically

## 📋 Prerequisites

- Docker & Docker Compose
- Git access (SSH keys for private repositories)
- Claude AI API key (or other AI provider)
- Bitbucket/GitHub account

## 🛠️ Quick Start

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd ai-dev-agent
```

### 2. Configure Settings

Edit `config.json` with your project details:

```json
[
  {
    "Key": "JIRA_URL",
    "Value": "your-jira-instance-url"
  }
]
```

### 3. Start n8n

```bash
sudo docker-compose up -d
```

### 4. Access n8n

- **URL**: http://localhost:5678
- **Email**: admin@example.com
- **Password**: ChangeMe123

⚠️ **Change the default password after first login!**

## 📦 What's Included

- **Dockerfile**: Custom n8n image with Git and required tools
- **docker-compose.yml**: Service configuration with persistent volumes
- **entrypoint.sh**: Auto-setup script for owner creation and workflow import
- **workflow.json**: Pre-configured AI agent workflow
- **config.json**: Project configuration template

## 🔧 Configuration

### Environment Variables

You can customize the admin credentials in `docker-compose.yml`:

```yaml
environment:
  - N8N_OWNER_EMAIL=admin@example.com
  - N8N_OWNER_PASSWORD=ChangeMe123
```

### Persistent Data

All n8n data is stored in a Docker volume:
- **Volume name**: `ai-dev-agent_n8n_data`
- **Location**: `/var/snap/docker/common/var-lib-docker/volumes/ai-dev-agent_n8n_data/_data`
- **Contents**: Database, workflows, SSH keys, Git repos, credentials

## 📝 Usage

### View Logs

```bash
sudo docker-compose logs -f
```

### Stop the Container

```bash
sudo docker-compose down
```

### Restart with Fresh Data

```bash
sudo docker-compose down -v  # Removes volumes
sudo docker-compose up -d
```

### Access Persistent Data

```bash
sudo ls -la /var/snap/docker/common/var-lib-docker/volumes/ai-dev-agent_n8n_data/_data
```

## 🔄 How It Works

1. **Container Starts**: n8n starts in the background
2. **Auto-Setup**: Entrypoint script creates admin user via REST API (first run only)
3. **Workflow Import**: AI agent workflow is imported and activated
4. **Ready**: n8n is accessible at http://localhost:5678

### Owner Creation

- ✅ **First run**: Creates admin user automatically
- ✅ **Subsequent runs**: Detects existing owner, skips creation
- ✅ **Persistent**: User data survives container restarts

## 🐛 Troubleshooting

### Landing on Setup Page

If you see the setup page despite successful owner creation:
```bash
sudo docker-compose down -v
sudo docker-compose up -d
```

### Permission Warnings

Permission warnings on config files are suppressed via:
```yaml
- N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
```

### Check if User Exists

```bash
sudo sqlite3 /var/snap/docker/common/var-lib-docker/volumes/ai-dev-agent_n8n_data/_data/database.sqlite "SELECT email FROM user;"
```

## 📚 Additional Documentation

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed setup instructions and troubleshooting.

## 🔐 Security Notes

- Change default credentials immediately after first login
- Keep your API keys secure and never commit them to Git
- Use environment variables for sensitive data in production

## 📄 License

See [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

