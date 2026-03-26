# Vulnerabilitat 3: Credencials Hardcodejades

## 📌 Descripció Breu

Les credencials hardcodejades es produeixen quan contrasenyes, claus API, tokens o altres secrets s'escriuen directament al codi font, Dockerfiles o fitxers de configuració que acaben al repositori. Qualsevol persona amb accés al repositori (o a la imatge Docker) pot obtenir aquestes credencials i usar-les per accedir a sistemes crítics.

---

## 🎯 Objectius de Seguretat Afectats

- **Confidencialitat** → Credencials exposades permeten accés no autoritzat a bases de dades, APIs i serveis
- **Integritat** → Un atacant pot modificar dades usant les credencials robades
- **Disponibilitat** → Pot eliminar dades o bloquejar l'accés legítim

---

## 🚨 Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Crític |
| **CVE relacionat** | CWE-798 (Use of Hard-coded Credentials) |
| **Impacte real** | Accés complet a bases de dades, APIs i serveis externs |
| **Problema addicional** | Un cop pujat a GitHub, el secret queda en l'historial de commits **per sempre** encara que s'esborri el fitxer |

### Per què és especialment perillós a Docker

Quan fas `docker history <imatge>` o `docker inspect`, es poden veure totes les capes de construcció de la imatge, incloent les variables d'entorn definides amb `ENV`. Qualsevol que tingui accés a la imatge pot extreure les credencials.

---

## 💻 Implementació Vulnerable

```dockerfile
# arnaulo - Vulnerable: credencials hardcodejades al Dockerfile
FROM ubuntu:20.04

RUN apt-get update && apt-get install -y mysql-server python3

# ❌ Credencials visibles directament al Dockerfile
ENV DB_HOST=localhost
ENV DB_USER=admin
ENV DB_PASSWORD=SuperSecret123
ENV DB_NAME=produccio
ENV API_KEY=a3f5c8e2b1d4f7a9c2e5b8d1f4a7c0e3

# ❌ Credencials hardcodejades en un fitxer de configuració
RUN echo "[database]" > /app/config.ini && \
    echo "host=localhost" >> /app/config.ini && \
    echo "user=admin" >> /app/config.ini && \
    echo "password=SuperSecret123" >> /app/config.ini

WORKDIR /app
CMD ["python3", "-m", "http.server", "8080"]
```

### Verificació de la vulnerabilitat

```bash
# Construir la imatge vulnerable
docker build -f Dockerfile.vulnerable -t vuln-credentials .

# Mètode 1: Veure variables d'entorn directament
docker run --rm vuln-credentials env
```

**Resultat esperat:**
```
DB_PASSWORD=SuperSecret123
API_KEY=a3f5c8e2b1d4f7a9c2e5b8d1f4a7c0e3
```

```bash
# Mètode 2: Inspeccionar les capes de la imatge
docker history vuln-credentials
docker inspect vuln-credentials | grep -A5 "Env"
```

---

## 🔓 Com Explotar

### Pas 1: Accedir a la imatge del registre
```bash
# Si la imatge és pública al Docker Hub o GitHub Registry
docker pull usuari/aplicacio:latest
```

### Pas 2: Extreure credencials de la imatge
```bash
# Veure l'historial de construcció
docker history usuari/aplicacio:latest --no-trunc

# Inspeccionar variables d'entorn
docker inspect usuari/aplicacio:latest | grep -i password
docker inspect usuari/aplicacio:latest | grep -i api_key
```

### Pas 3: Extreure credencials del repositori GitHub
```bash
# Buscar credencials a l'historial de commits
git log --all --full-history
git show <commit-hash>

# Eines automatitzades de cerca de secrets
truffleHog --regex --entropy=False https://github.com/usuari/repositori
```

### Pas 4: Usar les credencials robades
```bash
# Connectar a la base de dades amb les credencials trobades
mysql -h <DB_HOST> -u admin -pSuperSecret123 produccio

# Usar la API key robada
curl -H "Authorization: Bearer a3f5c8e2b1d4f7a9c2e5b8d1f4a7c0e3" \
     https://api.servei.com/dades-sensibles
```

---

## ✅ Solució — `Dockerfile.fixed`

```dockerfile
# arnaulo - Fixed: credencials gestionades amb variables d'entorn externes
FROM ubuntu:20.04

RUN apt-get update && apt-get install -y python3

RUN useradd -m -u 1001 appuser

WORKDIR /app

# ✅ Les variables es defineixen sense cap valor sensible
ENV DB_HOST=""
ENV DB_USER=""
ENV DB_PASSWORD=""
ENV DB_NAME=""
ENV API_KEY=""

COPY . .
RUN chown -R appuser:appuser /app

USER appuser

CMD ["python3", "-m", "http.server", "8080"]
```

### Fitxer `.env` (mai al repositori)
```bash
# ✅ Les credencials reals van aquí, fora del codi
DB_HOST=localhost
DB_USER=admin
DB_PASSWORD=SuperSecret123
DB_NAME=produccio
API_KEY=a3f5c8e2b1d4f7a9c2e5b8d1f4a7c0e3
```

### `.gitignore` obligatori
```bash
# Afegir al .gitignore del projecte
.env
*.env
.env.*
config.ini
secrets/
```

### Verificació de la correcció

```bash
# Construir la imatge corregida
docker build -f Dockerfile.fixed -t fixed-credentials .

# Les variables apareixen buides a la imatge
docker inspect fixed-credentials | grep -A5 "Env"
```

**Resultat esperat:**
```
DB_PASSWORD=
API_KEY=
```

```bash
# Les credencials reals s'injecten en temps d'execució
docker-compose up -d

# Verificar que el contenidor rep les variables correctament
docker exec fixed-hardcoded-credentials env | grep DB_
```

---

## 📖 Explicació de la Solució

| Mesura | Funció |
|---|---|
| Variables buides al `Dockerfile` | La imatge no conté cap secret, és segura de compartir |
| Fitxer `.env` local | Les credencials reals només existeixen a la màquina on s'executa |
| `.env` al `.gitignore` | El fitxer de secrets mai arriba al repositori |
| `env_file` al `docker-compose.yml` | Les credencials s'injecten en temps d'execució |

### Alternatives més avançades

Per a entorns de producció real es recomana usar gestors de secrets dedicats:

| Eina | Descripció |
|---|---|
| **Docker Secrets** | Sistema natiu de Docker Swarm per a secrets |
| **HashiCorp Vault** | Gestor de secrets centralitzat |
| **AWS Secrets Manager** | Servei gestionat d'AWS |
| **GitHub Actions Secrets** | Per a pipelines CI/CD |

---

## 🛡️ Bones Pràctiques

- **Mai** escriure credencials al `Dockerfile`, codi font o fitxers de configuració
- Afegir **sempre** `.env` al `.gitignore` abans del primer commit
- Si accidentalment puges un secret a GitHub, **canvia'l immediatament** — esborrar el fitxer no és suficient
- Usar `docker secret` per a entorns Docker Swarm de producció
- Revisar el repositori amb eines com **TruffleHog** o **GitLeaks** periòdicament
- Rotar les credencials regularment

---

## 🔗 Referències

- [CWE-798: Use of Hard-coded Credentials](https://cwe.mitre.org/data/definitions/798.html)
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/)
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [TruffleHog - Secret Scanner](https://github.com/trufflesecurity/trufflehog)
- [GitLeaks](https://github.com/gitleaks/gitleaks)
