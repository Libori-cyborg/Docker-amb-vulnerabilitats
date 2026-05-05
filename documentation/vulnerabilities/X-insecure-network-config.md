# Vulnerabilitat 9: Configuració de Xarxa Insegura

## Descripció Breu

Una configuració de xarxa insegura en contenidors Docker es produeix quan els serveis escolten a totes les interficies de xarxa (0.0.0.0), no hi ha segmentació entre contenidors, o els ports interns s'exposen directament a Internet sense cap control. Això permet que serveis interns siguin accessibles des de qualsevol origen, ampliant innecessariament la superfície d'atac.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Serveis interns accessibles des de l'exterior exposen dades no destinades a ser publiques
- **Integritat** -> Sense segmentació, un contenidor compromès pot atacar la resta de la xarxa interna
- **Disponibilitat** -> Serveis exposats a Internet son objectiu d'atacs de força bruta i DDoS

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | CWE-16 (Configuration), CWE-284 (Improper Access Control) |
| **Impacte real** | Acces no autoritzat a serveis interns des de qualsevol xarxa |
| **Escenari tipic** | Base de dades accessible des d'Internet per binding a 0.0.0.0 |

### Problemes habituals de configuració de xarxa

| Problema | Descripcio | Risc |
|---|---|---|
| Binding a `0.0.0.0` | El servei escolta a totes les interficies | Accessible des de qualsevol xarxa |
| Sense xarxes internes | Tots els contenidors a la mateixa xarxa | Un contenidor compromès pot atacar tots els altres |
| Xarxa `host` mode | El contenidor comparteix la xarxa del host | Sense aïllament de xarxa |
| Sense firewall intern | Sense regles iptables entre contenidors | Trafic lliure entre tots els contenidors |

---

## Implementació Vulnerable

```dockerfile
# Vulnerable: contenidor amb configuració de xarxa insegura
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y python3 net-tools

WORKDIR /app

# Escolta a totes les interficies de xarxa sense restriccions
CMD ["python3", "-m", "http.server", "8080", "--bind", "0.0.0.0"]
```

```yaml
# docker-compose.yml vulnerable
services:
  vulnerable-network:
    ports:
      - "0.0.0.0:8095:8080"
    networks:
      - insecure-net
```

### Verificació de la vulnerabilitat

```bash
# Construir i executar el contenidor vulnerable
docker-compose up -d vulnerable-network

# Comprovar que escolta a totes les interficies
docker exec vuln-insecure-network-config netstat -tuln

# Comprovar accessibilitat des de qualsevol IP del host
ss -tuln | grep 8095
```

**Resultat esperat:**
```
tcp  0.0.0.0:8095   0.0.0.0:*   LISTEN
# Accessible des de qualsevol interficie del host
```

```bash
# Escaneig extern per verificar que es accessible
nmap -p 8095 <IP-del-host>
# Port obert i accessible des de fora
```

---

## Com Explotar

### Pas 1: Descobrir serveis amb binding a 0.0.0.0
```bash
# Escaneig de ports des d'una maquina externa
nmap -sV <IP-del-host> -p 8090-8100

# Output: 8095/tcp open http Python http.server
```

### Pas 2: Acces directe al servei intern
```bash
# El servei intern es accessible directament des d'Internet
curl http://<IP-publica-del-host>:8095

# Si fos una base de dades
mysql -h <IP-publica-del-host> -P 8095 -u root
```

### Pas 3: Moviment lateral entre contenidors sense segmentació
```bash
# Des d'un contenidor compromès, atacar altres contenidors
# a la mateixa xarxa de Docker

# Escaneig de la xarxa interna de Docker
docker exec -it vuln-insecure-network-config bash
apt-get install -y nmap
nmap -sV 172.17.0.0/24

# Tots els contenidors de la xarxa bridge per defecte son visibles
```

### Pas 4: Atac amb mode xarxa host
```bash
# Si el contenidor usa --network host, comparteix la xarxa del host
docker run --network host ubuntu:22.04 netstat -tuln

# Pot veure i accedir a tots els ports del host
# inclosos serveis que no hauria de veure
```

---

## Solució — docker-compose.yml

```yaml
networks:
  secure-net:
    driver: bridge
    internal: true   # Xarxa sense acces a Internet

services:
  fixed-network:
    ports:
      # Binding nomes a localhost, no accessible des de fora
      - "127.0.0.1:8096:8080"
    networks:
      - secure-net
```

### Verificació de la correcció

```bash
# Construir i executar el contenidor corregit
docker-compose up -d fixed-network

# Comprovar que nomes escolta a localhost
ss -tuln | grep 8096
```

**Resultat esperat:**
```
tcp  127.0.0.1:8096  0.0.0.0:*  LISTEN
# Nomes accessible des del propi host
```

```bash
# Intentar acces des d'una maquina externa
curl http://<IP-del-host>:8096
# Output: Connection refused (no accessible des de fora)

# Acces local funciona correctament
curl http://127.0.0.1:8096
# Output: correcte
```

---

## Explicació de la Solució

| Mesura | Funcio |
|---|---|
| Binding a `127.0.0.1` | El servei nomes es accessible des del propi host |
| `internal: true` a la xarxa | La xarxa de Docker no te acces a Internet ni a l'exterior |
| Xarxes separades per servei | Segmentació: cada grup de contenidors a la seva xarxa |
| Evitar `--network host` | Manteniment de l'aïllament de xarxa del contenidor |

### Arquitectura de xarxa recomanada amb Docker

```
Internet
    |
  Proxy invers (Nginx/Traefik)  <- unic punt d'entrada
    |
  xarxa-frontend (bridge)
    |
  Aplicació web
    |
  xarxa-backend (bridge, internal: true)
    |
  Base de dades          <- mai accessible des de fora
```

Cada capa esta en una xarxa separada. La base de dades nomes es accessible per l'aplicació, i l'aplicació nomes es accessible pel proxy invers.

---

## Bones Practiques

- Mai usar `0.0.0.0` com a binding en serveis que no hagin de ser publics
- Usar `127.0.0.1` per a serveis que nomes hagin de ser accedits localment
- Crear xarxes Docker separades per frontend, backend i base de dades
- Usar `internal: true` per a xarxes que no necessitin acces a Internet
- Evitar `--network host` tret que sigui estrictament necessari
- Usar un proxy invers com a unic punt d'entrada des de l'exterior
- Mai exposar ports de bases de dades o serveis interns directament al host

---

## Referencies

- [Docker Networking Overview](https://docs.docker.com/network/)
- [Docker Bridge Networks](https://docs.docker.com/network/bridge/)
- [CWE-284: Improper Access Control](https://cwe.mitre.org/data/definitions/284.html)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark - Network](https://www.cisecurity.org/benchmark/docker)
