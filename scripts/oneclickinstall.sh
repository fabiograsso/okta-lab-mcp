#!/bin/bash

# Author: Fabio Grasso
# License: Apache-2.0
# Version: 2.0.0
# Description: Native installation script for Okta MCP Server without Docker
# - Installs Python 3.13, Node.js, and dependencies
# - Clones and installs Okta MCP Server from GitHub
# - Sets up HTTP Gateway with supergateway
# - Configures Gemini CLI for local MCP access
# - Sets up systemd services for auto-start
# - Copies Makefile for easy management

# Usage: ./oneclickinstall.sh

set -e
export DEBIAN_FRONTEND=noninteractive

echo "
                  ████          ████                              
                  ████          ████                              
       █████      ████    ████  █████        ████   ███           
    ██████████    ████   █████  ████████  █████████████           
  ██████████████  ████  █████   █████   ███████████████           
 █████      █████ █████████     ████    ████       ████           
 ████        ████ ████████      ████   ████        ████           
 ████        ████ ██████████    ████    ████       ████           
  █████    ██████ ████  █████   ████    █████    ██████           
   █████████████  ████   ██████ ████████ ███████████████         
    ██████████    ████     █████ ███████   ████████ █████         

→→→ Okta MCP Server Installation for Ubuntu 24.04 LTS ←←←
"

# --- SCRIPT START ---
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BASE_DIR="$HOME/okta-mcp-server"
LOG_FILE="$SCRIPT_DIR/oneclickinstall.log"
exec &> >(tee "$LOG_FILE")

# --- VERIFY OPERATING SYSTEM ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "24.04" ]; then
        echo "⚠️  WARNING: This script is designed for Ubuntu 24.04 LTS."
        echo "Detected OS: $PRETTY_NAME"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo "⚠️  WARNING: Cannot determine OS version."
fi

# --- CHECK FOR EXISTING ENVIRONMENT FILE ---
ENV_FILE="$BASE_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    echo "📋 Found existing .env file at $ENV_FILE"
    echo "Loading existing configuration..."
    source "$ENV_FILE"
    echo "✅ Configuration loaded from existing .env file"
else
    # --- COLLECT USER INPUT FOR CONFIGURATION ---
    echo "📋 Configuration Setup"
    echo "Please provide the following information for the Okta MCP setup:"
    echo

    # Function to read secure input
    read_secure() {
        local prompt="$1"
        local var_name="$2"
        local is_secret="${3:-false}"
        local default_value="${4:-}"

        if [ "$is_secret" = "true" ]; then
            echo -n "$prompt: "
            read -s value
            echo
        else
            if [ -n "$default_value" ]; then
                read -p "$prompt [$default_value]: " value
                value=${value:-$default_value}
            else
                read -p "$prompt: " value
            fi
        fi

        if [ -z "$value" ] && [ -z "$default_value" ]; then
            echo "❌ ERROR: $var_name cannot be empty"
            exit 1
        fi

        eval "$var_name='$value'"
    }

    # Collect configuration
    read_secure "Okta Organization URL (e.g., https://dev-123456.okta.com)" "OKTA_ORG_URL"
    read_secure "Okta Client ID" "OKTA_CLIENT_ID"
    read_secure "Okta Key ID" "OKTA_KEY_ID"
    echo
    echo "Please paste your private key (press Ctrl+D when finished):"
    OKTA_PRIVATE_KEY=$(cat)
    # Convert multiline to single line with \n
    OKTA_PRIVATE_KEY=$(echo "$OKTA_PRIVATE_KEY" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
    echo
    read_secure "Okta Scopes" "OKTA_SCOPES" false "okta.users.read okta.groups.read okta.apps.read okta.logs.read"
    read_secure "Gemini API Key (optional, press Enter to skip)" "GEMINI_API_KEY" false
    read_secure "HTTP Gateway Port" "GATEWAY_PORT" false "8000"
fi

echo
echo "ℹ️  Configuration Summary:"
echo "  ▪︎ OKTA_ORG_URL: $OKTA_ORG_URL"
echo "  ▪︎ OKTA_CLIENT_ID: $OKTA_CLIENT_ID"
echo "  ▪︎ OKTA_KEY_ID: $OKTA_KEY_ID"
echo "  ▪︎ OKTA_SCOPES: $OKTA_SCOPES"
echo "  ▪︎ GEMINI_API_KEY: ${GEMINI_API_KEY:+[SET]}${GEMINI_API_KEY:-[NOT SET]}"
echo "  ▪︎ GATEWAY_PORT: $GATEWAY_PORT"
echo

# --- CONFIRMATION ---
read -r -t 30 -p "Continue with installation? [Y/n] (auto-accepts in 30s) " CONFIRM
CONFIRM=${CONFIRM:-y}
case "$CONFIRM" in
    [yY][eE][sS] | [yY]) echo "Continuing..." ;;
    *) echo "Aborted."; exit 1 ;;
