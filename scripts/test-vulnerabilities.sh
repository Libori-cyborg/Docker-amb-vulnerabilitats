#!/bin/bash
# test-vulnerabilities.sh - Arnau Libori i Ayoub El Ballaoui
# Verifica automaticament les vulnerabilitats i les seves correccions

set -e

echo "=== DockerSecLab - Test de Vulnerabilitats ==="
echo "Arnau Libori i Ayoub El Ballaoui"
echo ""

PASS=0
FAIL=0

# Funcions auxiliars
pass() {
    echo "  [OK] $1"
    ((PASS++))
}

fail() {
    echo "  [FAIL] $1"
    ((FAIL++))
}

info() {
    echo "  [INFO] $1"
}

# Test 1 - running-as-root
echo "--- Test 1: running-as-root ---"
if docker image inspect seclab-vuln:running-as-root &> /dev/null; then
    USER_VULN=$(docker run --rm seclab-vuln:running-as-root whoami)
    if [ "$USER_VULN" = "root" ]; then
        pass "Vulnerable: corre com a root"
    else
        fail "Vulnerable: hauria de correr com a root"
    fi

    USER_FIXED=$(docker run --rm seclab-fixed:running-as-root whoami)
    if [ "$USER_FIXED" != "root" ]; then
        pass "Fixed: no corre com a root ($USER_FIXED)"
    else
        fail "Fixed: no hauria de correr com a root"
    fi
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# Test 2 - exposed-ports
echo "--- Test 2: exposed-ports ---"
if docker image inspect seclab-vuln:exposed-ports &> /dev/null; then
    PORTS_VULN=$(docker inspect seclab-vuln:exposed-ports | \
                 grep -c "ExposedPorts" || true)
    PORTS_FIXED=$(docker run --rm seclab-fixed:exposed-ports \
                  sh -c "cat /proc/net/tcp | wc -l" 2>/dev/null || echo "0")

    pass "Vulnerable: multiples ports exposats"
    pass "Fixed: port minim exposat"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# Test 3 - hardcoded-credentials
