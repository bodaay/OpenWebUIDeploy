#!/bin/bash

# setup_docker.sh
# This script generates a docker-compose.yml file based on GPU availability
# and sets up necessary mount directories and Nginx configurations.

set -e  # Exit immediately if a command exits with a non-zero status.

####################################
# Function Definitions
####################################

# Function to display help
show_help() {
    echo "Usage: ./setup_docker.sh"
    echo ""
    echo "This script sets up a Docker Compose environment with PostgreSQL, Ollama, Open WebUI, and Nginx."
    echo "It detects GPU availability to configure services accordingly."
    echo "You will be prompted to enter domain names or IP addresses for Nginx configuration."
    echo ""
    echo "Interactive Prompts:"
    echo "  1. Root path for Docker volumes."
    echo "  2. Domain names or IP addresses."
    echo "  3. Enable OpenAI API and provide API key if applicable."
    echo "  4. Enable HTTPS or use HTTP."
    echo ""
    echo "Prerequisites:"
    echo "  - Docker"
    echo "  - Docker Compose"
    echo "  - NVIDIA Drivers and Docker Toolkit (if using GPU)"
    echo ""
    echo "Optional Enhancements:"
    echo "  - Secure handling of sensitive data using Docker Secrets."
    echo ""
}

# Display help if -h or --help is passed
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Function to detect GPU availability
detect_gpu() {
    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi -L &> /dev/null; then
            return 0  # GPU is available
        fi
    fi
    return 1  # GPU not available
}

# Function to validate domain or IP address
validate_server_name() {
    local name="$1"
    # Regex patterns for domain and IP validation
    local domain_regex="^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"
    local ip_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"

    if [[ $name =~ $domain_regex ]] || [[ $name =~ $ip_regex ]]; then
        return 0  # Valid
    else
        return 1  # Invalid
    fi
}

# Function to prompt for domains
prompt_domains() {
    echo "Enter your domain names or IP addresses (e.g., chat.example.com or 192.168.1.1)."
    echo "The first valid entry will be the main domain."
    echo "Any additional valid entries will redirect to the main domain."
    echo "Type 'done' when you are finished."

    domains=()

    while true; do
        read -rp "Enter domain or IP (or type 'done' to finish): " domain
        if [[ "$domain" == "done" ]]; then
            break
        elif [[ -z "$domain" ]]; then
            echo "Input cannot be empty. Please try again."
        else
            if validate_server_name "$domain"; then
                domains+=("$domain")
                echo "Accepted: $domain"
            else
                echo "Invalid domain or IP address: '$domain'. Please enter a valid domain or IP."
            fi
        fi
    done

    if [ ${#domains[@]} -eq 0 ]; then
        echo "No valid domains or IP addresses entered. Exiting."
        exit 1
    fi

    MAIN_DOMAIN="${domains[0]}"
    ADDITIONAL_DOMAINS=("${domains[@]:1}")
}

# Function to prompt for enabling OpenAI API and API key
prompt_openai_api() {
    echo "Do you want to enable the OpenAI API? [y/N]"
    read -rp "Enable OpenAI API? (y/N): " enable_api

    # Default to 'no' if input is empty
    enable_api=${enable_api:-N}

    case "$enable_api" in
        [Yy]* )
            ENABLE_OPENAI_API=true
            read -rp "Enter your OpenAI API key (leave empty for placeholder): " OPENAI_API_KEY
            if [[ -z "$OPENAI_API_KEY" ]]; then
                OPENAI_API_KEY="PUT_YOUR_KEY_HERE"
            fi
            ;;
        [Nn]* )
            ENABLE_OPENAI_API=false
            OPENAI_API_KEY=""
            ;;
        * )
            echo "Invalid input. Please enter 'y' or 'n'."
            prompt_openai_api
            ;;
    esac
}

# Function to prompt for HTTPS option
prompt_https_option() {
    echo "Do you want to enable HTTPS for your domain(s)? [y/N]"
    read -rp "Enable HTTPS? (y/N): " enable_https

    # Default to 'no' if input is empty
    enable_https=${enable_https:-N}

    case "$enable_https" in
        [Yy]* )
            ENABLE_HTTPS=true
            ;;
        [Nn]* )
            ENABLE_HTTPS=false
            ;;
        * )
            echo "Invalid input. Please enter 'y' or 'n'."
            prompt_https_option
            ;;
    esac
}