esac

# --- SYSTEM PREPARATION ---
echo "🧑‍💻 Preparing system..."
sudo apt-get update -qq
sudo apt-get install -qq -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    git \
    make \
    jq \
    unzip \
    wget \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev

echo "✅ System preparation complete."

# --- INSTALL PYTHON 3.13 ---
echo "🐍 Installing Python 3.13..."

# Check if Python 3.13 is already installed
if command -v python3.13 &> /dev/null; then
    echo "Python 3.13 is already installed"
else
    # Add deadsnakes PPA for Python 3.13
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get update -qq
    sudo apt-get install -qq -y python3.13 python3.13-venv python3.13-dev
    
    # Install pip for Python 3.13
    curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.13
fi

# Install uv package manager
sudo python3.13 -m pip install --quiet uv

echo "✅ Python 3.13 and uv installation complete."

# --- INSTALL NODE.JS AND NPM ---
echo "📦 Installing Node.js and npm..."

# Install NodeSource repository for Node.js 20
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -qq -y nodejs
fi

# Install supergateway globally
sudo npm install -g supergateway

echo "✅ Node.js, npm, and supergateway installation complete."

# --- INSTALL GEMINI CLI ---
echo "🤖 Installing Gemini CLI..."

# Install Gemini CLI via npm if not already installed
if ! command -v gemini &> /dev/null; then
    sudo npm install -g @google/gemini-cli
fi

echo "✅ Gemini CLI installation complete."

# --- CLONE AND INSTALL OKTA MCP SERVER ---
echo "📁 Setting up Okta MCP Server..."

# Clone the repository
if [ -d "$BASE_DIR" ]; then
    echo "Repository already exists. Updating..."
    cd "$BASE_DIR"
    git pull
else
    echo "Cloning Okta MCP Server repository..."
    git clone https://github.com/okta/okta-mcp-server.git "$BASE_DIR"
    cd "$BASE_DIR"
fi

# Install Python dependencies using uv
echo "Installing Python dependencies..."
python3.13 -m uv sync

# Install keyrings.alt for credential storage
python3.13 -m uv add keyrings.alt

echo "✅ Okta MCP Server installation complete."

# --- COPY MAKEFILE ---
echo "📋 Copying Makefile for easy management..."

if [ -f "$SCRIPT_DIR/Makefile" ]; then
    cp "$SCRIPT_DIR/Makefile" "$BASE_DIR/Makefile"
    chmod +x "$BASE_DIR/Makefile"
    echo "✅ Makefile copied to $BASE_DIR"
else
    echo "⚠️  WARNING: Makefile not found in $SCRIPT_DIR"
    echo "   Please ensure Makefile is in the same directory as this script"
fi

# --- CREATE ENVIRONMENT FILE ---
if [ ! -f "$ENV_FILE" ]; then
    echo "🔧 Creating environment configuration..."
    
    cat > "$ENV_FILE" << EOF
# Okta Configuration
OKTA_ORG_URL=$OKTA_ORG_URL
OKTA_CLIENT_ID=$OKTA_CLIENT_ID
OKTA_KEY_ID=$OKTA_KEY_ID
OKTA_SCOPES=$OKTA_SCOPES
OKTA_LOG_LEVEL=INFO
OKTA_PRIVATE_KEY=$OKTA_PRIVATE_KEY

# Gateway Configuration
GATEWAY_PORT=$GATEWAY_PORT

EOF

    # Add Gemini API key if provided
    if [ -n "$GEMINI_API_KEY" ]; then
        echo "GEMINI_API_KEY=$GEMINI_API_KEY" >> "$ENV_FILE"
    fi
    
    echo "✅ Environment file created at $ENV_FILE"
fi

# --- CREATE LOG DIRECTORY ---
mkdir -p "$BASE_DIR/logs"
mkdir -p "$HOME/.config/okta-mcp"

