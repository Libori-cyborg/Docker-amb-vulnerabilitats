# DockerSecLab - Catàleg de Vulnerabilitats en Contenidors Docker

**Autors:** Arnau Libori i Ayoub El Ballaoui

---

## Descripció del Projecte

DockerSecLab és un catàleg educatiu pràctic de vulnerabilitats en contenidors Docker. El projecte consisteix en la creació, reproducció i correcció de problemes de seguretat habituals en entorns containeritzats.

Per a cada vulnerabilitat seleccionada, es desenvolupa:
- Un contenidor Docker **vulnerable**
- Un contenidor Docker amb la vulnerabilitat **corregida**
- Documentació tècnica detallada explicant la vulnerabilitat, riscos, explotació i solució

---

## Objectius Generals

1. Facilitar l'aprenentatge pràctic de la seguretat en contenidors Docker
2. Entendre com es generen vulnerabilitats reals en entorns containeritzats
3. Aplicar bones pràctiques de seguretat en Docker
4. Desenvolupar capacitats en ciberseguretat i administració de sistemes
5. Experimentar directament amb configuracions vulnerables en un entorn controlat

---

## Estructura del Projecte

```
DockerSecLab/
├── vulnerabilities/
│   ├── network/
│   │   ├── exposed-ports/
│   │   │   ├── Dockerfile.vulnerable
│   │   │   ├── Dockerfile.fixed
│   │   │   └── docker-compose.yml
│   │   ├── unencrypted-communication/
│   │   └── insecure-network-config/
│   ├── configuration/
│   │   ├── running-as-root/
│   │   ├── hardcoded-credentials/
│   │   └── obsolete-versions/
│   └── container-host/
│       ├── unnecessary-capabilities/
│       ├── dangerous-mounts/
│       └── no-resource-limits/
├── documentation/
│   ├── README.md
│   ├── VULNERABILITIES.md
│   └── vulnerabilities/
│       ├── 1-running-as-root.md
│       ├── 2-exposed-ports.md
│       ├── 3-hardcoded-credentials.md
│       └── ...
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
- Docker Compose: v1.29+
- Git: v2.25+
- Bash: v4.0+

---

## Instal·lació i Configuració

### 1. Actualitzar el sistema
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Instal·lar Docker
```bash
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

docker --version
```

### 3. Instal·lar Docker Compose
```bash
sudo apt install -y docker-compose
docker-compose --version
```

### 4. Configurar permisos
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### 5. Clonar el projecte
```bash
git clone https://github.com/Libori-cyborg/Docker-amb-vulnerabilitats.git DockerSecLab
cd DockerSecLab
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

### Aturar contenidors
```bash
docker-compose down
```

### Netejar completament
```bash
docker-compose down -v
docker system prune -a
```

---

## Vulnerabilitats Incloses

La documentació detallada de cada vulnerabilitat es troba a la carpeta `documentation/vulnerabilities/`. El resum complet de totes les vulnerabilitats està disponible a `VULNERABILITIES.md`.

### Vulnerabilitats de Xarxa

| Num | Vulnerabilitat | Descripció |
|---|---|---|
| 2 | exposed-ports | Exposició innecessària de ports |
| - | unencrypted-communication | Protocols sense xifratge (HTTP, Telnet, FTP) |
| - | insecure-network-config | Binding a 0.0.0.0, sense firewall |

### Vulnerabilitats de Configuració de Serveis

| Num | Vulnerabilitat | Descripció |
|---|---|---|
| 1 | running-as-root | Contenidors corrent amb privilegis màxims |
| 3 | hardcoded-credentials | Secrets emmagatzemats al Dockerfile o variables d'entorn |
| 4 | obsolete-versions | Serveis amb vulnerabilitats conegudes (CVEs) |

### Vulnerabilitats de Configuració del Contenidor/Host

| Num | Vulnerabilitat | Descripció |
|---|---|---|
| - | unnecessary-capabilities | Permisos de sistema excessius |
| - | dangerous-mounts | Accés sense restriccions a directoris del host |
| - | no-resource-limits | CPU, memòria i I/O il·limitades |

---

## Com Usar el Catàleg

Per a cada vulnerabilitat trobaràs:

### Dockerfile.vulnerable
Implementació amb la vulnerabilitat activa per estudiar-la.
```bash
docker build -f vulnerabilities/network/exposed-ports/Dockerfile.vulnerable \
  -t seclab-vulnerable:exposed-ports .
```

### Dockerfile.fixed
Versió corregida seguint bones pràctiques de seguretat.
```bash
docker build -f vulnerabilities/network/exposed-ports/Dockerfile.fixed \
  -t seclab-fixed:exposed-ports .
```

### docker-compose.yml
Per executar la versió vulnerable i la corregida simultàniament.
```bash
docker-compose -f vulnerabilities/network/exposed-ports/docker-compose.yml up
```

### Documentació Tècnica
Cada vulnerabilitat té un fitxer `.md` a `documentation/vulnerabilities/` amb:
- Descripció de la vulnerabilitat
- Riscos i conseqüències
- Com s'explota
- Com s'ha solucionat
- Bones pràctiques

---

## Eines d'Anàlisi Utilitzades

### Inspeccions bàsiques
```bash
docker inspect <image-id>
docker port <container-name>
docker top <container-name>
docker logs <container-name>
```

### Anàlisi de xarxa
```bash
netstat -tuln
ss -tuln
```

### Anàlisi de seguretat
```bash
# Instal·lar Trivy
wget https://github.com/aquasecurity/trivy/releases/download/v0.30.0/trivy_0.30.0_Linux-64bit.deb
sudo dpkg -i trivy_0.30.0_Linux-64bit.deb

# Escanejar imatge
trivy image <image-name>
```

---

## Consideracions Legals i Etica

Aquest projecte és estrictament educatiu i per a ús en entorns controlats i autoritzats.

- Usar aquest catàleg NOMÉS en màquines virtuals personals o de laboratori
- No atacar sistemes sense autorització explícita
- Complir amb les lleis de ciberseguretat locals
- Usar la informació de forma responsable

---

## Recursos Addicionals

- [Docker Security](https://docs.docker.com/engine/security/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [CIS Docker Benchmark](https://www.cisecurity.org/)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Trivy - Vulnerability Scanner](https://github.com/aquasecurity/trivy)
- [Hadolint - Dockerfile Linter](https://github.com/hadolint/hadolint)

---

**Ultima actualitzacio:** Marc 2026
**Versio:** 1.0.0
