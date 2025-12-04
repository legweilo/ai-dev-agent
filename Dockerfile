FROM n8nio/n8n:1.121.3

USER root

# Install Git, Python3, curl, jq, sqlite for the workflow automation and data table setup
RUN apk add --no-cache git openssh-client curl python3 py3-pip jq sqlite

# Create workflow folder
RUN mkdir -p /home/node/.n8n/workflows

# Copy config and workflow files
COPY config.json /home/node/config.json
COPY workflow.json /tmp/workflow.json

# Make sure sqlite3 is available (only 30 KB)
RUN apk add --no-cache sqlite


# Generate the final workflow with config values during build
RUN cd /tmp && \
    mv /tmp/workflow.json /home/node/.n8n/workflows/ai-agent.json


# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh


USER node
EXPOSE 5678

ENTRYPOINT ["/entrypoint.sh"]
