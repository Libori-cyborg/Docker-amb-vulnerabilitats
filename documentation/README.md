# DockerSecLab - Catàleg de Vulnerabilitats en Contenidors Docker

**Autors:** Arnau Libori i Ayoub El Ballaoui

---

## Descripció del Projecte

DockerSecLab és un catàleg educatiu pràctic de vulnerabilitats reals en serveis desplegats amb Docker. El projecte consisteix en la reproducció i correcció de vulnerabilitats conegudes en serveis com Apache, vsftpd, Redis, MySQL, Nginx i SSH, a més de males pràctiques de configuració pròpies dels contenidors Docker.

Per a cada vulnerabilitat es proporciona:
- Un contenidor Docker amb el **servei vulnerable** (versió insegura o mal configurada)
- Un contenidor Docker amb el **servei corregit** (versió actualitzada o configuració segura)
- Documentació tècnica detallada explicant la vulnerabilitat, riscos, explotació i solució

---

## Objectius Generals

1. Reproduir vulnerabilitats reals de serveis en un entorn controlat i segur
2. Entendre com s'exploten CVEs coneguts i males configuracions habituals
3. Aplicar bones pràctiques de seguretat en serveis i contenidors Docker
4. Desenvolupar capacitats en ciberseguretat i administració de sistemes
5. Experimentar directament amb atacs i defenses en un laboratori aïllat

---

## Estructura del Projecte

```
DockerSecLab/
├── vulnerabilities/
│   ├── network/
│   │   ├── apache/
│   │   │   ├── Dockerfile.vulnerable
│   │   │   ├── Dockerfile.fixed
│   │   │   └── docker-compose.yml
│   │   ├── ftp/
│   │   │   ├── Dockerfile.vulnerable
│   │   │   ├── Dockerfile.fixed
│   │   │   └── docker-compose.yml
│   │   └── redis/
│   │       ├── Dockerfile.vulnerable
│   │       ├── Dockerfile.fixed
│   │       └── docker-compose.yml
│   ├── configuration/
│   │   ├── mysql/
│   │   │   ├── Dockerfile.vulnerable
│   │   │   ├── Dockerfile.fixed
│   │   │   └── docker-compose.yml
│   │   ├── nginx/
│   │   │   ├── Dockerfile.vulnerable
│   │   │   ├── Dockerfile.fixed
│   │   │   └── docker-compose.yml
│   │   └── ssh/
│   │       ├── Dockerfile.vulnerable
│   │       ├── Dockerfile.fixed
│   │       └── docker-compose.yml
│   └── container-host/
│       ├── dangerous-mounts/
│       ├── no-resource-limits/
│       └── unnecessary-capabilities/
├── documentation/
│   ├── README.md
│   ├── VULNERABILITIES.md
│   └── vulnerabilities/
│       ├── 1-apache-cve-2021-41773.md
│       ├── 2-ftp-vsftpd-backdoor.md
│       ├── 3-redis-sense-autenticacio.md
│       ├── 4-mysql-credencials-febles.md
│       ├── 5-nginx-misconfiguracio.md
│       ├── 6-ssh-configuracio-insegura.md
│       ├── 7-dangerous-mounts.md
│       ├── 8-no-resource-limits.md
│       └── 9-unnecessary-capabilities.md
├── compose-files/
│   └── docker-compose.yml
├── scripts/
│   ├── setup.sh
│   ├── build-all.sh
│   └── test-vulnerabilities.sh
├── .gitignore
└── LICENSE
```

---

## Requisits del Sistema

### Hardware
- RAM: Mínim 4 GB (recomanat 8 GB)
- Emmagatzematge: 20-30 GB lliures
- CPU: Mínim 2 nuclis

### Software
- Distribució Linux: Ubuntu 20.04 LTS o superior
- Docker: v20.10+
- Docker Compose: v2.0+
- Git: v2.25+
- Bash: v4.0+

---

## Instal·lació i Configuració

### 1. Clonar el projecte
```bash
git clone https://github.com/Libori-cyborg/Docker-amb-vulnerabilitats.git DockerSecLab
cd DockerSecLab
```

### 2. Executar el setup automàtic
```bash
sudo bash scripts/setup.sh
```

### 3. Construir totes les imatges
```bash
bash scripts/build-all.sh
```

---

## Inici Ràpid

