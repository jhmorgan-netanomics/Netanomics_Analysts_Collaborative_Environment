#!/bin/bash

# Check if dropbox_keys.json exists
if [ -f "./dropbox_keys.json" ]; then
    echo "Dropbox keys found. Proceeding with integration..."
    cp ./dropbox_keys.json /tmp/dropbox_keys.json
else
    echo "Dropbox keys not found. Skipping Dropbox integration."
fi
