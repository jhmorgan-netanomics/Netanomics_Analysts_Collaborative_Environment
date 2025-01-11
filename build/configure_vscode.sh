#!/bin/bash

# Create the .vscode directory and settings.json file
mkdir -p /workspace/.vscode

# Configure settings.json
cat <<EOL > /workspace/.vscode/settings.json
{
    "julia.executablePath": "/usr/bin/julia",
    "r.rterm.linux": "/usr/local/bin/R",
    "r.rpath.linux": "/usr/local/bin/R",
    "python.pythonPath": "/usr/local/bin/python",
    "terminal.integrated.fontFamily": "monospace",
    "julia.additionalArgs": [
        "--banner=yes"
    ],
    "r.lsp.diagnostics": false
}
EOL

echo ".vscode/settings.json configured successfully."

# Create the .bashrc file with DISPLAY setting
cat <<EOL > /workspace/.vscode/.bashrc
# Setting Port to be :102 to Support X11 Forward via Xephyr
export DISPLAY=:102
EOL

echo ".vscode/.bashrc file created with DISPLAY=:102 setting."
