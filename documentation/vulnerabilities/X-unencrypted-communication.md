# Vulnerabilitat 8: Comunicació No Xifrada

## Descripció Breu

Quan un contenidor ofereix serveis de xarxa sense xifrar (HTTP, Telnet, FTP), tota la comunicació entre el client i el servidor viatja en text pla. Qualsevol atacant amb acces a la xarxa pot interceptar el trafic i llegir credencials, dades sensibles o sessions actives. Aquesta vulnerabilitat és especialment critica en entorns on multiples contenidors es comuniquen entre ells o amb clients externs.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Les dades transmeses poden ser llegides per tercers
- **Integritat** -> El trafic pot ser modificat en transit (atac Man-in-the-Middle)
- **Autenticitat** -> Sense certificats no es pot verificar la identitat del servidor

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | CWE-319 (Cleartext Transmission of Sensitive Information) |
| **Impacte real** | Interceptació de credencials, sessions i dades sensibles |
| **Escenari tipic** | Atac Man-in-the-Middle en una xarxa compartida o en la xarxa interna de Docker |

### Protocols vulnerables habituals en contenidors

| Protocol | Port | Protocol segur | Port segur |
|---|---|---|---|
| HTTP | 80 | HTTPS (TLS) | 443 |
| Telnet | 23 | SSH | 22 |
| FTP | 21 | SFTP / FTPS | 22 / 990 |
| SMTP | 25 | SMTPS | 465 |
| LDAP | 389 | LDAPS | 636 |

---

## Implementació Vulnerable

```dockerfile
# Vulnerable: servidor web amb comunicació HTTP sense xifrar
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y apache2

# Nomes HTTP, sense cap configuració SSL/TLS
EXPOSE 80

CMD ["apache2ctl", "-D", "FOREGROUND"]
```

### Verificació de la vulnerabilitat

```bash
# Construir i executar el contenidor vulnerable
docker build -f Dockerfile.vulnerable -t vuln-communication .
docker run -d -p 8093:80 --name vuln-unencrypted-communication vuln-communication

# Comprovar que nomes respon per HTTP
curl -v http://localhost:8093
curl -v https://localhost:8093
# HTTP funciona, HTTPS falla
```

---

## Com Explotar

### Pas 1: Interceptar trafic HTTP amb tcpdump
```bash
# Des del host, capturar trafic al port 8093
sudo tcpdump -i lo -A port 8093

# En una altra terminal, fer una peticio amb credencials
curl -X POST http://localhost:8093/login \
     -d "username=admin&password=secret123"
```

**Resultat esperat a tcpdump:**
```
POST /login HTTP/1.1
Host: localhost:8093
username=admin&password=secret123
```

### Pas 2: Atac Man-in-the-Middle amb Wireshark
```bash
# Capturar trafic entre contenidors a la xarxa de Docker
sudo wireshark &
# Seleccionar interficie docker0
# Filtrar: http

# Tot el trafic HTTP apareix en text pla incloent cookies de sessio
```

### Pas 3: Robar cookies de sessio
```bash
# Capturar la capçalera Cookie en trafic HTTP
sudo tcpdump -i docker0 -A | grep -i "cookie:"

# Output:
# Cookie: session=abc123xyz; user=admin
```

---

## Solució — Dockerfile.fixed

```dockerfile
# Fixed: servidor web amb HTTPS i certificat SSL
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y apache2 openssl

# Habilitar mod_ssl
RUN a2enmod ssl && a2ensite default-ssl

# Generar certificat autosignat
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/apache-selfsigned.key \
    -out /etc/ssl/certs/apache-selfsigned.crt \
    -subj "/C=ES/ST=Catalunya/L=Barcelona/O=DockerSecLab/CN=localhost"

RUN useradd -m -u 1001 appuser

EXPOSE 443
EXPOSE 80

CMD ["apache2ctl", "-D", "FOREGROUND"]
```

### Verificació de la correcció

```bash
# Construir i executar el contenidor corregit
docker-compose up -d fixed-communication

# Comprovar que respon per HTTPS
curl -vk https://localhost:8443

# Interceptar trafic HTTPS
sudo tcpdump -i lo -A port 8443
# El trafic apareix xifrat, illegible
```

**Resultat esperat de tcpdump amb HTTPS:**
```
.............V..k...lAW..S......
..b.h.......p...4..}....f.......
# Dades xifrades, no llegibles
```

---

## Explicació de la Solució

| Mesura | Funcio |
|---|---|
| `a2enmod ssl` | Habilita el modul SSL d'Apache |
| `a2ensite default-ssl` | Habilita el virtualhost HTTPS per defecte |
| Certificat autosignat | Permet xifrar la comunicació en entorns de desenvolupament |
| `EXPOSE 443` | El servei escolta per HTTPS |

### Certificat autosignat vs certificat de CA

| Tipus | Us recomanat | Validació |
|---|---|---|
| Autosignat | Desenvolupament i laboratori | Cap validació externa |
| Let's Encrypt | Produccio amb domini public | Validat per CA publica gratuita |
| Certificat comercial | Produccio critica | Validat per CA comercial |

### Configuració addicional recomanada — redirecció HTTP a HTTPS

```apache
# /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    # Redirigir tot el trafic HTTP a HTTPS
    Redirect permanent / https://localhost/
</VirtualHost>
```

---

## Bones Practiques

- Usar sempre HTTPS per a qualsevol servei web, fins i tot en entorns interns
- Desactivar protocols antics com TLS 1.0 i TLS 1.1, usar nomes TLS 1.2 i 1.3
- Redirigir sempre el trafic HTTP (port 80) a HTTPS (port 443)
- Usar Let's Encrypt per a certificats gratuïts i automatics en produccio
- Configurar HSTS (HTTP Strict Transport Security) per forçar HTTPS al navegador
- Renovar els certificats abans que caduquin
- Mai usar Telnet ni FTP en contenidors, substituir per SSH i SFTP

---

## Referencies

- [Apache SSL/TLS Documentation](https://httpd.apache.org/docs/2.4/ssl/)
- [Let's Encrypt](https://letsencrypt.org/)
- [CWE-319: Cleartext Transmission of Sensitive Information](https://cwe.mitre.org/data/definitions/319.html)
- [OWASP Transport Layer Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
