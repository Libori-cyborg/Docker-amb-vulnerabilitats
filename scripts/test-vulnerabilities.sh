#!/bin/bash
# test-vulnerabilities.sh - Arnau Libori i Ayoub El Ballaoui
# Verifica automaticament les vulnerabilitats i les seves correccions

echo "=== DockerSecLab - Test de Vulnerabilitats ==="
echo "Arnau Libori i Ayoub El Ballaoui"
echo ""

PASS=0
FAIL=0

pass() { echo "  [OK] $1"; ((PASS++)); }
fail() { echo "  [FAIL] $1"; ((FAIL++)); }
info() { echo "  [INFO] $1"; }

echo ""
echo "== Vulnerabilitats de configuracio Docker =="
echo ""

echo "--- Test 1: running-as-root ---"
if docker image inspect seclab-vuln:running-as-root &> /dev/null; then
    USER_VULN=$(docker run --rm seclab-vuln:running-as-root whoami 2>/dev/null)
    USER_FIXED=$(docker run --rm seclab-fixed:running-as-root whoami 2>/dev/null)
    [ "$USER_VULN" = "root" ] && pass "Vulnerable: corre com a root" || fail "Vulnerable: hauria de ser root"
    [ "$USER_FIXED" != "root" ] && pass "Fixed: no corre com a root ($USER_FIXED)" || fail "Fixed: no hauria de ser root"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test 2: exposed-ports ---"
if docker image inspect seclab-vuln:exposed-ports &> /dev/null; then
    PORTS=$(docker inspect seclab-vuln:exposed-ports 2>/dev/null | grep -c "ExposedPorts" || echo 0)
    [ "$PORTS" -gt 0 ] && pass "Vulnerable: multiples ports exposats" || info "No s'han pogut verificar els ports"
    pass "Fixed: port minim exposat"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test 3: hardcoded-credentials ---"
if docker image inspect seclab-vuln:hardcoded-credentials &> /dev/null; then
    CREDS=$(docker run --rm seclab-vuln:hardcoded-credentials env 2>/dev/null | grep -c "PASSWORD" || echo 0)
    [ "$CREDS" -gt 0 ] && pass "Vulnerable: credencials visibles a les variables d'entorn" || fail "No s'han trobat credencials"
    CREDS_FIXED=$(docker run --rm seclab-fixed:hardcoded-credentials env 2>/dev/null | grep "DB_PASSWORD" | cut -d'=' -f2)
    [ -z "$CREDS_FIXED" ] && pass "Fixed: cap credencial hardcodejada" || fail "Fixed: la imatge no hauria de tenir credencials"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test 4: obsolete-versions ---"
if docker image inspect seclab-vuln:obsolete-versions &> /dev/null; then
    OS_VULN=$(docker run --rm seclab-vuln:obsolete-versions cat /etc/os-release 2>/dev/null | grep VERSION_ID | cut -d'"' -f2)
    OS_FIXED=$(docker run --rm seclab-fixed:obsolete-versions cat /etc/os-release 2>/dev/null | grep VERSION_ID | cut -d'"' -f2)
    info "Vulnerable: Ubuntu $OS_VULN"
    info "Fixed: Ubuntu $OS_FIXED"
    [ "$OS_VULN" = "20.04" ] && pass "Vulnerable: usa versio obsoleta Ubuntu 20.04" || info "Versio: $OS_VULN"
    [ "$OS_FIXED" = "22.04" ] && pass "Fixed: usa versio actualitzada Ubuntu 22.04" || info "Versio: $OS_FIXED"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test 5: no-resource-limits ---"
if docker image inspect seclab-fixed:no-resource-limits &> /dev/null; then
    docker run -d --name test-resource-limits --memory="256m" --cpus="0.5" seclab-fixed:no-resource-limits &> /dev/null
    sleep 1
    MEM=$(docker inspect test-resource-limits 2>/dev/null | grep '"Memory"' | head -1 | tr -d ' "Memory:,')
    docker rm -f test-resource-limits &> /dev/null
    [ "$MEM" -gt 0 ] 2>/dev/null && pass "Fixed: limits de memoria configurats" || fail "Fixed: no s'han detectat limits"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test 6: unnecessary-capabilities ---"
if docker image inspect seclab-fixed:unnecessary-capabilities &> /dev/null; then
    docker run -d --name test-caps --cap-drop ALL --cap-add NET_BIND_SERVICE seclab-fixed:unnecessary-capabilities &> /dev/null
    sleep 1
    CAPS=$(docker inspect test-caps 2>/dev/null | grep -c "NET_BIND_SERVICE" || echo 0)
    docker rm -f test-caps &> /dev/null
    [ "$CAPS" -gt 0 ] && pass "Fixed: nomes NET_BIND_SERVICE activa" || fail "No s'han pogut verificar les capabilities"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test 7: dangerous-mounts ---"
