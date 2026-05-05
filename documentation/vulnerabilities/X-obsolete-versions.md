# Vulnerabilitat 4: Versions Obsoletes

## Descripció Breu

Usar versions antigues de serveis, llibreries o imatges base en contenidors Docker exposa el sistema a vulnerabilitats conegudes i documentades públicament (CVEs). Els atacants poden consultar bases de dades de vulnerabilitats com NVD o CVE Details per trobar exploits ja desenvolupats contra versions específiques de software. A mes, les versions EOL (End of Life) deixen de rebre pegats de seguretat oficials, deixant el sistema permanentment exposat.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Vulnerabilitats conegudes poden permetre acces a dades sensibles
- **Integritat** -> Exploits documentats poden permetre modificació del sistema
- **Disponibilitat** -> Algunes vulnerabilitats permeten atacs de denegació de servei (DoS)

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | Multiples CVEs segons la versió usada |
| **Impacte real** | Explotació directa amb exploits públics disponibles |
| **Problema addicional** | Les imatges Docker es construeixen una vegada i poden quedar desactualitzades sense que ningú ho noti |

### Diferència entre versió vulnerable i corregida

| Element | Vulnerable | Fixed |
|---|---|---|
| Imatge base | Ubuntu 20.04 (EOL abril 2025) | Ubuntu 22.04 (suport fins 2027) |
| PHP | 7.4 (EOL novembre 2022) | 8.1 (suport actiu) |
| Apache | Versió antiga del repositori 20.04 | Versió actualitzada del repositori 22.04 |
| Pegats de seguretat | Sense actualitzacions oficials | Pegats actius disponibles |

### Exemples de CVEs reals per versions antigues

| Software | Versió vulnerable | CVE | Impacte |
|---|---|---|---|
| Apache 2.4.49 | < 2.4.51 | CVE-2021-41773 | Path Traversal + RCE |
| PHP 7.4 | EOL | CVE-2022-31625 | Use after free, RCE |
| PHP 7.4 | EOL | CVE-2021-21703 | Escalada de privilegis local |
| Ubuntu 20.04 | EOL abril 2025 | Multiples | Sense pegats de seguretat oficials |

---

## Implementació Vulnerable

```dockerfile
# Vulnerable: versions obsoletes amb CVEs coneguts
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    apache2 \
    php7.4 \
    openssl

EXPOSE 80 443

CMD ["apache2ctl", "-D", "FOREGROUND"]
```

### Verificació de la vulnerabilitat

```bash
# Construir i executar el contenidor vulnerable
docker build -f Dockerfile.vulnerable -t vuln-versions .
docker run -d -p 8087:80 --name vuln-obsolete-versions vuln-versions

# Comprovar versions instal·lades
docker exec vuln-obsolete-versions apache2 -v
docker exec vuln-obsolete-versions php --version
docker exec vuln-obsolete-versions cat /etc/os-release | grep VERSION
```

**Resultat esperat:**
```
Server version: Apache/2.4.41 (Ubuntu)
PHP 7.4.x (cli)
VERSION_ID="20.04"
```

```bash
# Escanejar vulnerabilitats amb Trivy
trivy image vuln-versions
```

**Resultat esperat de Trivy:**
```
CRITICAL: 5+
HIGH:     12+
PHP 7.4   CVE-2022-31625   CRITICAL
PHP 7.4   CVE-2021-21703   HIGH
...
```

---

## Com Explotar

### Pas 1: Identificar versions en ús
```bash
# Escaneig de versions amb nmap
nmap -sV -p 8087 localhost

# Output: Apache/2.4.41 (Ubuntu)
```

### Pas 2: Buscar CVEs per la versió trobada
```bash
# Consultar base de dades de vulnerabilitats
# https://nvd.nist.gov/vuln/search
# Cercar: php 7.4 o apache 2.4.41

# O amb Searchsploit localment
searchsploit apache 2.4.41
searchsploit php 7.4
```

