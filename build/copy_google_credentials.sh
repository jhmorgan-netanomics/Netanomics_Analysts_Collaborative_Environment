#!/bin/bash

# Check if google_credentials.json exists
if [ -f "./google_credentials.json" ]; then
    echo "Google credentials found. Proceeding with integration..."
    cp ./google_credentials.json /tmp/google_credentials.json
else
    echo "Google credentials not found. Skipping Google integration."
fi