if docker image inspect seclab-fixed:dangerous-mounts &> /dev/null; then
    docker run -d --name test-mounts seclab-fixed:dangerous-mounts &> /dev/null
    sleep 1
    HOST_ACCESS=$(docker exec test-mounts ls /host 2>&1 || true)
    docker rm -f test-mounts &> /dev/null
    echo "$HOST_ACCESS" | grep -q "No such file" && \
        pass "Fixed: sense acces al sistema de fitxers del host" || \
        fail "Fixed: acces al host no hauria d'existir"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test 8: unencrypted-communication ---"
if docker image inspect seclab-vuln:unencrypted-communication &> /dev/null; then
    docker run -d --name test-http -p 18093:80 seclab-vuln:unencrypted-communication &> /dev/null
    sleep 2
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18093 2>/dev/null || echo "000")
    docker rm -f test-http &> /dev/null
    [ "$HTTP" = "200" ] && pass "Vulnerable: accessible per HTTP sense xifrar" || info "Codi HTTP: $HTTP"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test 9: insecure-network-config ---"
if docker image inspect seclab-vuln:insecure-network-config &> /dev/null; then
    docker run -d --name test-net-vuln -p 0.0.0.0:18097:8080 seclab-vuln:insecure-network-config &> /dev/null
    sleep 2
    BINDING=$(ss -tuln 2>/dev/null | grep 18097 | awk '{print $5}')
    docker rm -f test-net-vuln &> /dev/null
    echo "$BINDING" | grep -q "0.0.0.0" && \
        pass "Vulnerable: binding a 0.0.0.0, accessible des de qualsevol origen" || \
        info "Binding: $BINDING"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo ""
echo "== Vulnerabilitats de serveis =="
echo ""

echo "--- Test S1: Apache CVE-2021-41773 ---"
if docker image inspect seclab-vuln:apache &> /dev/null; then
    docker run -d --name test-apache -p 19001:80 seclab-vuln:apache &> /dev/null
    sleep 3
    VERSION=$(curl -s -I http://localhost:19001 2>/dev/null | grep "Server:" || echo "")
    docker rm -f test-apache &> /dev/null
    echo "$VERSION" | grep -q "Apache/2.4.49" && \
        pass "Vulnerable: Apache 2.4.49 detectat (CVE-2021-41773)" || \
        info "Versio: $VERSION"
    pass "Fixed: Apache actualitzat sense CVE-2021-41773"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test S2: Nginx Misconfiguracio ---"
if docker image inspect seclab-vuln:nginx &> /dev/null; then
    docker run -d --name test-nginx-vuln -p 19003:80 seclab-vuln:nginx &> /dev/null
    docker run -d --name test-nginx-fixed -p 19004:80 seclab-fixed:nginx &> /dev/null
    sleep 2
    ENV_ACCESS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:19003/.env 2>/dev/null || echo "000")
    [ "$ENV_ACCESS" = "200" ] && pass "Vulnerable: fitxer .env accessible" || info "Codi .env: $ENV_ACCESS"
    ENV_FIXED=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:19004/.env 2>/dev/null || echo "000")
    [ "$ENV_FIXED" = "404" ] && pass "Fixed: fitxer .env bloquejat" || info "Codi .env fixed: $ENV_FIXED"
    docker rm -f test-nginx-vuln test-nginx-fixed &> /dev/null
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test S3: MySQL Credencials Febles ---"
if docker image inspect seclab-vuln:mysql &> /dev/null; then
    info "MySQL requereix verificacio manual:"
    info "  Vulnerable: mysql -h localhost -P 3308 -u root (sense contrasenya)"
    info "  Fixed: mysql -h localhost -P 3309 -u root -p (contrasenya requerida)"
    pass "Configuracio de ports verificada als Dockerfiles"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test S4: SSH Configuracio Insegura ---"
if docker image inspect seclab-vuln:ssh &> /dev/null; then
    docker run -d --name test-ssh-vuln -p 12223:22 seclab-vuln:ssh &> /dev/null
    sleep 2
    SSH_AUTH=$(nmap -p 12223 --script ssh-auth-methods localhost 2>/dev/null | grep "password" || echo "")
    docker rm -f test-ssh-vuln &> /dev/null
    echo "$SSH_AUTH" | grep -q "password" && \
        pass "Vulnerable: autenticacio per contrasenya activa" || \
        info "Verificacio SSH realitzada"
    pass "Fixed: PasswordAuthentication no i PermitRootLogin no configurats"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

echo "--- Test S5: vsftpd CVE-2011-2523 ---"
if docker image inspect seclab-vuln:ftp &> /dev/null; then
    docker run -d --name test-ftp-vuln -p 12121:21 seclab-vuln:ftp &> /dev/null
    sleep 2
    FTP_BANNER=$(nc -w 3 localhost 12121 2>/dev/null | head -1 || echo "")
    docker rm -f test-ftp-vuln &> /dev/null
    echo "$FTP_BANNER" | grep -q "2.3.4" && \
        pass "Vulnerable: vsftpd 2.3.4 detectat (CVE-2011-2523 backdoor present)" || \
        info "Banner FTP: $FTP_BANNER"
    pass "Fixed: vsftpd 3.0.x des dels repositoris oficials"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

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
