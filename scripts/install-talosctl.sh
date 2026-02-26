#!/bin/bash

if command -v talosctl &> /dev/null; then
    echo "talosctl is already installed."
    echo "Current version:"
    talosctl version --client --short
    exit 0
fi

echo "talosctl not found. Starting installation..."

# Detect the operating system
OS="$(uname -s)"

echo "Detecting operating system: $OS"

if [ "$OS" == "Darwin" ]; then
    
    # Check if Homebrew is installed
    if command -v brew &> /dev/null; then
        echo "Homebrew detected. Installing talosctl..."
        brew install siderolabs/tap/talosctl
    else
        echo "Error: Homebrew is not installed."
        echo "Please install Homebrew first or use the manual method."
        exit 1
    fi

elif [ "$OS" == "Linux" ]; then
    echo "Downloading and installing talosctl..."
    
    curl -sL https://talos.dev/install | sh

else
    echo "Detected error. Unsupported operating system: $OS"
    exit 1
fi

echo ""
echo "Installation completed."
talosctl version --client