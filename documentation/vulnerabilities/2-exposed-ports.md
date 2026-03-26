# Vulnerabilitat 2: Exposició Innecessària de Ports

## 📌 Descripció Breu

Quan un contenidor Docker exposa més ports dels estrictament necessaris per al seu funcionament, s'augmenta la **superfície d'atac** del sistema. Cada port obert és una porta d'entrada potencial per a un atacant. Aquesta vulnerabilitat és especialment perillosa quan s'exposen ports de serveis sensibles com bases de dades (3306), SSH (22) o panells d'administració.

---

## 🎯 Objectius de Seguretat Afectats

- **Confidencialitat** → Ports de bases de dades exposats permeten accés directe a dades sensibles
- **Integritat** → Accés SSH no controlat pot permetre modificacions al sistema
- **Disponibilitat** → Ports exposats poden ser objectiu d'atacs de força bruta o DDoS

---

## 🚨 Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | CWE-16 (Configuration), CWE-200 (Information Exposure) |
| **Impacte real** | Accés directe a serveis interns que no haurien de ser accessibles des de l'exterior |
| **Escenari típic** | Base de dades MySQL accessible des d'Internet sense cap restricció |

### Ports especialment perillosos

| Port | Servei | Risc |
|---|---|---|
| `22` | SSH | Atacs de força bruta, accés remot no autoritzat |
| `3306` | MySQL | Accés directe a la base de dades |
| `5432` | PostgreSQL | Accés directe a la base de dades |
| `6379` | Redis | Accés sense autenticació per defecte |
| `27017` | MongoDB | Accés sense autenticació per defecte |
| `9090` | Prometheus/Admin | Exposició de mètriques internes |

---

## 💻 Implementació Vulnerable

```dockerfile
# arnaulo - Vulnerable: exposició innecessària de ports
FROM ubuntu:20.04

RUN apt-get update && apt-get install -y \
    python3 \
    mysql-server \
    ssh

# ❌ S'exposen tots els ports innecessàriament
EXPOSE 22
EXPOSE 3306
EXPOSE 8080
EXPOSE 8443
EXPOSE 9090

CMD ["python3", "-m", "http.server", "8080"]
```

### Verificació de la vulnerabilitat

```bash
# Construir i executar el contenidor vulnerable
docker build -f Dockerfile.vulnerable -t vuln-ports .
docker run -d -p 8081:8080 -p 2222:22 -p 3307:3306 --name vuln-exposed-ports vuln-ports

# Veure els ports exposats
docker port vuln-exposed-ports
```

**Resultat esperat:**
```
8080/tcp -> 0.0.0.0:8081
22/tcp   -> 0.0.0.0:2222
3306/tcp -> 0.0.0.0:3307
```

```bash
# Escanejar ports amb nmap des de fora
nmap -p 8081,2222,3307 localhost
```

---

## 🔓 Com Explotar

### Pas 1: Descobrir ports oberts
```bash
# Escaneig de ports del contenidor vulnerable
nmap -sV localhost -p 2222,3307,8081

# Output: ports oberts i versions dels serveis
```

### Pas 2: Atac de força bruta a SSH
```bash
# Intentar accés SSH al port exposat
ssh -p 2222 root@localhost

# Amb hydra per força bruta
hydra -l root -P /usr/share/wordlists/rockyou.txt ssh://localhost:2222
```

### Pas 3: Accés directe a la base de dades
```bash
# Connexió directa a MySQL exposat
mysql -h localhost -P 3307 -u root

# Si no té contrasenya o és feble, accés total a les dades
SHOW DATABASES;
SELECT * FROM usuaris;
```

### Pas 4: Exfiltració de dades
```bash
# Volcatge complet de la base de dades
mysqldump -h localhost -P 3307 -u root --all-databases > dump.sql
```

---

## ✅ Solució — `Dockerfile.fixed`

```dockerfile
# arnaulo - Fixed: només s'exposa el port necessari
FROM ubuntu:20.04

RUN apt-get update && apt-get install -y python3

RUN useradd -m -u 1001 appuser

WORKDIR /app
COPY . .
RUN chown -R appuser:appuser /app

USER appuser

# ✅ Només s'exposa el port que realment necessita l'aplicació
EXPOSE 8080

CMD ["python3", "-m", "http.server", "8080"]
```

### Verificació de la correcció

```bash
# Construir i executar el contenidor corregit
docker build -f Dockerfile.fixed -t fixed-ports .
docker run -d -p 8082:8080 --name fixed-exposed-ports fixed-ports

# Verificar que només hi ha un port exposat
docker port fixed-exposed-ports
```

**Resultat esperat:**
```
8080/tcp -> 0.0.0.0:8082
```

```bash
# Intentar connexió a ports que no haurien d'estar oberts
nmap -p 2222,3307 localhost
# Output: ports tancats o filtrats
```

---

## 📖 Explicació de la Solució

| Mesura | Funció |
|---|---|
| Eliminar `EXPOSE` innecessaris | Redueix la superfície d'atac visible |
| Eliminar serveis no necessaris | Menys serveis = menys vectors d'atac |
| Mapeig explícit de ports al `docker-compose.yml` | Control total de quins ports arriben a l'exterior |
| Usar xarxes internes de Docker | Els serveis interns es comuniquen sense exposar-se al host |

### Comunicació interna segura amb Docker networks

Quan dos contenidors necessiten comunicar-se (ex. app + base de dades), **no cal exposar el port al host**. Docker permet comunicació interna:

```yaml
# docker-compose.yml correcte
services:
  app:
    ports:
      - "8080:8080"  # ✅ Només l'app és accessible des de fora
  
  database:
    # ❌ NO posar ports aquí
    # La base de dades és accessible internament per nom de servei
```

L'app es connecta a la base de dades usant `database:3306` internament, sense exposar res a l'exterior.

---

## 🛡️ Bones Pràctiques

- **Principi de mínim privilegi de xarxa**: exposar només els ports estrictament necessaris
- Usar **xarxes internes de Docker** per comunicació entre contenidors
- Mai exposar ports de bases de dades (3306, 5432, 27017) directament a Internet
- Mai exposar SSH (22) en contenidors de producció
- Usar un **reverse proxy** (Nginx, Traefik) com a únic punt d'entrada
- Revisar periòdicament amb `docker ps` i `nmap` els ports realment oberts

---

## 🔗 Referències

- [Docker Networking](https://docs.docker.com/network/)
- [CWE-16: Configuration](https://cwe.mitre.org/data/definitions/16.html)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark - Network](https://www.cisecurity.org/benchmark/docker)
