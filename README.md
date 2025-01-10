# Welcome to the Netanomics Collaborative Environment

The Netanomics Collaborative Environment provides an integrated workspace for **Julia**, **R**, and **Python**, enabling seamless collaboration, reproducibility, and scalability for data analysis and visualization.

This environment also supports terminal-based tools such as **CmdStan**, **NIST Dataplot**, **Generic Mapping Tools (GMT)**, and **Graphviz**, with **VSCode settings** for effortless development. Whether you're using JupyterLab, RStudio Server, or terminal workflows, this setup ensures consistency and ease of use.

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
3. **x11docker**: For managing X11 forwarding and Xephyr environments.
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

## Usage

### Managing JupyterLab

To manage JupyterLab containers, use the `manage_jupyterlab.sh` script:

```bash
# Usage: ./manage_jupyterlab.sh [container_name] [ip_address] [port]
./manage_jupyterlab.sh BEND 52.70.230.30 8888