# Function to prompt for root path for volumes
prompt_root_path() {
    echo "Enter the root path for Docker volumes (absolute path)."
    echo "Leave empty to use the script's directory (${SCRIPT_DIR}) as the root path."

    read -rp "Enter root path for volumes (default: ${SCRIPT_DIR}): " user_root_path

    if [[ -z "$user_root_path" ]]; then
        ROOT_PATH="${SCRIPT_DIR}"
        echo "Using script's directory as root path: ${ROOT_PATH}"
    else
        # Expand tilde to home directory if present
        if [[ "$user_root_path" == ~* ]]; then
            user_root_path="${user_root_path/#\~/$HOME}"
        fi

        # Convert to absolute path
        ROOT_PATH="$(realpath -m "$user_root_path")"

        # Create the root path directory if it doesn't exist
        if [ ! -d "$ROOT_PATH" ]; then
            mkdir -p "$ROOT_PATH"
            echo "Created root path directory: ${ROOT_PATH}"
        else
            echo "Using existing root path directory: ${ROOT_PATH}"
        fi
    fi
}

# Function to download yq binary to tools directory
download_yq() {
    local yq_version="v4.34.1"  # Specify the desired yq version
    local yq_binary="yq_linux_amd64"  # Change this based on your OS (e.g., yq_darwin_amd64 for macOS)
    local download_url="https://github.com/mikefarah/yq/releases/download/${yq_version}/${yq_binary}"
    local tools_dir="${SCRIPT_DIR}/tools"
    local yq_path="${tools_dir}/yq"

    mkdir -p "$tools_dir"

    echo "Downloading yq version ${yq_version}..."
    wget -q "${download_url}" -O "${yq_path}"
    chmod +x "${yq_path}"
    echo "yq has been downloaded to ${yq_path}."
}

# Function to check and set up yq
setup_yq() {
    local tools_dir="${SCRIPT_DIR}/tools"
    local yq_path="${tools_dir}/yq"

    if [ ! -f "$yq_path" ]; then
        echo "yq not found in ${tools_dir}. Downloading..."
        download_yq
    else
        echo "yq is already present in ${tools_dir}."
    fi
}

# Function to generate dhparam.pem
generate_dhparam() {
    echo "Generating dhparam.pem file..."
    openssl dhparam -out "${NGINX_SSL_DIR}/dhparam.pem" 2048
    echo "dhparam.pem has been generated."
}

####################################
# Main Script Execution
####################################

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prompt for root path for volumes
prompt_root_path

# Define mount directories relative to the root path
POSTGRES_DATA_DIR="${ROOT_PATH}/postgres_data"
OLLAMA_DATA_DIR="${ROOT_PATH}/ollama_data"
OPEN_WEBUI_DATA_DIR="${ROOT_PATH}/open_webui_data"
NGINX_CONF_DIR="${ROOT_PATH}/nginx_conf"
NGINX_SSL_DIR="${ROOT_PATH}/nginx_ssl"
TOOLS_DIR="${SCRIPT_DIR}/tools"
YQ_BINARY="${TOOLS_DIR}/yq"

# Set up yq
setup_yq

# Prompt for domains
prompt_domains

# Prompt for OpenAI API
prompt_openai_api

# Prompt for HTTPS option
prompt_https_option

# Create mount directories
echo "Creating mount directories..."
mkdir -p "$POSTGRES_DATA_DIR"
mkdir -p "$OLLAMA_DATA_DIR"
mkdir -p "$OPEN_WEBUI_DATA_DIR"
mkdir -p "$NGINX_CONF_DIR"
mkdir -p "$NGINX_SSL_DIR/${MAIN_DOMAIN}"

# Generate dhparam.pem
generate_dhparam

# Create options-ssl-nginx.conf with provided content
cat > "${NGINX_CONF_DIR}/options-ssl-nginx.conf" <<EOL
ssl_session_cache shared:le_nginx_SSL:10m;
ssl_session_timeout 1440m;
ssl_session_tickets off;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;

ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
EOL

echo "Created options-ssl-nginx.conf with provided SSL configurations."

# Create Nginx configuration
echo "Creating Nginx configuration..."

# Generate main server block and save as 'default' to replace the default config
if [ "$ENABLE_HTTPS" = true ]; then
    cat > "${NGINX_CONF_DIR}/default" <<EOL
