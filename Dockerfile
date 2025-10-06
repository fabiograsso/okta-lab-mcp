FROM python:3.13-slim

LABEL maintainer="Fabio Gasso <fabio.grasso@gmail.com>"
LABEL org.opencontainers.image.authors="Fabio Gasso <fabio.grasso@gmail.com>"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.licenses="GPLv3"
LABEL org.opencontainers.image.source="https://github.com/fabiograsso/okta-lab-mcp"
LABEL org.opencontainers.image.description="Okta MCP Server"

WORKDIR /app

# Install uv
RUN pip install uv

# Copy the source directory
COPY ./okta-mcp-server  /app

# Install Python dependencies including keyrings.alt for plaintext keyring support
RUN uv sync && \
    uv add keyrings.alt 

# Set environment variable for keyring backend to use plaintext file storage
ENV PYTHON_KEYRING_BACKEND=keyrings.alt.file.PlaintextKeyring

# Set default environment variables
ENV OKTA_LOG_LEVEL=INFO
ENV OKTA_TIMEOUT=30
ENV OKTA_MAX_RETRIES=3
ENV OKTA_RATE_LIMIT=600
ENV OKTA_LOG_FILE=/app/logs/okta-mcp.log

# Run the MCP server by default
CMD ["uv", "run", "okta-mcp-server"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
            CMD ["python3.13", "-c", "import sys; sys.exit(0)"]