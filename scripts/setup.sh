#!/bin/bash
# setup.sh - Arnau Libori i Ayoub El Ballaoui
# Instal·lació automatica de Docker i Docker Compose al sistema

set -e

echo "=== DockerSecLab - Setup ==="
echo "Arnau Libori i Ayoub El Ballaoui"
echo ""

# Verificar que s'executa com a root o amb sudo
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Executa aquest script amb sudo"
    echo "  sudo bash setup.sh"
    exit 1
fi

# Actualitzar el sistema
echo "[1/5] Actualitzant el sistema..."
apt-get update -y
apt-get upgrade -y

# Instal·lar dependències
echo "[2/5] Instal·lant dependències..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    net-tools \
    nmap

# Instal·lar Docker
echo "[3/5] Instal·lant Docker..."
if command -v docker &> /dev/null; then
    echo "Docker ja esta instal·lat: $(docker --version)"
else
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo \
        "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io
    echo "Docker instal·lat: $(docker --version)"
fi

# Instal·lar Docker Compose
echo "[4/5] Instal·lant Docker Compose..."
if command -v docker-compose &> /dev/null; then
    echo "Docker Compose ja esta instal·lat: $(docker-compose --version)"
else
    apt-get install -y docker-compose
    echo "Docker Compose instal·lat: $(docker-compose --version)"
fi

# Afegir usuari al grup docker
echo "[5/5] Configurant permisos..."
CURRENT_USER=${SUDO_USER:-$USER}
if ! groups "$CURRENT_USER" | grep -q docker; then
    usermod -aG docker "$CURRENT_USER"
    echo "Usuari $CURRENT_USER afegit al grup docker"
    echo "IMPORTANT: Tanca la sessio i torna a entrar per aplicar els canvis"
else
    echo "Usuari $CURRENT_USER ja pertany al grup docker"
fi

echo ""
echo "=== Setup completat ==="
echo "Verifica la instal·lació amb: docker run hello-world"