# --- CREATE SYSTEMD SERVICE FOR MCP SERVER ---
echo "🔧 Creating systemd service for Okta MCP Server..."

sudo tee /etc/systemd/system/okta-mcp.service > /dev/null << EOF
[Unit]
Description=Okta MCP Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$BASE_DIR
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=$ENV_FILE
ExecStart=/usr/bin/python3.13 -m uv run okta-mcp-server
Restart=always
RestartSec=10
StandardOutput=append:$BASE_DIR/logs/okta-mcp.log
StandardError=append:$BASE_DIR/logs/okta-mcp-error.log

[Install]
WantedBy=multi-user.target
EOF

# --- CREATE SYSTEMD SERVICE FOR HTTP GATEWAY ---
echo "🔧 Creating systemd service for HTTP Gateway..."

sudo tee /etc/systemd/system/okta-mcp-gateway.service > /dev/null << EOF
[Unit]
Description=Okta MCP HTTP Gateway
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$BASE_DIR
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=$ENV_FILE
ExecStart=/usr/bin/npx supergateway --stdio "python3.13 -m uv run okta-mcp-server" --outputTransport streamableHttp --stateful --port \${GATEWAY_PORT}
Restart=always
RestartSec=10
StandardOutput=append:$BASE_DIR/logs/gateway.log
StandardError=append:$BASE_DIR/logs/gateway-error.log

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable services
sudo systemctl daemon-reload
sudo systemctl enable okta-mcp-gateway.service

echo "✅ Systemd services created and enabled."

# --- CONFIGURE GEMINI CLI ---
echo "🤖 Configuring Gemini CLI for local MCP access..."

mkdir -p "$HOME/okta-mcp-server/.gemini"
cat > "$HOME/.gemini/settings.json" << EOF
{
  "mcpServers": {
    "okta-mcp-local": {
      "type": "stdio",
      "command": "python3.13",
      "args": ["-m", "uv", "run", "okta-mcp-server"],
      "cwd": "$BASE_DIR",
      "env": {
        "OKTA_ORG_URL": "$OKTA_ORG_URL",
        "OKTA_CLIENT_ID": "$OKTA_CLIENT_ID",
        "OKTA_KEY_ID": "$OKTA_KEY_ID",
        "OKTA_PRIVATE_KEY": "$OKTA_PRIVATE_KEY",
        "OKTA_SCOPES": "$OKTA_SCOPES"
      }
    }
  },
  "defaultServer": "okta-mcp-local"
}
EOF

echo "✅ Gemini CLI configuration created."

# --- CREATE VS CODE MCP CONFIGURATION ---
echo "🆚 Creating VS Code MCP configuration..."

mkdir -p "$BASE_DIR/.vscode"
cat > "$BASE_DIR/.vscode/mcp.json" << EOF
{
  "servers": {
    "okta": {
      "type": "stdio",
      "command": "python3.13",
      "args": ["-m", "uv", "run", "okta-mcp-server"],
      "cwd": "$BASE_DIR",
      "env": {
        "OKTA_ORG_URL": "$OKTA_ORG_URL",
        "OKTA_CLIENT_ID": "$OKTA_CLIENT_ID",
        "OKTA_KEY_ID": "$OKTA_KEY_ID",
        "OKTA_PRIVATE_KEY": "$OKTA_PRIVATE_KEY",
        "OKTA_SCOPES": "$OKTA_SCOPES",
        "OKTA_LOGS": "/home/ubuntu/okta-mcp-server/logs/okta-mcp.log"
      }
    }
  }
}
EOF

echo "✅ VS Code MCP configuration created."

# --- CONFIGURE FIREWALL ---
if sudo ufw status | grep -q -i "Status: active"; then
    echo "🔥 Configuring firewall..."
    sudo ufw allow $GATEWAY_PORT/tcp
    sudo ufw reload
    echo "✅ Firewall configured for port $GATEWAY_PORT"
fi

# --- START SERVICES ---
echo "🚀 Starting services..."

sudo systemctl start okta-mcp-gateway.service
sleep 3

# --- TEST SERVICES ---
echo "🧪 Testing services..."

# Check if services are running
if systemctl is-active --quiet okta-mcp-gateway.service; then
    echo "✅ HTTP Gateway is running"
    
    # Test gateway endpoint
    sleep 2
    if curl -s -f "http://localhost:$GATEWAY_PORT" > /dev/null 2>&1; then
        echo "✅ Gateway is responding on port $GATEWAY_PORT"
    else
        echo "⚠️  Gateway is running but not responding yet (may need more time to start)"
    fi
