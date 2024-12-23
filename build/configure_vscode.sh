#!/bin/bash

# Create the .vscode directory and settings.json file
mkdir -p /workspace/.vscode
cat <<EOL > /workspace/.vscode/settings.json
{
    "julia.executablePath": "/usr/bin/julia",
    "r.rterm.linux": "/usr/local/bin/R",
    "r.rpath.linux": "/usr/local/bin/R",
    "python.pythonPath": "/usr/local/bin/python"
}
EOL

echo ".vscode/settings.json configured successfully."
