FROM n8nio/n8n:1.121.3

USER root

# Install Git (from before) + tools for scripting (curl for health checks)
RUN apk add --no-cache git openssh-client curl

# Create workflow folder
RUN mkdir -p /home/node/.n8n/workflows

# Copy files
COPY config.json /home/node/config.json
COPY workflow.json /home/node/.n8n/workflows/ai-agent.json
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
EXPOSE 5678

ENTRYPOINT ["/entrypoint.sh"]
