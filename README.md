# Welcome to the Netanomics Collaborative Environment

The Netanomics Collaborative Environment provides an integrated workspace for **Julia**, **R**, and **Python**, enabling analysts to collaborate within an integrated and scaleable environment.

This environment also supports terminal-based tools such as **CmdStan**, **NIST Dataplot**, **Generic Mapping Tools (GMT)**, and **Graphviz**, with **VSCode settings** for streamlined development. Whether you're using JupyterLab, RStudio Server, or terminal workflows, this setup ensures consistency and ease of use.

---

## Features

### Integrated Development Tools:
- **RStudio Server**: Access RStudio directly in your browser, enabling powerful R development with server-side execution.
- **JupyterLab**: A flexible and interactive interface for Python, Julia, and R workflows, perfect for notebooks and exploratory analysis.

### Terminal-Based Applications:
- **CmdStan**: A command-line tool for probabilistic modeling.
- **NIST Dataplot**: A command-line tool for statistical analysis and visualization.
- **Generic Mapping Tools (GMT)**: Create high-quality geographic maps directly from the command line.
- **Graphviz**: Generate graph visualizations programmatically for analysis and presentations.

### Simplified Management Scripts:
- `manage_rstudio_server.sh`: Manage RStudio Server containers with ease.
- `manage_jupyterlab.sh`: Start, stop, and manage JupyterLab sessions.
- `run_with_xephyr.sh`: Enable X11 forwarding for graphical applications within the container.
- `start_workspace.sh`: Initialize your workspace, set up user accounts, and configure the environment.

### Portable & Reproducible:
- **Dockerized Environment**: The entire setup is encapsulated in Docker containers, ensuring consistent behavior across systems and eliminating dependency issues.

---

## Requirements

To use the Netanomics Collaborative Environment, ensure you have the following installed on your system:

1. **Docker**: [Install Docker](https://docs.docker.com/get-docker/)
2. **Shell Access**: The ability to execute Bash scripts.
3. **x11docker**: For managing X11 forwarding and Xephyr environments. This component is not essential, but facilitates the use of terminal-based tools such as NIST Dataplot.
   - [Install x11docker](https://github.com/mviereck/x11docker):
     ```bash
     sudo apt install x11docker
     ```
   - x11docker is critical for providing secure and functional X11 forwarding within Docker.

---

## Getting Started

### Step 1: Clone the Repository
```bash
git clone https://github.com/jhmorgan-Netanomics/Netanomics_Analysts_Collaborative_Environment.git
cd Netanomics_Analysts_Collaborative_Environment
```

---

## Usage

### `manage_rstudio_server.sh`

#### Overview
The `manage_rstudio_server.sh` script is designed to manage an RStudio Server container within the `collaborative-env` Docker environment. It checks if the container exists and starts or creates it as needed, ensuring that the RStudio Server is accessible on the specified IP address and port. This script streamlines container management and ensures that any conflicting processes using the specified port are terminated before launching the server.

#### Features
- Automatically checks and frees a specified port if it's already in use.
- Attaches to an existing running container if found.
- Starts a stopped container or creates a new one if none exists.
- Can run without arguments, automatically creating a new container with default settings.

#### Usage
```bash
./manage_rstudio_server.sh [container_name] [ip_address] [port]
```
- **`container_name`**: (Optional) Name of the container. Defaults to `collaborative-env-rstudio`.
- **`ip_address`**: (Optional) IP address to bind the server. Defaults to `127.0.0.1`.
- **`port`**: (Optional) Port to expose RStudio Server. Defaults to `8787`.

If no arguments are provided, the script uses the default values and creates a new container if one does not exist.

---

### `manage_jupyterlab.sh`

#### Overview
The `manage_jupyterlab.sh` script is designed to manage a JupyterLab container within the `collaborative-env` Docker environment. It checks if the container exists and starts or creates it as needed, ensuring that JupyterLab is accessible on the specified IP address and port. The script also ensures that any conflicting processes using the specified port are terminated before launching the JupyterLab server.

#### Features
- Automatically checks and frees a specified port if it's already in use.
- Attaches to an existing running container if found.
- Starts a stopped container or creates a new one if none exists.
- Can run without arguments, automatically creating a new container with default settings.

#### Usage
```bash
./manage_jupyterlab.sh [container_name] [ip_address] [port]

#### Usage
```bash
./manage_jupyterlab.sh [container_name] [ip_address] [port]

```
- **`container_name`**: (Optional) Name of the container. Defaults to collaborative-env-jupyter.
- **`ip_address`**: (Optional) IP address to bind the server. Defaults to `127.0.0.1`.
- **`port`**: (Optional) Port to expose JupyterLab. Defaults to 8888.

If no arguments are provided, the script uses the default values and creates a new container if one does not exist.

---
