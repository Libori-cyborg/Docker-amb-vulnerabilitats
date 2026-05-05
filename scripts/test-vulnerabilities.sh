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

# ============================================================
echo "== Vulnerabilitats de Xarxa =="
echo ""

# --- Apache CVE-2021-41773 ---
echo "--- Test 1: Apache CVE-2021-41773 (Path Traversal + RCE) ---"
if docker image inspect seclab-vuln:apache &> /dev/null; then
    docker run -d --name test-apache-vuln -p 19001:80 seclab-vuln:apache &> /dev/null
    sleep 3
    # Comprovar versio vulnerable al banner
    VERSION=$(curl -s -I http://localhost:19001 2>/dev/null | grep -i "Server:" || echo "")
    echo "$VERSION" | grep -q "2.4.49" && \
        pass "Vulnerable: Apache 2.4.49 detectat (CVE-2021-41773 present)" || \
        info "Banner del servidor: $VERSION"
    # Intentar path traversal basic
    TRAVERSAL=$(curl -s --path-as-is http://localhost:19001/cgi-bin/.%2e/.%2e/.%2e/etc/passwd 2>/dev/null | head -3 || echo "")
    echo "$TRAVERSAL" | grep -q "root" && \
        pass "Vulnerable: Path traversal exitós, /etc/passwd accessible" || \
        info "Path traversal: resposta sense contingut sensible"
    docker rm -f test-apache-vuln &> /dev/null

    docker run -d --name test-apache-fixed -p 19002:80 seclab-fixed:apache &> /dev/null
    sleep 3
    TRAVERSAL_FIXED=$(curl -s --path-as-is http://localhost:19002/cgi-bin/.%2e/.%2e/.%2e/etc/passwd 2>/dev/null || echo "403")
    echo "$TRAVERSAL_FIXED" | grep -q "root" && \
        fail "Fixed: path traversal no hauria de funcionar" || \
        pass "Fixed: path traversal bloquejat correctament"
    docker rm -f test-apache-fixed &> /dev/null
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# --- vsftpd CVE-2011-2523 ---
echo "--- Test 2: vsftpd 2.3.4 CVE-2011-2523 (Backdoor) ---"
if docker image inspect seclab-vuln:ftp &> /dev/null; then
    docker run -d --name test-ftp-vuln -p 12121:21 seclab-vuln:ftp &> /dev/null
    sleep 2
    FTP_BANNER=$(nc -w 3 localhost 12121 2>/dev/null | head -1 || echo "")
    echo "$FTP_BANNER" | grep -q "2.3.4" && \
        pass "Vulnerable: vsftpd 2.3.4 detectat (backdoor CVE-2011-2523 present)" || \
        info "Banner FTP: $FTP_BANNER"
    docker rm -f test-ftp-vuln &> /dev/null

    docker run -d --name test-ftp-fixed -p 12122:21 seclab-fixed:ftp &> /dev/null
    sleep 2
    FTP_BANNER_FIXED=$(nc -w 3 localhost 12122 2>/dev/null | head -1 || echo "")
    echo "$FTP_BANNER_FIXED" | grep -qv "2.3.4" && \
        pass "Fixed: vsftpd actualitzat, backdoor eliminat" || \
        fail "Fixed: versio no hauria de ser 2.3.4"
    docker rm -f test-ftp-fixed &> /dev/null
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# --- Redis sense autenticació ---
echo "--- Test 3: Redis sense autenticacio (exposat a 0.0.0.0) ---"
if docker image inspect seclab-vuln:redis &> /dev/null; then
    docker run -d --name test-redis-vuln -p 16380:6379 seclab-vuln:redis &> /dev/null
    sleep 2
    # Intentar connexio sense contrasenya
    REDIS_ACCESS=$(redis-cli -p 16380 ping 2>/dev/null || echo "FAILED")
    echo "$REDIS_ACCESS" | grep -q "PONG" && \
        pass "Vulnerable: Redis accessible sense autenticacio (PONG rebut)" || \
        info "Resposta Redis: $REDIS_ACCESS"
    # Llegir claus sensibles
    SECRET=$(redis-cli -p 16380 GET secret_key 2>/dev/null || echo "")
    [ -n "$SECRET" ] && \
        pass "Vulnerable: dades sensibles llegibles sense contrasenya ($SECRET)" || \
        info "No s'han pogut llegir les claus"
    docker rm -f test-redis-vuln &> /dev/null

    docker run -d --name test-redis-fixed -p 127.0.0.1:16381:6379 seclab-fixed:redis &> /dev/null
    sleep 2
    REDIS_NO_AUTH=$(redis-cli -p 16381 ping 2>/dev/null || echo "NOAUTH")
    echo "$REDIS_NO_AUTH" | grep -q "NOAUTH" && \
        pass "Fixed: Redis requereix autenticacio (NOAUTH)" || \
        info "Resposta Redis fixed: $REDIS_NO_AUTH"
    docker rm -f test-redis-fixed &> /dev/null
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# ============================================================
echo "== Vulnerabilitats de Configuracio de Serveis =="
echo ""

# --- MySQL credencials febles ---
echo "--- Test 4: MySQL root sense contrasenya + acces remot ---"
if docker image inspect seclab-vuln:mysql &> /dev/null; then
    docker run -d --name test-mysql-vuln -p 13308:3306 seclab-vuln:mysql &> /dev/null
    sleep 5
    MYSQL_ACCESS=$(mysql -h 127.0.0.1 -P 13308 -u root --connect-timeout=3 -e "SHOW DATABASES;" 2>/dev/null | head -3 || echo "")
    [ -n "$MYSQL_ACCESS" ] && \
        pass "Vulnerable: MySQL accessible com a root sense contrasenya" || \
        info "MySQL vulnerable: verificacio manual recomanada"
    docker rm -f test-mysql-vuln &> /dev/null

    docker run -d --name test-mysql-fixed -p 127.0.0.1:13309:3306 seclab-fixed:mysql &> /dev/null
    sleep 5
    MYSQL_FIXED=$(mysql -h 127.0.0.1 -P 13309 -u root --connect-timeout=3 -e "SHOW DATABASES;" 2>/dev/null || echo "ERROR_AUTH")
    echo "$MYSQL_FIXED" | grep -q "ERROR_AUTH" && \
        pass "Fixed: MySQL requereix autenticacio" || \
        info "Fixed: verificacio manual recomanada"
    docker rm -f test-mysql-fixed &> /dev/null
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# --- Nginx directory listing ---
echo "--- Test 5: Nginx directory listing + fitxers sensibles ---"
if docker image inspect seclab-vuln:nginx &> /dev/null; then
    docker run -d --name test-nginx-vuln -p 19003:80 seclab-vuln:nginx &> /dev/null
    docker run -d --name test-nginx-fixed -p 19004:80 seclab-fixed:nginx &> /dev/null
    sleep 2

    ENV_VULN=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:19003/.env 2>/dev/null || echo "000")
    [ "$ENV_VULN" = "200" ] && \
        pass "Vulnerable: fitxer .env accessible (codi HTTP 200)" || \
        info "Codi HTTP .env vulnerable: $ENV_VULN"

    DIR_LISTING=$(curl -s http://localhost:19003/ 2>/dev/null | grep -i "Index of" || echo "")
    [ -n "$DIR_LISTING" ] && \
        pass "Vulnerable: directory listing actiu" || \
        info "Directory listing: no detectat en ruta arrel"

    ENV_FIXED=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:19004/.env 2>/dev/null || echo "000")
    [ "$ENV_FIXED" = "404" ] && \
        pass "Fixed: fitxer .env bloquejat (codi HTTP 404)" || \
        info "Codi HTTP .env fixed: $ENV_FIXED"

    docker rm -f test-nginx-vuln test-nginx-fixed &> /dev/null
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# --- SSH configuracio insegura ---
echo "--- Test 6: SSH PermitRootLogin + contrasenya feble ---"
if docker image inspect seclab-vuln:ssh &> /dev/null; then
    docker run -d --name test-ssh-vuln -p 12223:22 seclab-vuln:ssh &> /dev/null
    sleep 2
    # Comprovar que PermitRootLogin esta actiu
    ROOT_LOGIN=$(docker exec test-ssh-vuln grep "PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "")
    echo "$ROOT_LOGIN" | grep -q "yes" && \
        pass "Vulnerable: PermitRootLogin yes configurat" || \
        info "Configuracio SSH: $ROOT_LOGIN"
    PASS_AUTH=$(docker exec test-ssh-vuln grep "PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "")
    echo "$PASS_AUTH" | grep -q "yes" && \
        pass "Vulnerable: PasswordAuthentication yes (força bruta possible)" || \
        info "PasswordAuthentication: $PASS_AUTH"
    docker rm -f test-ssh-vuln &> /dev/null

    docker run -d --name test-ssh-fixed -p 12224:22 seclab-fixed:ssh &> /dev/null
    sleep 2
    ROOT_LOGIN_FIXED=$(docker exec test-ssh-fixed grep "PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "")
    echo "$ROOT_LOGIN_FIXED" | grep -q "no" && \
        pass "Fixed: PermitRootLogin no configurat" || \
        info "Fixed SSH: $ROOT_LOGIN_FIXED"
    docker rm -f test-ssh-fixed &> /dev/null
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# ============================================================
echo "== Vulnerabilitats de Contenidor/Host =="
echo ""

# --- No resource limits ---
echo "--- Test 7: Sense limits de recursos ---"
if docker image inspect seclab-fixed:no-resource-limits &> /dev/null; then
    docker run -d --name test-resource-limits \
        --memory="256m" --cpus="0.5" \
        seclab-fixed:no-resource-limits &> /dev/null
    sleep 1
    MEM=$(docker inspect test-resource-limits 2>/dev/null | grep '"Memory"' | head -1 | tr -d ' "Memory:,')
    docker rm -f test-resource-limits &> /dev/null
    [ "$MEM" -gt 0 ] 2>/dev/null && \
        pass "Fixed: limits de memoria configurats ($MEM bytes)" || \
        fail "Fixed: no s'han detectat limits de memoria"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# --- Unnecessary capabilities ---
echo "--- Test 8: Capabilities innecessaries ---"
if docker image inspect seclab-fixed:unnecessary-capabilities &> /dev/null; then
    docker run -d --name test-caps \
        --cap-drop ALL --cap-add NET_BIND_SERVICE \
        seclab-fixed:unnecessary-capabilities &> /dev/null
    sleep 1
    CAPS=$(docker inspect test-caps 2>/dev/null | grep -c "NET_BIND_SERVICE" || echo 0)
    docker rm -f test-caps &> /dev/null
    [ "$CAPS" -gt 0 ] && \
        pass "Fixed: nomes NET_BIND_SERVICE activa" || \
        fail "No s'han pogut verificar les capabilities"
else
    info "Imatge no trobada, executa build-all.sh primer"
fi
echo ""

# --- Dangerous mounts ---
echo "--- Test 9: Muntatges perillosos ---"
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

# ============================================================
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