else
    echo "❌ HTTP Gateway failed to start"
    echo "Check logs: sudo journalctl -u okta-mcp-gateway.service -n 50"
fi

# --- CREATE CONVENIENCE SCRIPTS ---
echo "📝 Creating convenience scripts..."

# Create start script
cat > "$BASE_DIR/start.sh" << 'EOF'
#!/bin/bash
sudo systemctl start okta-mcp-gateway.service
echo "Services started. Check status with: systemctl status okta-mcp-gateway"
EOF
chmod +x "$BASE_DIR/start.sh"

# Create stop script
cat > "$BASE_DIR/stop.sh" << 'EOF'
#!/bin/bash
echo "Stopping Okta MCP services..."
sudo systemctl stop okta-mcp-gateway.service
echo "Services stopped."
EOF
chmod +x "$BASE_DIR/stop.sh"

# Create status script
cat > "$BASE_DIR/status.sh" << 'EOF'
#!/bin/bash
echo "Okta MCP & HTTP Gateway Status:"
systemctl status okta-mcp-gateway.service --no-pager
EOF
chmod +x "$BASE_DIR/status.sh"

# Create logs script
cat > "$BASE_DIR/logs.sh" << 'EOF'
#!/bin/bash
echo "=== Okta MCP Server Logs ==="
tail -n 50 logs/gateway.log 2>/dev/null || sudo journalctl -u okta-mcp-gateway.service -n 50
EOF
chmod +x "$BASE_DIR/logs.sh"

chown -R $USER:$USER "$BASE_DIR"

# --- COMPLETION MESSAGE ---
echo ""
echo "🎉 =================================="
echo "🎉 INSTALLATION COMPLETED SUCCESSFULLY!"
echo "🎉 =================================="
echo ""
echo "📍 Okta MCP Server installed at: $BASE_DIR"
echo ""
echo "🔧 Services Status:"
echo "  ▪︎ Okta MCP Server and HTTP Gateway: $(systemctl is-active okta-mcp-gateway.service)"
echo "  ▪︎ Gateway URL: http://localhost:$GATEWAY_PORT"
echo ""
echo "📱 Available Commands:"
echo "  ▪︎ Start services: sudo systemctl start okta-mcp-gateway"
echo "  ▪︎ Stop services: sudo systemctl stop okta-mcp-gateway "
echo "  ▪︎ Service status: systemctl status okta-mcp-gateway"
echo "  ▪︎ View logs: journalctl -u okta-mcp-gateway -f"
echo "  ▪︎ Test gateway: curl http://localhost:$GATEWAY_PORT"
echo ""
echo "📁 Configuration Files:"
echo "  ▪︎ Environment: $ENV_FILE"
echo "  ▪︎ Gemini CLI: ~/.gemini/settings.json"
echo "  ▪︎ VS Code MCP: $BASE_DIR/.vscode/mcp.json"
echo "  ▪︎ Makefile: $BASE_DIR/Makefile"
echo "  ▪︎ Logs: $BASE_DIR/logs/"
echo ""
echo "🔌 SSH Tunnel for Remote Access:"
echo "  To access the gateway from a remote machine, create an SSH tunnel:"
echo "  ssh -L 8000:localhost:$GATEWAY_PORT $USER@$(hostname -I | awk '{print $1}')"
echo "  Then access: http://localhost:8000"
echo ""
echo "⚠️  IMPORTANT NOTES:"
echo "  ▪︎ Services will auto-start on system boot"
echo "  ▪︎ To use Gemini CLI with stdio: gemini --server okta-mcp-local"
echo "  ▪︎ To use Gemini CLI with gateway: gemini --server okta-mcp-gateway (default)"
echo "  ▪︎ Use 'make help' in $BASE_DIR for all available commands"
echo ""
echo "📚 Next Steps:"
echo "  1. Test with Makefile: cd $BASE_DIR && make test"
echo "  2. Check health: cd $BASE_DIR && make health"
echo "  3. Test Gemini CLI: gemini (uses gateway by default)"
echo "  4. For remote access, set up SSH tunnel as shown above"
echo ""
echo "🔗 Repository: https://github.com/okta/okta-mcp-server"
echo "📖 Installation log: $LOG_FILE"
echo ""