#!/bin/bash
# build-all.sh - Arnau Libori i Ayoub El Ballaoui
# Construeix totes les imatges Docker del projecte

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== DockerSecLab - Build de totes les imatges ==="
echo "Arnau Libori i Ayoub El Ballaoui"
echo ""

if ! docker info &> /dev/null; then
    echo "ERROR: Docker no esta en execució"
    exit 1
fi

build_image() {
    NAME=$1
    PATH_REL=$2
    FULL_PATH="$PROJECT_DIR/vulnerabilities/$PATH_REL"

    echo "--- Construint: $NAME ---"

    if [ ! -d "$FULL_PATH" ]; then
        echo "  AVIS: Carpeta no trobada: $FULL_PATH"
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

build_image "running-as-root"        "configuration/running-as-root"
build_image "exposed-ports"          "network/exposed-ports"
build_image "hardcoded-credentials"  "configuration/hardcoded-credentials"
build_image "obsolete-versions"      "configuration/obsolete-versions"
build_image "no-resource-limits"     "container-host/no-resource-limits"
build_image "unnecessary-capabilities" "container-host/unnecessary-capabilities"
build_image "dangerous-mounts"       "container-host/dangerous-mounts"
build_image "unencrypted-communication" "network/unencrypted-communication"
build_image "insecure-network-config" "network/insecure-network-config"

echo "=== Build finalitzat ==="
echo ""
echo "Imatges creades:"
docker images | grep seclab