### Pas 3: Escaneig automatitzat de CVEs
```bash
# Trivy per escanejar la imatge completa
trivy image vuln-versions --severity CRITICAL,HIGH

# Grype com a alternativa
grype vuln-versions
```

### Pas 4: Verificar que la versió es EOL
```bash
# Comprovar data de fi de suport
docker exec vuln-obsolete-versions cat /etc/os-release
# Ubuntu 20.04 -> EOL abril 2025, sense pegats oficials nous
```

---

## Solució — Dockerfile.fixed

```dockerfile
# Fixed: versions actualitzades i imatge base moderna
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    apache2 \
    php8.1 \
    openssl

RUN useradd -m -u 1001 appuser

RUN apt-get upgrade -y && apt-get clean

EXPOSE 80

USER appuser

CMD ["apache2ctl", "-D", "FOREGROUND"]
```

### Verificació de la correcció

```bash
# Construir i executar el contenidor corregit
docker build -f Dockerfile.fixed -t fixed-versions .
docker run -d -p 8088:80 --name fixed-obsolete-versions fixed-versions

# Comprovar versions actuals
docker exec fixed-obsolete-versions apache2 -v
docker exec fixed-obsolete-versions php --version
docker exec fixed-obsolete-versions cat /etc/os-release | grep VERSION
```

**Resultat esperat:**
```
Server version: Apache/2.4.52+ (Ubuntu)
PHP 8.1.x (cli)
VERSION_ID="22.04"
```

```bash
# Escanejar amb Trivy
trivy image fixed-versions --severity CRITICAL,HIGH
```

**Resultat esperat:**
```
CRITICAL: 0
HIGH:     0
```

---

## Explicació de la Solució

| Mesura | Funcio |
|---|---|
| Usar `ubuntu:22.04` en lloc de `20.04` | Imatge base amb suport actiu fins 2027 |
| PHP 8.1 en lloc de 7.4 | Versió amb suport actiu i pegats de seguretat |
| Apache actualitzat | Sense CVEs critics coneguts en la versió del repositori 22.04 |
| `apt-get upgrade -y` | Aplica tots els pegats disponibles en el moment de la construcció |
| `apt-get clean` | Redueix la mida de la imatge eliminant caché innecessaria |

### Bones pràctiques per mantenir les versions actualitzades

Per evitar que les imatges quedin obsoletes amb el temps, cal reconstruir-les periòdicament:

```bash
# Reconstruir sense usar la caché de Docker
docker build --no-cache -f Dockerfile.fixed -t fixed-versions .

# Comprovar si hi ha actualitzacions disponibles
trivy image fixed-versions
```

---

## Bones Practiques

- Usar sempre imatges base amb suport actiu (LTS vigent)
- Revisar les dates EOL dels serveis que s'utilitzen
- Integrar Trivy o Grype al pipeline CI/CD per detectar vulnerabilitats automaticament
- Reconstruir les imatges periòdicament per incorporar pegats de seguretat
- Subscriure's a alertes de seguretat dels serveis utilitzats
- Evitar fixar versions massa especifiques al Dockerfile sense un proces de revisió periodic

---

## Referencies

- [Ubuntu Release Cycle](https://ubuntu.com/about/release-cycle)
- [PHP Supported Versions](https://www.php.net/supported-versions.php)
- [CVE-2022-31625 - PHP](https://nvd.nist.gov/vuln/detail/CVE-2022-31625)
- [CVE-2021-41773 - Apache](https://nvd.nist.gov/vuln/detail/CVE-2021-41773)
- [NVD - National Vulnerability Database](https://nvd.nist.gov/)
- [Trivy - Container Vulnerability Scanner](https://github.com/aquasecurity/trivy)
- [Grype - Vulnerability Scanner](https://github.com/anchore/grype)
- [Docker Official Images](https://hub.docker.com/search?q=&type=image&image_filter=official)
