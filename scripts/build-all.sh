#!/bin/bash
# build-all.sh - Arnau Libori i Ayoub El Ballaoui
# Construeix totes les imatges Docker del projecte

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== DockerSecLab - Build de totes les imatges ==="
echo "Arnau Libori i Ayoub El Ballaoui"
echo ""

# Verificar que Docker esta en execució
if ! docker info &> /dev/null; then
    echo "ERROR: Docker no esta en execució"
    echo "Inicia Docker amb: sudo systemctl start docker"
    exit 1
fi

# Llista de vulnerabilitats i les seves rutes
declare -A VULNERABILITIES=(
    ["running-as-root"]="configuration/running-as-root"
    ["exposed-ports"]="network/exposed-ports"
    ["hardcoded-credentials"]="configuration/hardcoded-credentials"
    ["obsolete-versions"]="configuration/obsolete-versions"
    ["no-resource-limits"]="container-host/no-resource-limits"
    ["unnecessary-capabilities"]="container-host/unnecessary-capabilities"
    ["dangerous-mounts"]="container-host/dangerous-mounts"
    ["unencrypted-communication"]="network/unencrypted-communication"
    ["insecure-network-config"]="network/insecure-network-config"
)

SUCCESS=0
FAILED=0

for NAME in "${!VULNERABILITIES[@]}"; do
    PATH_REL="${VULNERABILITIES[$NAME]}"
    FULL_PATH="$PROJECT_DIR/vulnerabilities/$PATH_REL"

    echo "--- Construint: $NAME ---"

    if [ ! -d "$FULL_PATH" ]; then
        echo "AVIS: Carpeta no trobada: $FULL_PATH"
        ((FAILED++))
        continue
    fi

    # Construir imatge vulnerable
    if [ -f "$FULL_PATH/Dockerfile.vulnerable" ]; then
        docker build -f "$FULL_PATH/Dockerfile.vulnerable" \
                     -t "seclab-vuln:$NAME" \
                     "$FULL_PATH" && \
            echo "  Vulnerable: OK" || \
            echo "  Vulnerable: ERROR"
    fi

    # Construir imatge corregida
    if [ -f "$FULL_PATH/Dockerfile.fixed" ]; then
        docker build -f "$FULL_PATH/Dockerfile.fixed" \
                     -t "seclab-fixed:$NAME" \
                     "$FULL_PATH" && \
            echo "  Fixed: OK" || \
            echo "  Fixed: ERROR"
    fi

    ((SUCCESS++))
    echo ""
done

echo "=== Build finalitzat ==="
echo "Correctes: $SUCCESS | Fallades: $FAILED"
echo ""
echo "Imatges creades:"
docker images | grep seclab
