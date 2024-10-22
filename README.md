# Docker Environment Setup with PostgreSQL, Ollama, Open WebUI, and Nginx

![Docker Logo](https://www.docker.com/sites/default/files/d8/2019-07/Moby-logo.png)

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
  - [Running the Setup Script](#running-the-setup-script)
  - [Interactive Prompts](#interactive-prompts)
- [Configuration Details](#configuration-details)
  - [Domain Names and IP Addresses](#domain-names-and-ip-addresses)
  - [HTTPS Setup](#https-setup)
  - [OpenAI API Integration](#openai-api-integration)
  - [GPU Configuration](#gpu-configuration)
- [Directory Structure](#directory-structure)
- [SSL Certificate Setup](#ssl-certificate-setup)
- [Starting the Services](#starting-the-services)
- [Stopping the Services](#stopping-the-services)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Introduction

This repository provides a **Bash script** (`setup_docker.sh`) that automates the setup of a **Docker Compose** environment comprising:

- **PostgreSQL**: A powerful, open-source object-relational database system.
- **Ollama**: A service (assuming a specific use case; ensure to replace with actual description if different).
- **Open WebUI**: A web-based user interface for managing services.
- **Nginx**: A high-performance web server and reverse proxy.

The script intelligently detects GPU availability to configure services accordingly and offers options to enable HTTPS and integrate the OpenAI API.

## Features

- **Automatic GPU Detection**: Configures Docker services to utilize GPU resources if available.
- **Flexible Domain Configuration**: Allows users to specify multiple domain names or IP addresses.
- **HTTPS Support**: Option to enable secure HTTPS connections using SSL certificates.
- **OpenAI API Integration**: Enables integration with the OpenAI API by providing an API key.
- **Automated Configuration Generation**: Generates `docker-compose.yml` and Nginx configuration files based on user inputs.
- **Tool Management**: Downloads and manages necessary tools like `yq` for YAML processing.

## Prerequisites

Before running the setup script, ensure that the following prerequisites are met:

### Required Software

- **Docker**: [Install Docker](https://docs.docker.com/get-docker/)
- **Docker Compose**: [Install Docker Compose](https://docs.docker.com/compose/install/)
- **Bash Shell**: Ensure you are running a Unix-like operating system with Bash.

### Optional (Based on Configuration)

- **NVIDIA Drivers and Docker Toolkit**: Required if you plan to utilize GPU resources.
  - [Install NVIDIA Drivers](https://www.nvidia.com/Download/index.aspx)
  - [Install NVIDIA Docker Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- **Certbot**: Required for SSL certificate generation if enabling HTTPS.
  - [Install Certbot](https://certbot.eff.org/instructions)

## Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/yourusername/your-repo-name.git
   cd your-repo-name
   ```

2. **Make the Setup Script Executable**

   ```bash
   chmod +x setup_docker.sh
   ```

## Usage

### Running the Setup Script

Execute the `setup_docker.sh` script to initiate the Docker environment setup:

```bash
./setup_docker.sh
```

### Interactive Prompts

The script will guide you through several interactive prompts to customize your Docker setup:

1. **Root Path for Docker Volumes**
   - **Description**: Specifies where Docker volumes will be stored on your host system.
   - **Default**: The directory where the script resides.

2. **Domain Names or IP Addresses**
   - **Description**: Enter one or more domain names (e.g., `chat.example.com`) or IP addresses (e.g., `192.168.1.1`).
   - **Usage**:
     - The first valid entry becomes the main domain.
     - Additional entries will redirect to the main domain.

3. **Enable OpenAI API**
   - **Description**: Choose whether to integrate the OpenAI API.
   - **Options**:
     - **Yes**: You'll be prompted to enter your OpenAI API key.
     - **No**: The OpenAI API integration will be disabled.

4. **Enable HTTPS**
   - **Description**: Decide whether to enable HTTPS for secure connections.
   - **Options**:
     - **Yes**: Configures Nginx to use SSL certificates.
     - **No**: Configures Nginx to use HTTP only.

## Configuration Details

### Domain Names and IP Addresses

- **Main Domain**: The primary domain where your services will be accessible.
- **Additional Domains**: Any extra domains or IPs will redirect to the main domain.

**Example**:

```
Main Domain: chat.example.com
Additional Domain: api.example.com
```

### HTTPS Setup

- **Enabling HTTPS**:
  - **Requires SSL Certificates**: Place your SSL certificates in the specified directories.
  - **Nginx Configuration**: Configured to listen on port `443` with SSL.

- **Disabling HTTPS**:
  - **Nginx Configuration**: Configured to listen on port `80` without SSL.

**Note**: It's highly recommended to enable HTTPS to secure data in transit.

### OpenAI API Integration

- **Enabling OpenAI API**:
  - **API Key**: Provide your OpenAI API key during the setup.
  - **Environment Variables**: The API key is injected into the Docker environment for `open-webui`.

- **Disabling OpenAI API**:
  - **No API Key**: The integration is skipped, and related environment variables are excluded.

### GPU Configuration

- **GPU Detected**:
  - **Ollama and Open WebUI**: Configured to utilize GPU resources.
  - **Docker Compose**: Modified to include GPU-specific settings using `yq`.

- **GPU Not Detected**:
  - **Ollama and Open WebUI**: Configured to run on CPU.
  - **Docker Compose**: No GPU-specific settings applied.

## Directory Structure

After running the setup script, the following directory structure will be created:

```
/your-root-path
│
├── docker-compose.yml
├── postgres_data/
├── ollama_data/
├── open_webui_data/
├── nginx_conf/
│   ├── main.conf
│   └── redirects.conf
├── nginx_certs/
└── tools/
    └── yq
```

- **docker-compose.yml**: Defines the Docker services and configurations.
- **postgres_data/**: Stores PostgreSQL data.
- **ollama_data/**: Stores Ollama data.
- **open_webui_data/**: Stores Open WebUI data.
- **nginx_conf/**: Contains Nginx configuration files.
  - **main.conf**: Main Nginx server block.
  - **redirects.conf**: Redirects for additional domains.
- **nginx_certs/**: Stores SSL certificates (if HTTPS is enabled).
- **tools/**: Contains utility binaries like `yq`.

## SSL Certificate Setup

If you opted to enable HTTPS during the setup, follow these steps to obtain and place your SSL certificates:

1. **Obtain SSL Certificates Using Certbot**

   Replace `your-main-domain.com` with your actual main domain.

   ```bash
   sudo certbot certonly --webroot -w /path/to/nginx_conf -d your-main-domain.com
   ```

   For additional domains:

   ```bash
   sudo certbot certonly --webroot -w /path/to/nginx_conf -d additional-domain1.com -d additional-domain2.com
   ```

2. **Place Certificates in the Specified Directory**

   Ensure that your certificates are located in:

   ```
   /your-root-path/nginx_certs/live/your-main-domain.com/fullchain.pem
   /your-root-path/nginx_certs/live/your-main-domain.com/privkey.pem
   ```

   Repeat for additional domains as needed.

3. **Verify Nginx Configuration**

   Ensure that the certificate paths in `nginx_conf/main.conf` and `nginx_conf/redirects.conf` match the actual certificate locations.

## Starting the Services

Once the setup is complete and SSL certificates are in place (if HTTPS is enabled), start the Docker services:

```bash
docker-compose -f /your-root-path/docker-compose.yml up -d
```

**Note**: Replace `/your-root-path` with the actual root path you specified during setup.

### Automatically Starting Services

The `setup_docker.sh` script includes optional lines to automatically start the services after setup. To enable this feature:

1. **Edit the Script**

   Uncomment the following lines at the end of the script:

   ```bash
   # echo "Starting Docker Compose services..."
   # docker-compose -f "${ROOT_PATH}/docker-compose.yml" up -d
   # echo "Docker Compose services started successfully."
   # echo "Setup complete."
   ```

2. **Run the Script Again**

   Execute the script to perform the setup and automatically start the services.

## Stopping the Services

To stop and remove the Docker services, execute:

```bash
docker-compose -f /your-root-path/docker-compose.yml down
```

## Troubleshooting

### Common Issues

1. **Docker or Docker Compose Not Installed**

   - **Solution**: Follow the [Prerequisites](#prerequisites) section to install Docker and Docker Compose.

2. **GPU Not Detected Despite Having NVIDIA Hardware**

   - **Solution**:
     - Ensure NVIDIA drivers are correctly installed.
     - Verify that the NVIDIA Docker Toolkit is installed.
     - Restart Docker service: `sudo systemctl restart docker`

3. **Nginx Fails to Start Due to SSL Issues**

   - **Solution**:
     - Verify that SSL certificates are correctly placed in the `nginx_certs` directory.
     - Ensure certificate paths in Nginx configuration files are accurate.
     - Check certificate validity using tools like [SSL Labs](https://www.ssllabs.com/ssltest/).

4. **Open WebUI Not Accessible**

   - **Solution**:
     - Check if all Docker services are running: `docker-compose ps`
     - Review logs for any service-specific errors: `docker-compose logs open-webui`

### Viewing Logs

To view logs for all services:

```bash
docker-compose -f /your-root-path/docker-compose.yml logs -f
```

To view logs for a specific service (e.g., Nginx):

```bash
docker-compose -f /your-root-path/docker-compose.yml logs -f nginx
```

## Contributing

Contributions are welcome! Please follow these steps to contribute:

1. **Fork the Repository**

2. **Create a Feature Branch**

   ```bash
   git checkout -b feature/YourFeatureName
   ```

3. **Commit Your Changes**

   ```bash
   git commit -m "Add your feature"
   ```

4. **Push to the Branch**

   ```bash
   git push origin feature/YourFeatureName
   ```

5. **Open a Pull Request**

Provide a clear description of your changes and the problem they solve.

## License

This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgements

- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Nginx](https://www.nginx.com/)
- [Certbot](https://certbot.eff.org/)
- [yq](https://github.com/mikefarah/yq)

---

**Happy Dockering! 🚀**

