# Welcome to the Netanomics Collaborative Environment

The Netanomics Collaborative Environment provides an integrated workspace for R, Julia, Python, allowing seamless collaboration and reproducibility in data analysis and research.

The environment also provides terminal-based tools such as NIST Dataplot, Generic Mapping Tools (GMT), and Graphviz with VSCode settings to allow for the easy execution of these programs.

## Features

- **RStudio Server**: Accessible from your browser, enabling advanced R development with server-side execution.
- **JupyterLab**: A flexible, interactive environment for Python, Julia, and R workflows.
- **Dockerized Setup**: Portable and reproducible environments using Docker containers.
- **Simplified Management Scripts**:
  - `manage_rstudio_server.sh` for managing RStudio Server containers.
  - `manage_jupyterlab.sh` for managing JupyterLab containers.
  - `run_with_xephyr.sh` for providing X11 forwarding for terminal-based applications.
  - `start_workspace.sh` for initializing your workspace and creating user accounts.

## Requirements

- **Docker**: Ensure Docker is installed on your system.
- **Shell Access**: Ability to execute Bash scripts.
- 

## Repository

The repository for this project is available on GitHub:  
[Netanomics Collaborative Environment Repository](https://github.com/jhmorgan-netanomics/Netanomics_Analysts_Collaborative_Environment/tree/main)

## Usage

### Managing JupyterLab

To manage JupyterLab containers, use the `manage_jupyterlab.sh` script:

```bash
# Usage: ./manage_jupyterlab.sh [container_name] [ip_address] [port]
./manage_jupyterlab.sh BEND 52.70.230.30 8888
