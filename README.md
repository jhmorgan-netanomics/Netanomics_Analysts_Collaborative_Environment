# Welcome to the Netanomics Collaborative Environment

The Netanomics Collaborative Environment provides an integrated workspace for **Julia**, **R**, and **Python**, enabling analysts to collaborate within an integrated and scaleable environment.

This environment also supports terminal-based tools such as **CmdStan**, **NIST Dataplot**, **Generic Mapping Tools (GMT)**, and **Graphviz**, with **VSCode settings** for streamlined development. Whether you're using JupyterLab, RStudio Server, or terminal workflows, this setup ensures consistency and ease of use.

The docker can be pulled using:
 ```bash
docker pull jhm18/netanomics_analysts_collaborative_environment:latest
 ```

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
```
- **`container_name`**: (Optional) Name of the container. Defaults to collaborative-env-jupyter.
- **`ip_address`**: (Optional) IP address to bind the server. Defaults to `127.0.0.1`.
- **`port`**: (Optional) Port to expose JupyterLab. Defaults to 8888.

If no arguments are provided, the script uses the default values and creates a new container if one does not exist.

---

### `run_with_xephyr.sh`

#### Overview
The `run_with_xephyr.sh` script is designed to facilitate X11 forwarding for graphical applications within the `collaborative-env` Docker container. It uses Xephyr to create an isolated X server environment for the container, ensuring that GUI-based workflows can be displayed on the host system.

#### Features
- Dynamically assigns an available `DISPLAY` for Xephyr.
- Configures `xhost` to allow host X server connections.
- Launches Xephyr with a resolution of `1280x720`.
- Passes the Xephyr `DISPLAY` and X11 socket to the Docker container.
- Cleans up the Xephyr process when the container exits.

#### Usage
```bash
./run_with_xephyr.sh [container_name]
```
- **`container_name`**: (Optional) Name of the container. Attaches to the container if it is running.

This script runs without additional arguments and automatically configures the Xephyr environment for the container. Ensure that X11 is running on the host system before executing the script.

---
---

### `start_workspace.sh`

#### Overview
The `start_workspace.sh` script initializes the workspace for the `collaborative-env` Docker container. It handles user account setup, Git configuration, and workflow initialization, ensuring a flexible environment for a variety of use cases. This function can both be called by the host functions described previously or used within the container to initiate a workflow.

#### Features
- Configures `git` globally if not already set, prompting the user for `user.name` and `user.email`.
- Checks for the existence of the `netanomics` user and prompts for a new user account if it doesn’t exist.
- Updates RStudio Server configuration for the current or newly created user.
- Initializes the specified workflow (`rstudio`, `jupyter`, or X11 with Openbox).
- Defaults to an interactive shell if no `DISPLAY` is available.

#### Usage
```bash
./start_workspace.sh [workflow]
```
- **`workflow`**: (Optional) Specifies the workflow to start. Accepted values are:
  - `rstudio`: Starts RStudio Server.
  - `jupyter`: Starts JupyterLab.
  - (No argument): Starts an X11 session with Openbox or an interactive shell if no `DISPLAY` is set.

If no arguments are provided, the script attempts to start an X11 session or falls back to a basic shell.

---
## X11 Forwarding & VSCode

### **1. Configure the Display on Your Local Machine**

On your **local machine**, ensure that SSH is configured to forward X11 traffic. Edit or create the `~/.ssh/config` file with the following content:

```plaintext
Host your-ec2-instance-name
    HostName <your-ec2-instance-ip>
    User <your-username>
    ForwardX11 yes
    ForwardX11Trusted yes
```

Replace the placeholders:
- **`your-ec2-instance-name`**: A friendly alias for your host (e.g., `ec2-host`).
- **`<your-ec2-instance-ip>`**: The public IP address of your EC2 instance.
- **`<your-username>`**: The username for your EC2 instance (e.g., `ubuntu`).

Additionally, add the following conditional export to your `.bashrc` or `.zshrc` file on your local machine to set the `DISPLAY` variable specifically for VSCode's integrated terminal:
```bash
if [[ $TERM_PROGRAM == "vscode" ]]; then
    export DISPLAY=localhost:10.0
fi
```

For **Windows users**, add the following line to your PowerShell profile (e.g., `Microsoft.PowerShell_profile.ps1`):
```powershell
if ($env:TERM_PROGRAM -eq "vscode") {
    $env:DISPLAY = "localhost:10.0"
}
```

---

#### **Install X11 Tools**
To use X11 forwarding, you will need an X11 server installed on your local machine:
- `VcXsrv`: Windows Operating Systems
- `XQuartz`: OsX (Mac) Operating Systems

### **2. Configure the Display on the Host (EC2 Instance)**

If you are running the **Netanomics Collaborative Environment** on your own EC2 instance, you need to configure the instance to permit X11 forwarding. Follow these steps to ensure proper setup:

#### **1. Update the SSH Daemon Configuration**
On the **EC2 instance**, edit the SSH daemon configuration file located at `/etc/ssh/sshd_config` to enable X11 forwarding. You will need root or sudo privileges to do this:

```bash
sudo nano /etc/ssh/sshd_config
```

Ensure the following lines are present and not commented out (remove the `#` if necessary):

```plaintext
X11Forwarding yes
X11DisplayOffset 10
X11UseLocalhost yes
```

Save the file and restart the SSH service to apply the changes:

```bash
sudo systemctl restart sshd
```

---

#### **2. Allow Local Connections to the X11 Server**
Run the following command to allow local connections to the X11 server:

```bash
xhost +local:
```

To make this setting persistent, you can add it to your `~/.bashrc` or `~/.zshrc` file:

```bash
# Allow local connections to the X11 server
if command -v xhost &>/dev/null; then
    xhost +local:
fi
```

---

- **Windows**: Download and install [VcXsrv](https://sourceforge.net/projects/vcxsrv/).
- **macOS**: Download and install [XQuartz](https://www.xquartz.org/).

Ensure the X11 server is running before starting your SSH session to the host.
