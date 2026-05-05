#!/bin/bash
# build-all.sh - Arnau Libori i Ayoub El Ballaoui
# Construeix totes les imatges Docker del projecte

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== DockerSecLab - Build de totes les imatges ==="
echo "Arnau Libori i Ayoub El Ballaoui"
echo ""

if ! docker info &> /dev/null; then
    echo "ERROR: Docker no esta en execucio"
    echo "Inicia Docker amb: sudo systemctl start docker"
    exit 1
fi

build_image() {
    NAME=$1
    PATH_REL=$2
    FULL_PATH="$PROJECT_DIR/vulnerabilities/$PATH_REL"

    echo "--- Construint: $NAME ---"

    if [ ! -d "$FULL_PATH" ]; then
        echo "  AVIS: Carpeta no trobada: $FULL_PATH"
        echo ""
        return
    fi

    if [ -f "$FULL_PATH/Dockerfile.vulnerable" ]; then
        docker build -f "$FULL_PATH/Dockerfile.vulnerable" \
                     -t "seclab-vuln:$NAME" \
                     "$FULL_PATH" > /dev/null 2>&1 && \
            echo "  Vulnerable: OK" || echo "  Vulnerable: ERROR"
    fi

    if [ -f "$FULL_PATH/Dockerfile.fixed" ]; then
        docker build -f "$FULL_PATH/Dockerfile.fixed" \
                     -t "seclab-fixed:$NAME" \
                     "$FULL_PATH" > /dev/null 2>&1 && \
            echo "  Fixed: OK" || echo "  Fixed: ERROR"
    fi
    echo ""
}

echo "== Vulnerabilitats de Xarxa =="
echo ""
build_image "apache"  "network/apache"
build_image "ftp"     "network/ftp"
build_image "redis"   "network/redis"

echo "== Vulnerabilitats de Configuracio de Serveis =="
echo ""
build_image "mysql"   "configuration/mysql"
build_image "nginx"   "configuration/nginx"
build_image "ssh"     "configuration/ssh"

echo "== Vulnerabilitats de Contenidor/Host =="
echo ""
build_image "no-resource-limits"        "container-host/no-resource-limits"
build_image "unnecessary-capabilities"  "container-host/unnecessary-capabilities"
build_image "dangerous-mounts"          "container-host/dangerous-mounts"

echo "=== Build finalitzat ==="
echo ""
echo "Imatges creades:"
docker images | grep seclab
