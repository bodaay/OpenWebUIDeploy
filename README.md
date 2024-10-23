# Docker Compose Setup Script for Open WebUI with Ollama and Nginx

This script automates the setup of a Docker Compose environment featuring PostgreSQL, Ollama, Open WebUI, and Nginx. It detects GPU availability to configure services accordingly and helps you set up necessary directories and configurations.

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Interactive Prompts](#interactive-prompts)
- [Configuration Details](#configuration-details)
  - [Directory Structure](#directory-structure)
  - [SSL Certificates](#ssl-certificates)
- [Starting the Services](#starting-the-services)
- [Additional Notes](#additional-notes)
- [Troubleshooting](#troubleshooting)
- [License](#license)

---

## Features

- **Automatic GPU Detection**: Configures services for GPU usage if available.
- **Custom Domain Configuration**: Supports setting up multiple domains or IP addresses.
- **OpenAI API Integration**: Optionally enable the OpenAI API by providing your API key.
- **HTTPS Support**: Optionally enable HTTPS with custom SSL certificates.
- **Customizable Paths**: Choose the root path for Docker volumes and configurations.
- **Automated Nginx Configuration**: Generates Nginx configuration files based on your input.
- **SSL Setup**: Assists in setting up SSL certificates and `dhparam.pem`.

---

## Prerequisites

- **Docker**: Install from [Docker's official website](https://docs.docker.com/get-docker/).
- **Docker Compose**: Install from [Docker Compose documentation](https://docs.docker.com/compose/install/).
- **NVIDIA Drivers and Docker Toolkit**: Required if you plan to use GPU acceleration.

---

## Usage

1. **Clone the Repository** (if applicable) or copy the script into your desired directory.

2. **Make the Script Executable**:

   ```bash
   chmod +x setup_docker.sh
   ```

3. **Run the Script**:

   ```bash
   ./setup_docker.sh
   ```

---

## Interactive Prompts

The script will guide you through several prompts:

1. **Root Path for Docker Volumes**:
   - Enter the absolute path where you want to store Docker volumes and configurations.
   - Leave empty to use the script's directory.

2. **Domain Names or IP Addresses**:
   - Enter your main domain or IP address (e.g., `chat.example.com` or `192.168.1.1`).
   - Optionally, enter additional domains or IPs to redirect to the main domain.
   - Type `done` when finished.

3. **Enable OpenAI API**:
   - Choose whether to enable the OpenAI API integration.
   - If enabled, provide your OpenAI API key or leave empty to use a placeholder.

4. **Enable HTTPS**:
   - Choose whether to enable HTTPS for your domain(s).
   - If enabled, you'll need to provide SSL certificates.

---

## Configuration Details

### Directory Structure

After running the script, the following directory structure will be created:

```
your-root-path/
├── docker-compose.yml
├── nginx_conf/
│   ├── default                 # Nginx main configuration file
│   └── options-ssl-nginx.conf  # SSL options configuration
├── nginx_ssl/
│   ├── dhparam.pem             # Generated Diffie-Hellman parameter file
│   ├── your-main-domain/
│   │   ├── private.key         # Your SSL private key (place here)
│   │   └── fullchain.pem       # Your SSL certificate chain (place here)
│   └── additional-domain(s)/   # Additional domains' SSL files (if any)
├── ollama_data/                # Data for Ollama
├── open_webui_data/            # Data for Open WebUI
└── postgres_data/              # Data for PostgreSQL
```

### SSL Certificates

If you enabled HTTPS:

- **SSL Certificates Location**:
  - Main Domain:
    - Private Key: `nginx_ssl/your-main-domain/private.key`
    - Full Chain Certificate: `nginx_ssl/your-main-domain/fullchain.pem`
  - Additional Domains:
    - Place SSL files in `nginx_ssl/your-additional-domain/`

- **dhparam.pem**:
  - Generated automatically and placed in `nginx_ssl/dhparam.pem`.

- **Nginx Configuration**:
  - SSL certificate paths in the Nginx configuration are set to match these directories.

**Important**: Ensure your SSL certificate files are correctly placed before starting the services.

---

## Starting the Services

After configuring and placing your SSL certificates (if HTTPS is enabled), you can start the Docker services:

```bash
docker-compose -f "your-root-path/docker-compose.yml" up -d
```

**Note**: Replace `your-root-path` with the actual path you provided during setup.

---

## Additional Notes

- **GPU Acceleration**:
  - If a GPU is detected, the script configures Docker services to use GPU resources.
  - Uses GPU-enabled Docker images for Ollama and Open WebUI.

- **OpenAI API Integration**:
  - If enabled, your API key is set as an environment variable for the Open WebUI service.

- **Custom Nginx Configuration**:
  - The script generates a `default` configuration file that replaces Nginx's default.
  - It handles domain redirection and proxy settings for Open WebUI.

- **YQ Installation**:
  - The script downloads `yq`, a YAML processor, to handle dynamic Docker Compose modifications.

---

## Troubleshooting

- **SSL Certificate Issues**:
  - Ensure the SSL certificates and private keys are correctly placed and have appropriate permissions.
  - Check that the paths in the Nginx configuration match the actual file locations.

- **Docker Service Failures**:
  - Run `docker-compose logs` to view logs for troubleshooting.
  - Ensure all prerequisites are installed and properly configured.

- **GPU Not Detected**:
  - Verify that NVIDIA drivers and Docker Toolkit are installed.
  - Check GPU accessibility with `nvidia-smi`.

- **Port Conflicts**:
  - Ensure that ports `80` and `443` (if HTTPS is enabled) are not in use by other services.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

**Thank you for using this setup script! If you encounter any issues or have suggestions for improvements, feel free to contribute or reach out.**