echo "--- Test 3: hardcoded-credentials ---"
if docker image inspect seclab-vuln:hardcoded-credentials &> /dev/null; then
    CREDS=$(docker run --rm seclab-vuln:hardcoded-credentials \
            env | grep -c "PASSWORD" || true)
    if [ "$CREDS" -gt 0 ]; then
        pass "Vulnerable: credencials visibles a les variables d'entorn"
    else
        fail "Vulnerable: no s'han trobat credencials exposades"
    fi

    CREDS_FIXED=$(docker run --rm seclab-fixed:hardcoded-credentials \
                  env | grep "DB_PASSWORD" | cut -d'=' -f2)
    if [ -z "$CREDS_FIXED" ]; then
        pass "Fixed: cap credencial hardcodejada a la imatge"
    else
        fail "Fixed: la imatge no hauria de tenir credencials"
    fi
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# Test 4 - obsolete-versions
echo "--- Test 4: obsolete-versions ---"
if docker image inspect seclab-vuln:obsolete-versions &> /dev/null; then
    OS_VULN=$(docker run --rm seclab-vuln:obsolete-versions \
              cat /etc/os-release | grep VERSION_ID | cut -d'"' -f2)
    OS_FIXED=$(docker run --rm seclab-fixed:obsolete-versions \
               cat /etc/os-release | grep VERSION_ID | cut -d'"' -f2)

    info "Vulnerable: Ubuntu $OS_VULN"
    info "Fixed: Ubuntu $OS_FIXED"

    if [ "$OS_VULN" = "18.04" ]; then
        pass "Vulnerable: usa versio obsoleta Ubuntu 18.04"
    fi
    if [ "$OS_FIXED" = "22.04" ]; then
        pass "Fixed: usa versio actualitzada Ubuntu 22.04"
    fi
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# Test 5 - no-resource-limits
echo "--- Test 5: no-resource-limits ---"
CONTAINER="test-resource-limits"
if docker image inspect seclab-fixed:no-resource-limits &> /dev/null; then
    docker run -d --name "$CONTAINER" \
        --memory="256m" --cpus="0.5" \
        seclab-fixed:no-resource-limits &> /dev/null

    MEM_LIMIT=$(docker inspect "$CONTAINER" | \
                grep '"Memory"' | head -1 | tr -d ' "Memory:,')
    docker rm -f "$CONTAINER" &> /dev/null

    if [ "$MEM_LIMIT" -gt 0 ] 2>/dev/null; then
        pass "Fixed: limits de memoria configurats ($MEM_LIMIT bytes)"
    else
        fail "Fixed: no s'han detectat limits de memoria"
    fi
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# Test 6 - unnecessary-capabilities
echo "--- Test 6: unnecessary-capabilities ---"
if docker image inspect seclab-fixed:unnecessary-capabilities &> /dev/null; then
    docker run -d --name test-caps \
        --cap-drop ALL --cap-add NET_BIND_SERVICE \
        seclab-fixed:unnecessary-capabilities &> /dev/null

    CAPS=$(docker inspect test-caps | grep -c "NET_BIND_SERVICE" || true)
    docker rm -f test-caps &> /dev/null

    if [ "$CAPS" -gt 0 ]; then
        pass "Fixed: nomes NET_BIND_SERVICE activa"
    else
        fail "Fixed: no s'han pogut verificar les capabilities"
    fi
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# Test 7 - dangerous-mounts
echo "--- Test 7: dangerous-mounts ---"
if docker image inspect seclab-fixed:dangerous-mounts &> /dev/null; then
    docker run -d --name test-mounts \
        seclab-fixed:dangerous-mounts &> /dev/null

    HOST_ACCESS=$(docker exec test-mounts ls /host 2>&1 || true)
    docker rm -f test-mounts &> /dev/null

    if echo "$HOST_ACCESS" | grep -q "No such file"; then
        pass "Fixed: sense acces al sistema de fitxers del host"
    else
        fail "Fixed: acces al host no hauria d'existir"
    fi
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# Test 8 - unencrypted-communication
echo "--- Test 8: unencrypted-communication ---"
if docker image inspect seclab-vuln:unencrypted-communication &> /dev/null; then
    docker run -d --name test-http -p 18093:80 \
        seclab-vuln:unencrypted-communication &> /dev/null
    sleep 2

    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
                    http://localhost:18093 || echo "000")
    docker rm -f test-http &> /dev/null

    if [ "$HTTP_RESPONSE" = "200" ]; then
        pass "Vulnerable: accessible per HTTP sense xifrar"
    else
        info "Vulnerable: codi de resposta HTTP $HTTP_RESPONSE"
    fi
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# Test 9 - insecure-network-config
echo "--- Test 9: insecure-network-config ---"
if docker image inspect seclab-vuln:insecure-network-config &> /dev/null; then
    docker run -d --name test-net-vuln \
        -p 0.0.0.0:18097:8080 \
        seclab-vuln:insecure-network-config &> /dev/null
    sleep 2

    BINDING=$(ss -tuln | grep 18097 | awk '{print $5}')
    docker rm -f test-net-vuln &> /dev/null

    if echo "$BINDING" | grep -q "0.0.0.0"; then
        pass "Vulnerable: binding a 0.0.0.0, accessible des de qualsevol origen"
    else
        info "Vulnerable: binding $BINDING"
    fi
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# Resum final
echo "================================="
echo "Resum de tests"
echo "================================="
echo "Passats: $PASS"
echo "Fallats: $FAIL"
echo "Total:   $((PASS + FAIL))"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "Tots els tests han passat correctament."
else
    echo "Hi ha $FAIL tests fallats. Revisa les imatges amb build-all.sh"
fi
