# Okta MCP Server - Docker Lab Setup Guide

A Docker-based lab environment for testing and developing with the Okta MCP (Model Context Protocol) Server. This setup provides multiple deployment options including an HTTP Gateway for easy integration.

Other use cases and information are available in my blog post: [Lab for test the Okta MCP Server with (or without) Docker](https://iam.fabiograsso.net/posts/howto/okta-lab-mcp/?utm_source=wiki&utm_medium=wiki&utm_campaign=mcp-wiki)

> 📢 **Okta MCP Server**: This lab is based on the [Okta MCP Server](https://github.com/okta/okta-mcp-server) - currently in beta. The official server enables AI assistants to interact with your Okta organization through the Model Context Protocol.
>
> You can refer to the blog post [Introducing the Okta MCP Server](https://developer.okta.com/blog/2025/09/22/okta-mcp-server) that contains useful information and instructions on how configure the Okta tenant.

> ⚠️ **Important**: This is a development/lab setup intended for testing and experimentation. It is **NOT suitable for production use** as it uses a plaintext keyring for credential storage. For production deployments, use proper secret management solutions.

## 📋 Table of Contents

- [Overview](#-overview)
- [What is MCP?](#-what-is-mcp)
- [Why Use a Gateway?](#-why-use-a-gateway)
- [Quick Start](#-quick-start)
- [Docker Installation Details](#-docker-installation-details)
- [Configuration](#-configuration)
- [Available Commands](#-available-commands)
- [Client Configuration Examples](#-client-configuration-examples)
- [Okta Authentication Setup](#-okta-authentication-setup)
- [Testing and Examples](#-testing-and-examples)
- [Native Installation Alternative](#-native-installation-alternative)
- [Security Considerations](#-security-considerations)
- [Troubleshooting](#-troubleshooting)
- [Additional Resources](#-additional-resources)

## 🎯 Overview

This Docker-based lab provides a complete environment for testing the Okta MCP Server with flexible integration options:

- **Okta MCP Server**: Core server for Okta API operations
- **HTTP Gateway**: [Supergateway](https://github.com/supermaven-inc/supergateway) for HTTP transport and remote access
- **Gemini CLI**: Google's AI-powered CLI for testing
- **Client Configurations**: Ready-to-use configs for VS Code, Claude Desktop, and Gemini CLI
![Claude Desktop example showing natural language Okta management](img/claude-example.png)

### Lab Components

| Component | Purpose | Access Method |
|-----------|---------|---------------|
| MCP Server | Core Okta operations | stdio (internal only) |
| HTTP Gateway | Network access | HTTP on port 8000 |
| Gemini CLI | Testing interface | Via gateway |

### Why Docker for This Lab?

- **Isolation**: No system-wide changes required
- **Consistency**: Same environment across all platforms
- **Easy Cleanup**: Simple removal with no traces
- **Version Control**: Infrastructure as code
- **Quick Setup**: Running in minutes

## 🤖 What is MCP?

The [Model Context Protocol (MCP)](https://modelcontextprotocol.io/introduction) is an open protocol introduced by Anthropic that standardizes how Large Language Models communicate with external tools, resources, and remote services. It enables AI assistants to:

- **Access external data sources** and APIs in real-time
- **Execute actions** on behalf of users through natural language
- **Maintain context** across multiple interactions
- **Integrate seamlessly** with existing tools and workflows


```mermaid
flowchart LR
 subgraph AI["AI applications"]
        Chat["Chat interface <br><small>(Claude Desktop, LibreChat)</small>"]
        IDE["IDEs and code editors <br><small>(Claude Code, Goose)</small>"]
        Other["Other AI applications <br><small>(5ire, Superinterface)</small>"]
  end
 subgraph Data["Data sources and tools"]
        Files["Data and file systems <br><small>(PostgreSQL, SQLite, GDrive)</small>"]
        DevTools["Development tools <br><small>(Git, Sentry, etc.)</small>"]
        ProdTools["Productivity tools <br><small>(Slack, Google Maps, etc.)</small>"]
  end
    Chat L_Chat_MCP_0@<--> MCP["MCP <br><small>Standardized protocol</small>"]
    IDE L_IDE_MCP_0@<--> MCP
    MCP L_MCP_Files_0@<--> Files & DevTools & ProdTools
    Other L_Other_MCP_0@<--> MCP

    style Chat stroke-width:2px
    style IDE stroke-width:2px
    style Other stroke-width:2px
    style Files stroke-width:2px
    style DevTools stroke-width:2px
    style ProdTools stroke-width:2px
    style MCP fill:#e6f3ff,stroke:#6699cc,stroke-width:2px
    style AI fill:#FFE0B2,color:#000000
    style Data fill:#C8E6C9

    L_Chat_MCP_0@{ animation: slow } 
    L_IDE_MCP_0@{ animation: slow } 
    L_MCP_Files_0@{ animation: slow } 
    L_MCP_DevTools_0@{ animation: slow } 
    L_MCP_ProdTools_0@{ animation: slow } 
    L_Other_MCP_0@{ animation: slow } 
```


### What is the Okta MCP Server?

The Okta MCP Server integrates with LLMs and AI agents, allowing you to perform various Okta management operations using natural language. For instance, you could simply ask Claude Desktop, VS Code Copilot, or Gemini to perform Okta management operations:

- *"Create a new user and add them to the Engineering group"*
- *"Show me all failed login attempts from the last 24 hours"*
- *"List all applications that haven't been used in the past month"*
- *"Deactivate users who haven't logged in for 90 days"*

The server provides comprehensive tool support including:
- **User Management**: Create, update, deactivate, and manage user profiles
- **Group Operations**: Manage groups and memberships
- **Application Management**: Configure and manage SSO applications
- **Policy Administration**: Handle security policies and rules
- **Audit and Logging**: Access system logs and authentication data

```mermaid
---
config:
  layout: dagre
---
flowchart LR
    agent["AI Agent"] L_agent_server_0@-- MCP Protocol --> server["Okta MCP Server"]
    server L_server_apis_0@-- API Calls --> apis["Okta APIs"]
     agent:::Sky
     server:::Rose
     apis:::Peach
    classDef Sky stroke-width:1px, stroke-dasharray:none, stroke:#374D7C, fill:#E2EBFF, color:#374D7C
    classDef Rose stroke-width:1px, stroke-dasharray:none, stroke:#FF5978, fill:#FFDFE5, color:#8E2236
    classDef Peach stroke-width:1px, stroke-dasharray:none, stroke:#FBB35A, fill:#FFEFDB, color:#8F632D
    L_agent_server_0@{ animation: slow } 
    L_server_apis_0@{ animation: slow }
```

## 🌐 Why Use a Gateway?

### The stdio Protocol Limitation

The MCP protocol uses various ways for communication, but the first release of the Okta MCP Server supports only **stdio** (standard input/output), which works perfectly for direct, local client-server communication. However, stdio has limitations:

1. **Single Connection**: Only one client can connect at a time
2. **Local Only**: No network access capability
3. **Docker Compose Incompatibility**: Cannot directly interact with stdio in detached containers
4. **No Session Management**: No built-in way to maintain state across connections

### The Solution: HTTP Gateway

The [Supergateway](https://github.com/supermaven-inc/supergateway) (HTTP Gateway) solves these limitations by creating a bridge that enables:
- **Remote Access**: Connect from anywhere via HTTP
- **Multiple Clients**: Support concurrent connections
- **Docker Compose Support**: Perfect for containerized environments

```mermaid
flowchart LR
    agent["AI Agent"] L_agent_gateway_0@-- HTTP --> gateway["Gateway"]
    gateway L_gateway_server_0@-- stdio --> server["Okta MCP Server"]
    server L_server_apis_0@-- API Calls --> apis["Okta APIs"]

    agent:::Sky
    gateway:::Aqua
    gateway:::Ash
    server:::Rose
    apis:::Peach
    classDef Sky stroke-width:1px, stroke-dasharray:none, stroke:#374D7C, fill:#E2EBFF, color:#374D7C
    classDef Rose stroke-width:1px, stroke-dasharray:none, stroke:#FF5978, fill:#FFDFE5, color:#8E2236
    classDef Peach stroke-width:1px, stroke-dasharray:none, stroke:#FBB35A, fill:#FFEFDB, color:#8F632D
    classDef Aqua stroke-width:1px, stroke-dasharray:none, stroke:#46EDC8, fill:#DEFFF8, color:#378E7A
    classDef Ash stroke-width:1px, stroke-dasharray:none, stroke:#999999, fill:#EEEEEE, color:#000000

    L_agent_gateway_0@{ animation: slow } 
    L_gateway_server_0@{ animation: slow } 
    L_server_apis_0@{ animation: slow } 
```

#### Benefits of Using the Gateway

1. **Docker Compose Compatibility**
  - Containers in Docker Compose run in detached mode
  - Cannot directly pipe stdio between services
  - Gateway provides HTTP endpoints that services can communicate with
2. **Remote Access**
  - Access your MCP server from anywhere via HTTP
  - Perfect for team collaboration
  - Easy integration with cloud services
3. **Multiple Clients**
  - Support concurrent connections from different clients
  - Each session maintains its own state
  - No conflicts between users
4. **Standard HTTP Protocol**
- Works with any HTTP client (curl, Postman, browsers)
- Easy to debug and test
- Compatible with web applications

### When to Use the Gateway vs Direct stdio

| Use Case | Recommended Approach |
|----------|---------------------|
| Local VS Code extension | Direct stdio (Docker run without Compose) |
| Claude Desktop on same machine | Direct stdio (Docker run without Compose) |
| Docker Compose setup | HTTP Gateway (required) |
| Remote Access | HTTP Gateway + SSH tunnel |
| Web application integration | HTTP Gateway |
| API testing with Postman | HTTP Gateway |
| Multiple concurrent users | HTTP Gateway |
| Single user, local development | Either option works |
---

## 🚀 Quick Start

### Prerequisites

- Docker Engine 20.10+ or Docker Desktop
- Git
- Port 8000 available (or change it in the config)
- Gemini API Key
  - You can generate a new API Key at https://aistudio.google.com/apikey
  - There is a **free tier of 100 requests/day** with Gemini 2.5 Pro. Enough for testing.
- An Okta tenant
  - You can refer to the blog post **[Introducing the Okta MCP Server](https://developer.okta.com/blog/2025/09/22/okta-mcp-server)** that contains useful information and instructions on how configure the Okta tenant.

### 1. Clone and Setup

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/fabiograsso/okta-lab-mcp.git
cd okta-lab-mcp

# Initial setup
make setup
```

### 2. Configure Environment

```bash
# Create .env from template
cp example.env .env

# Edit with your Okta credentials
nano .env
```

Required variables:
```bash
OKTA_ORG_URL=https://my-tenant.okta.com
OKTA_CLIENT_ID=my-client-id
OKTA_KEY_ID=my-key-id
OKTA_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nmy-pem-private-key...\n-----END PRIVATE KEY-----
OKTA_SCOPES=okta.users.read okta.groups.read
```

### 3. Build and Start

```bash
# Build Docker images
make build

# Start all services
make start

# Verify health
make health
```

### 4. Access the Gateway

```bash
# Test the gateway
curl http://localhost:8000

# View logs
make logs-gateway
make logs-mcp
make logs-all
```

---

## 🐳 Docker Installation Details

### Project Structure

```
okta-lab-mcp/
├── Docker Files
│   ├── Dockerfile              # Main Okta MCP server image
│   ├── Dockerfile-gateway      # MCP + Gateway image
│   └── docker-compose.yml      # Service orchestration
│
├── Configuration
│   └── env-example             # Template for .env
│
├── Management Scripts
│   ├── Makefile                # Simplified commands
│   └── docker-utils.sh         # Docker utilities
│
├── Source Code
│   └── okta-mcp-server/        # Okta MCP server source (git submodule)
│
├── Runtime Data
│   └── data/
│       ├── okta-mcp/
│       │   ├── logs/           # Container logs
│       └── gemini/             # Gemini workspace
│
└── Sample Configurations
    └── sample/
        ├── .vscode/
        │   └── mcp.json        # VS Code config
        ├── .gemini/
        │   └── settings.json   # Gemini config
        └── Claude Desktop/
            └── claude_desktop_config.json
```

### Docker Images and Services

#### 1. okta-mcp-server
- **Purpose**: Core MCP server functionality
- **Base Image**: python:3.13-slim
- **Communication**: stdio only (internal)
- **Access**: Through `docker` command only

#### 2. okta-mcp-server-gateway
- **Purpose**: MCP Server + HTTP Gateway
- **Base Image**: okta-mcp-server + Node.js
- **Port**: 8000 (configurable via env `GATEWAY_PORT`)
- **Protocol**: HTTP
- **Access**: http://localhost:8000

#### 3. gemini-cli
- **Purpose**: Testing and demonstration
- **Image**: Google's official Gemini CLI
- **Access**: Connects to the gateway via HTTP

### Docker Deployment Options

#### Option A: Full Stack with Docker Compose

You can run both the MCP Server + Gateway and Gemini-cli:

```bash
# Start all services (recommended for lab)
docker compose up -d

# Services running:
# - MCP Server + HTTP Gateway (port 8000)
# - Gemini CLI
```

#### Option B: Standalone MCP Server

```bash
# For direct stdio access (VS Code, Claude Desktop, Gemini run locally)
docker run -i --rm \
  -e OKTA_ORG_URL="https://my-tenant.okta.com" \
  -e OKTA_CLIENT_ID="your_client_id" \
  -e OKTA_KEY_ID="your_key_id" \
  -e OKTA_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----" \
  -e OKTA_SCOPES="okta.users.read okta.groups.read" \
  okta-mcp-server

# No .env file needed - credentials passed directly
```

#### Option C: Gateway Only

```bash
# Start just the gateway
docker compose up -d okta-mcp-server-gateway

# Access at http://localhost:8000
```

### Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| ./data/okta-mcp/logs | /app/logs | MCP Server logs |
| ./data/gemini | /home/gemini | Gemini workspace |

---

## 🔑 Configuration

### Environment Variables

#### For Docker Compose (.env file)

```bash
# Required
OKTA_ORG_URL=https://my-tenant.okta.com
OKTA_CLIENT_ID=my-client-id
OKTA_KEY_ID=my-key-id
OKTA_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nmy-pem-private-key...\n-----END PRIVATE KEY-----
OKTA_SCOPES=okta.users.read okta.groups.read okta.apps.read

# Optional
OKTA_LOG_LEVEL=INFO
GATEWAY_PORT=8000
GEMINI_API_KEY=your-gemini-api-key
```

#### For Standalone Docker

Environment variables are passed directly with `-e` flags:

```bash
docker run -i --rm \
  -e "OKTA_ORG_URL=https://my-tenant.okta.com" \
  -e "OKTA_CLIENT_ID=my-client-id" \
  -e "OKTA_KEY_ID=my-key-id" \
  -e "OKTA_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----" \
  -e "OKTA_SCOPES=okta.users.read okta.groups.read" \
  -e "OKTA_LOG_LEVEL=DEBUG" \
  okta-mcp-server
```

### Private Key Formatting

The private key must be formatted as a single line with `\n` for newlines:

```bash
# Original format
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
more_key_content_here...
-----END PRIVATE KEY-----

# Formatted for environment variable
-----BEGIN PRIVATE KEY-----\nmy-pem-private-keyQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\nmore_key_content_here...\n-----END PRIVATE KEY-----
```

Convert using:
```bash
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' private_key.pem
```

---

## 📋 Client Configuration Examples

The `sample/` folder contains ready-to-use configurations:

In each file you'll find two servers:

1. Using Docker for run the Okta MCP.
2. Using HTTP for connect to the Gateway

You can then experiment with both and enable/disable each one as needed.

### VS Code (sample/.vscode/mcp.json)
Ready-to-use configuration for VS Code.

Example:

```json
{
  "mcp": {
    "servers": {
      "okta-docker": {
        "type": "stdio",
        "command": "docker",
        "args": [
          "run",
          "-i",
          "--rm",
          "-e", "OKTA_ORG_URL=https://xxxx.okta.com",
          "-e", "OKTA_CLIENT_ID=xxxx",
          "-e", "OKTA_SCOPES=okta.users.read okta.groups.read okta.logs.read okta.apps.read okta.userTypes.read",
          "-e", "OKTA_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nxxxxxxxx\n-----END PRIVATE KEY-----",
          "-e", "OKTA_KEY_ID=xxxxx",
          "-e", "OKTA_LOG_LEVEL=DEBUG",
          "okta-mcp-server"
        ]
      },
      "okta-gateway": {
        "type": "http",
        "url": "http://localhost:8000/mcp"
      }
    }
  }
}
```

The sample code implement both ways to connect to the MCP Server: via HTTP gateway or via stdio. You can choose what to use, or try both.
I suggest in any case to keep only one active at time.

### Claude Desktop (sample/Claude Desktop/claude_desktop_config.json)
Ready-to-use configuration for Claude Desktop.

### Gemini CLI (sample/.gemini/settings.json)
Ready-to-use configuration for Gemini-cli (if you run it locally instead of inside the docker compose).

---

## 🔐 Okta Authentication Setup

The MCP Server supports two authentication methods:

### Method 1: Device Authorization Grant (Interactive)

1. Create a **new App Integration** in your Okta org
2. Select **OIDC - OpenID Connect** and **Native Application**
3. Under **Grant type**, ensure **Device Authorization** is checked
4. Go to **Okta API Scopes** tab and grant permissions (e.g., `okta.users.read`, `okta.groups.manage`)
5. Save and copy the **Client ID**

### Method 2: Private Key JWT (Browserless) - Recommended

1. **Create App**: Select **API Services** and save
2. **Configure Client Authentication**: 
   - Disable **Require Demonstrating Proof of Possession (DPoP)**
   - Select **Public key / Private key** authentication
3. **Add Public Key**: Generate in Okta or upload your own
4. **Grant API Scopes**: Add required permissions
5. **Assign Admin Roles**: Assign **Super Administrator** role

My lab is meant to use the **Private Key JWT (Browserless) method**, in order to run without requiring user interaction for registration. For detailed instructions, refer to [Okta's blog post](https://developer.okta.com/blog/2025/09/22/okta-mcp-server).

---

## 🧪 Testing and Examples

### Gemini CLI

You have different ways to start the gemini-cli:

1. **Docker Desktop**: Open the `gemini-cli` container, go to the Exec tab and run `gemini`
    ![Gemini CLI in Docker Desktop](img/gemini-cli-docker-desktop.png)
2. **Exec gemini in the docker compose:
    ```bash
    docker compose exec gemini-cli gemini

    # or
    make gemini
    ```
3. **Standalone Docker**: 
   ```bash
   docker run -it --rm \
   --network okta-gemini-network \
   -v ./data/gemini:/home/node/.gemini:rw \
   -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
   us-docker.pkg.dev/gemini-code-dev/gemini-cli/sandbox:0.7.0
   ```
4. **Local Installation**:
   ```bash
   # Using npx (no installation required)
   npx https://github.com/google-gemini/gemini-cli

   # Or install with NPM
   npm install -g @google/gemini-cli

   # Or with brew
   brew install gemini-cli

   # Then just run
   gemini
   ```

### Example Queries

Once you started gemini-cli, you can run `/mcp` to see available MCP servers and supported commands. Then test queries like:

- `How many users are in my Okta tenant?`
- `What are the latest logins of user Fabio Grasso?`
- `Add user Fabio Grasso to the group Office 365 License`
- `Check the logs for login errors and provide me the list of users with more than 5 failed login attempts`
- `Check the logs, count all logins per user and give me the ranking of the 10 top users by login count`

## 🛠️ Available Commands

### Essential Commands

```bash
make help           # Display all available commands
make setup          # Initial setup
make build          # Build Docker images
make start          # Start all services
make stop           # Stop all services
make status         # Check service status
make health         # Health check
make logs           # View logs
```

### Service Management

```bash
make start-gateway  # Start only gateway
make restart        # Restart all services
make logs-gateway   # Gateway logs only
make logs-all       # All service logs
make shell          # Open shell in container
```

### Testing

```bash
make gateway-test   # Test HTTP gateway
make run-example    # Show Docker run example
```

### Maintenance

```bash
make clean          # Clean Docker resources
make clean-all      # Complete cleanup
make update         # Update and rebuild
make backup-logs    # Backup logs
```
---

## 🔒 Security Considerations

### ⚠️ Lab Environment Warning

This setup is designed for **testing and development only**:

1. **Plaintext Keyring**: Uses `keyrings.alt.file.PlaintextKeyring`
2. **HTTP Transport**: No TLS/SSL encryption
3. **No Authentication**: Gateway has no access control
4. **Environment Variables**: Sensitive data in plain text
5. **Log Files**: May contain sensitive information

### 🔐 Remote Access via SSH Tunnel

When running on a remote server, create an SSH tunnel for secure access (instead of opening the HTTP port):

```bash
# On your local machine
ssh -L 8000:localhost:8000 username@server-ip

# Access the gateway at http://localhost:8000
```

### Production Recommendations

Never use this setup in production. Instead:
- Implement proper secret management
- Use HTTPS with valid certificates
- Add authentication to the gateway
- Implement rate limiting
- Use dedicated service accounts
- Enable audit logging
- Encrypt data at rest and in transit

---

## 🛠️ Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify `OKTA_ORG_URL`, `OKTA_CLIENT_ID`, `OKTA_PRIVATE_KEY`, `OKTA_KEY_ID` and scopes
   - Check application has required API scopes granted
   - Ensure admin roles are assigned

2. **MCP Client Connection Issues**
   - Restart your MCP client after installation
   - Verify server path in configuration
   - Check that `uv` is installed and accessible

3. **Docker Issues**
   - Use `make logs-all` to view container logs
   - Verify port 8000 is available
   - Check Docker compose services with `make status`

4. **Gateway Access Problems**
   - Test with `curl http://localhost:8000`
   - Check firewall rules for port 8000
   - Verify HTTP gateway container is running

### Debug Mode

Enable detailed logging:

```bash
# For Docker deployment
export OKTA_LOG_LEVEL=DEBUG

# Or add to .env file
OKTA_LOG_LEVEL=DEBUG
```


---

## 💻 Native Installation Alternative

You will find [in my blog post](https://iam.fabiograsso.net/posts/howto/okta-lab-mcp/) detailed instructions on how to install this stack (Okta MCP Server + Gateway + Gemini-cli) in a Linux (Ubuntu) server or in macOS.
**Advantages of Native Installation:**
✅ *Direct stdio access* for local clients  
✅ *Better performance* (no container overhead)  
✅ *System service integration* with systemd  
✅ *Auto-start on boot* 
✅ *Native file system access* 
**Disadvantages of Native Installation**
❌ *System-wide changes* required  
❌ *Harder to clean up* completely  
❌ *Platform-specific* (the script is Ubuntu only)  
❌ *Manual updates* required  

---

## 📚 Additional Resources

### Documentation
- [Okta MCP Server](https://github.com/okta/okta-mcp-server)
- [MCP Protocol](https://modelcontextprotocol.io)
- [Supergateway](https://github.com/supermaven-inc/supergateway)
- [Docker Documentation](https://docs.docker.com/)

### MCP Client Integration
- [VS Code Extension](https://code.visualstudio.com/docs/copilot/customization/mcp-servers)
- [Claude Desktop](https://modelcontextprotocol.io/docs/develop/connect-local-servers)
- [Gemini CLI](https://github.com/google-gemini/gemini-cli/blob/main/docs/tools/mcp-server.md)

### Okta Resources
- [Okta API Documentation](https://developer.okta.com/docs/api/)
- [Okta Developer Portal](https://developer.okta.com/)
- [Introducing the Okta MCP Server](https://developer.okta.com/blog/2025/09/22/okta-mcp-server)

---

## 🎯 Choose Your Path

**Quick Testing?** → Use Docker installation with HTTP Gateway  
**Local Development?** → Use standalone Docker with stdio  
**Persistent Test Server?** → Use [native installation](#-native-installation-alternative)  
**No Docker Available?** → Use [native installation](#-native-installation-alternative)  
**Remote Access Needed?** → Set up [SSH tunnel](#-remote-access-via-ssh-tunnel)  
**Multiple Users?** → Use HTTP Gateway  

**Need help?** Check the [troubleshooting section](#-troubleshooting) or view logs with `make logs-all`

---

## 📞 Support

Questions or feedback? Feel free to open an issue on the [okta-lab-mcp repository](https://github.com/fabiograsso/okta-lab-mcp).