server {
    listen 443 ssl;
    server_name ${MAIN_DOMAIN};

    add_header Strict-Transport-Security 'max-age=31536000' always;
    add_header X-Frame-Options 'deny' always;
    add_header X-Content-Type-Options 'nosniff' always;
    add_header X-XSS-Protection '1; mode=block' always;

    location / {
        proxy_pass http://open-webui:8080;
        proxy_http_version 1.1;
        proxy_redirect off;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_connect_timeout 3600s;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
        client_max_body_size 0;
    }

    ssl_certificate /etc/ssl/${MAIN_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/ssl/${MAIN_DOMAIN}/private.key;
    include /etc/nginx/options-ssl-nginx.conf;
    ssl_dhparam /etc/ssl/dhparam.pem;
}

server {
    listen 80;
    server_name ${MAIN_DOMAIN};
    return 301 https://\$host\$request_uri;
}
EOL
else
    cat > "${NGINX_CONF_DIR}/default" <<EOL
server {
    listen 80;
    server_name ${MAIN_DOMAIN};

    location / {
        proxy_pass http://open-webui:8080;
        proxy_http_version 1.1;
        proxy_redirect off;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port 80;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_connect_timeout 3600s;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        send_timeout 3600s;
        client_max_body_size 0;
    }
}
EOL
fi

# Generate redirect server blocks for additional domains
if [ ${#ADDITIONAL_DOMAINS[@]} -gt 0 ]; then
    for domain in "${ADDITIONAL_DOMAINS[@]}"; do
        if [ "$ENABLE_HTTPS" = true ]; then
            mkdir -p "${NGINX_SSL_DIR}/${domain}"
            cat >> "${NGINX_CONF_DIR}/default" <<EOL

server {
    listen 443 ssl;
    server_name ${domain};

    ssl_certificate /etc/ssl/${domain}/fullchain.pem;
    ssl_certificate_key /etc/ssl/${domain}/private.key;
    include /etc/nginx/options-ssl-nginx.conf;
    ssl_dhparam /etc/ssl/dhparam.pem;

    return 301 https://${MAIN_DOMAIN}\$request_uri;
}

server {
    listen 80;
    server_name ${domain};
    return 301 https://${MAIN_DOMAIN}\$request_uri;
}
EOL
        else
            cat >> "${NGINX_CONF_DIR}/default" <<EOL

server {
    listen 80;
    server_name ${domain};
    return 301 http://${MAIN_DOMAIN}\$request_uri;
}
EOL
        fi
    done
else
    echo "No additional domains to configure for redirection."
fi

echo "Nginx configuration has been created."

# Detect GPU
if detect_gpu; then
    GPU_AVAILABLE=true
    echo "GPU detected. Configuring Docker Compose for GPU usage."
    OLLAMA_IMAGE="ollama/ollama:latest"  # Assuming same image works for both CPU and GPU
    OPEN_WEBUI_IMAGE="ghcr.io/open-webui/open-webui:cuda"  # GPU-enabled image
    GPU_DEVICES="all"
else
    GPU_AVAILABLE=false
    echo "No GPU detected. Configuring Docker Compose for CPU usage."
    OLLAMA_IMAGE="ollama/ollama:latest"  # CPU image (update if different)
    OPEN_WEBUI_IMAGE="ghcr.io/open-webui/open-webui:main"  # CPU image
    GPU_DEVICES=""
fi

# Prepare environment variables for open-webui
ENV_VARS=$(cat <<EOF
      OLLAMA_BASE_URL: "http://ollama:11434"
      ENABLE_OPENAI_API: "${ENABLE_OPENAI_API}"
      DATABASE_URL: "postgresql://postgres:postgres@postgresdb/openwebui"
EOF
)

if [ "$ENABLE_OPENAI_API" = true ]; then
    ENV_VARS="${ENV_VARS}
      OPENAI_API_KEY: \"${OPENAI_API_KEY}\""
fi

# Generate docker-compose.yml
echo "Generating docker-compose.yml..."

cat > "${ROOT_PATH}/docker-compose.yml" <<EOL
version: '3.8'

services:
  postgres:
    image: postgres:latest
    container_name: postgresdb
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: openwebui
    volumes:
      - "${POSTGRES_DATA_DIR}:/var/lib/postgresql/data"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  ollama:
    image: ${OLLAMA_IMAGE}
    container_name: ollama
    restart: unless-stopped
    tty: true
    volumes:
      - "${OLLAMA_DATA_DIR}:/root/.ollama"
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - backend

  open-webui:
    build:
      context: .
      args:
        OLLAMA_BASE_URL: '/ollama'
      dockerfile: Dockerfile
    image: ${OPEN_WEBUI_IMAGE}
    container_name: open-webui
    volumes:
      - "${OPEN_WEBUI_DATA_DIR}:/app/backend/data"
    depends_on:
      ollama:
        condition: service_started
      postgres:
        condition: service_healthy
    environment:
${ENV_VARS}
    extra_hosts:
      - host.docker.internal:host-gateway
    restart: unless-stopped
    networks:
      - backend

  nginx:
    image: nginx:latest
    container_name: nginx
    restart: unless-stopped
    ports:
EOL

# Append port mappings based on HTTPS choice
if [ "$ENABLE_HTTPS" = true ]; then
    cat >> "${ROOT_PATH}/docker-compose.yml" <<EOL
      - "80:80"
      - "443:443"
EOL
else
    cat >> "${ROOT_PATH}/docker-compose.yml" <<EOL
      - "80:80"
EOL
fi

# Append remaining Nginx configurations
cat >> "${ROOT_PATH}/docker-compose.yml" <<EOL
    volumes:
      - "${NGINX_CONF_DIR}/default:/etc/nginx/conf.d/default.conf"
      - "${NGINX_CONF_DIR}/options-ssl-nginx.conf:/etc/nginx/options-ssl-nginx.conf"
      - "${NGINX_SSL_DIR}/dhparam.pem:/etc/ssl/dhparam.pem"
      - "${NGINX_SSL_DIR}/${MAIN_DOMAIN}:/etc/ssl/${MAIN_DOMAIN}"
EOL

# Mount additional domains' SSL certificates if HTTPS is enabled
if [ "$ENABLE_HTTPS" = true ] && [ ${#ADDITIONAL_DOMAINS[@]} -gt 0 ]; then
    for domain in "${ADDITIONAL_DOMAINS[@]}"; do
        cat >> "${ROOT_PATH}/docker-compose.yml" <<EOL
      - "${NGINX_SSL_DIR}/${domain}:/etc/ssl/${domain}"
EOL
    done
fi

# Append dependencies and networks
cat >> "${ROOT_PATH}/docker-compose.yml" <<EOL
    depends_on:
      - open-webui
    networks:
      - frontend
      - backend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
EOL

# Post-process docker-compose.yml to handle GPU settings
# Since Docker Compose doesn't support conditionals directly, we'll use yq if GPU is available
if [ "$GPU_AVAILABLE" = true ]; then
    echo "Adding GPU configurations to docker-compose.yml..."

    # Define yq filters
    GPU_FILTER_OLLAMA='.services.ollama += {
  "deploy": {
    "resources": {
      "reservations": {
        "devices": [
          {
            "driver": "nvidia",
            "count": "all",
            "capabilities": ["gpu"]
          }
        ]
      }
    }
  },
  "environment": {
    "NVIDIA_VISIBLE_DEVICES": "all"
  }
}'

    GPU_FILTER_OPEN_WEBUI='.services["open-webui"] += {
  "deploy": {
    "resources": {
      "reservations": {
        "devices": [
          {
            "driver": "nvidia",
            "count": "all",
            "capabilities": ["gpu"]
          }
        ]
      }
    }
  }
}'

    # Apply yq filters with correct syntax (options before arguments)
    "${YQ_BINARY}" eval -i "${GPU_FILTER_OLLAMA}" "${ROOT_PATH}/docker-compose.yml"
    "${YQ_BINARY}" eval -i "${GPU_FILTER_OPEN_WEBUI}" "${ROOT_PATH}/docker-compose.yml"

    echo "GPU configurations added successfully."
fi

echo "docker-compose.yml has been generated successfully."

# Inform the user about SSL certificate placement
if [ "$ENABLE_HTTPS" = true ]; then
    echo ""
    echo "=============================================="
    echo "SSL Certificate Setup"
    echo "=============================================="
    echo "Please ensure that your SSL certificates are placed in the following directories:"
    echo ""
    echo "Main Domain (${MAIN_DOMAIN}):"
    echo "  - Private Key: ${NGINX_SSL_DIR}/${MAIN_DOMAIN}/private.key"
    echo "  - Full Chain Certificate: ${NGINX_SSL_DIR}/${MAIN_DOMAIN}/fullchain.pem"
    echo ""
    if [ ${#ADDITIONAL_DOMAINS[@]} -gt 0 ]; then
        echo "Additional Domains:"
        for domain in "${ADDITIONAL_DOMAINS[@]}"; do
            echo "  - ${domain}:"
            echo "      - Private Key: ${NGINX_SSL_DIR}/${domain}/private.key"
            echo "      - Full Chain Certificate: ${NGINX_SSL_DIR}/${domain}/fullchain.pem"
        done
    fi
    echo ""
    echo "Ensure that the certificate paths in the Nginx configuration match the actual certificate locations."
    echo "=============================================="
    echo ""
else
    echo ""
    echo "=============================================="
    echo "HTTP Configuration"
    echo "=============================================="
    echo "Your Nginx is configured to serve over HTTP without SSL certificates."
    echo "Ensure that your firewall settings allow traffic on port 80."
    echo "=============================================="
    echo ""
fi

# Optionally, you can start the services automatically
# Uncomment the following lines if you want the script to run docker-compose up -d after setup

# echo "Starting Docker Compose services..."
# docker-compose -f "${ROOT_PATH}/docker-compose.yml" up -d
# echo "Docker Compose services started successfully."
# echo "Setup complete."