### Executar tots els contenidors
```bash
cd compose-files
docker-compose up -d
```

### Verificar contenidors en execució
```bash
docker ps
```

### Executar tests de verificació
```bash
bash scripts/test-vulnerabilities.sh
```

### Aturar i netejar
```bash
docker-compose down
docker system prune -a
```

---

## Vulnerabilitats Incloses

### Vulnerabilitats de Xarxa

| Num | Servei | Vulnerabilitat | CVE / CWE | Ports |
|---|---|---|---|---|
| 1 | Apache 2.4.49 | Path Traversal + RCE | CVE-2021-41773 | 9001 / 9002 |
| 2 | vsftpd 2.3.4 | Backdoor porta 6200 | CVE-2011-2523 | 2121 / 2122 |
| 3 | Redis | Sense autenticació, exposat a 0.0.0.0 | CWE-287 | 6380 / 6381 |

### Vulnerabilitats de Configuració de Serveis

| Num | Servei | Vulnerabilitat | CVE / CWE | Ports |
|---|---|---|---|---|
| 4 | MySQL | Root sense contrasenya + accés remot obert | CWE-521 | 3308 / 3309 |
| 5 | Nginx | Directory listing + fitxers sensibles exposats | CWE-548 | 9003 / 9004 |
| 6 | OpenSSH | PermitRootLogin + contrasenya feble | CWE-521 | 2223 / 2224 |

### Vulnerabilitats de Configuració del Contenidor/Host

| Num | Vulnerabilitat | CVE / CWE | Ports |
|---|---|---|---|
| 7 | Muntatges perillosos (/, docker.sock) | CWE-284 | 8093 / 8094 |
| 8 | Sense límits de recursos (DoS) | CWE-400 | 8089 / 8090 |
| 9 | Capabilities innecessàries | CWE-250 | 8091 / 8092 |

---

## Com Usar el Catàleg

### Executar una vulnerabilitat individual
```bash
# Exemple: Apache CVE-2021-41773
docker-compose -f vulnerabilities/network/apache/docker-compose.yml up -d

# Comprovar que funciona
curl http://localhost:9001

# Provar el path traversal (contenidor vulnerable)
curl --path-as-is http://localhost:9001/cgi-bin/.%2e/.%2e/.%2e/etc/passwd

# Aturar
docker-compose -f vulnerabilities/network/apache/docker-compose.yml down
```

### Construir una imatge individualment
```bash
docker build -f vulnerabilities/network/apache/Dockerfile.vulnerable \
  -t seclab-vuln:apache vulnerabilities/network/apache/

docker build -f vulnerabilities/network/apache/Dockerfile.fixed \
  -t seclab-fixed:apache vulnerabilities/network/apache/
```

---

## Eines d'Anàlisi Utilitzades

### Inspeccions bàsiques
```bash
docker inspect <container-name>
docker port <container-name>
docker logs <container-name>
```

### Anàlisi de xarxa
```bash
nmap -sV -p <port> localhost
ss -tuln
nc -w 3 localhost <port>
```

### Anàlisi de vulnerabilitats
```bash
# Escaneig amb Trivy
trivy image seclab-vuln:apache
trivy image seclab-fixed:apache

# Captura de tràfic
tcpdump -i any port <port>

# Prova d'autenticació
redis-cli -p 6380 ping
mysql -h 127.0.0.1 -P 3308 -u root
```

---

## Consideracions Legals i Ètiques

Aquest projecte és estrictament educatiu i per a ús en entorns controlats i autoritzats.

- Usar aquest catàleg NOMÉS en màquines virtuals personals o de laboratori
- No atacar sistemes sense autorització explícita
- Complir amb les lleis de ciberseguretat locals
- Usar la informació de forma responsable

---

## Recursos Addicionals

- [Docker Security](https://docs.docker.com/engine/security/)
- [NVD - National Vulnerability Database](https://nvd.nist.gov/)
- [CVE-2021-41773 Detail](https://nvd.nist.gov/vuln/detail/CVE-2021-41773)
- [CVE-2011-2523 Detail](https://nvd.nist.gov/vuln/detail/CVE-2011-2523)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Trivy - Vulnerability Scanner](https://github.com/aquasecurity/trivy)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

---

**Ultima actualitzacio:** Abril 2026
**Versio:** 2.0.0
