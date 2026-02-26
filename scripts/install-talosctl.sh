#!/bin/bash

if command -v talosctl &> /dev/null; then
    echo "talosctl ya está instalado."
    echo "Versión actual:"
    talosctl version --client --short
    exit 0
fi

echo "talosctl no encontrado. Iniciando instalación..."

# Detectar el sistema operativo
OS="$(uname -s)"

echo "Detectando sistema operativo: $OS"

if [ "$OS" == "Darwin" ]; then
    
    # Comprobar si Homebrew está instalado
    if command -v brew &> /dev/null; then
        echo "Homebrew detectado. Instalando talosctl..."
        brew install siderolabs/tap/talosctl
    else
        echo "Error: No tienes Homebrew instalado."
        echo "Por favor instala Homebrew primero o usa el método manual."
        exit 1
    fi

elif [ "$OS" == "Linux" ]; then
    echo "Descargando e instalando talosctl..."
    
    curl -sL https://talos.dev/install | sh

else
    echo "Error detectado. Sistema operativo no soportado: $OS"
    exit 1
fi

echo ""
echo "Instalación completada."
talosctl version --client
