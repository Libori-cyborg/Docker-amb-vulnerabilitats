# Vulnerabilitat 1: Execució com a Root

## 📌 Descripció Breu

Per defecte, els processos dins d'un contenidor Docker s'executen com a **root (UID 0)** si no s'especifica cap usuari al Dockerfile. Això significa que qualsevol procés compromès dins del contenidor tindrà privilegis màxims dins del sistema de fitxers del contenidor i, en alguns escenaris, pot arribar a afectar el sistema host.

---

## 🎯 Objectius de Seguretat Afectats

- **Confidencialitat** → Un atacant pot llegir fitxers sensibles del contenidor
- **Integritat** → Pot modificar fitxers de sistema, binaris o configuracions
- **Disponibilitat** → Pot aturar processos crítics o eliminar dades

---

## 🚨 Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | CWE-250 (Execution with Unnecessary Privileges) |
| **Impacte real** | Si l'aplicació té una vulnerabilitat (ex. RCE), l'atacant obtindrà accés root dins del contenidor |
| **Escapament** | Combinat amb altres vulnerabilitats (ex. muntatges perillosos), pot permetre sortir al host |

### Escenari real
Si una aplicació web corre com a root i té una vulnerabilitat de Remote Code Execution (RCE), l'atacant pot:
1. Executar comandes arbitràries com a root
2. Llegir fitxers sensibles (`/etc/shadow`, credencials, tokens)
3. Instal·lar malware o backdoors dins del contenidor
4. Intentar escapar al sistema host si hi ha muntatges mal configurats

---

## 💻 Implementació Vulnerable

```dockerfile
# arnaulo - Vulnerable: contenidor executant-se com a root
FROM ubuntu:20.04

RUN apt-get update && apt-get install -y python3

WORKDIR /app
COPY . .

# ❌ No s'especifica cap usuari → corre com a root per defecte
CMD ["python3", "-m", "http.server", "8080"]
```

### Verificació de la vulnerabilitat

```bash
# Construir i executar el contenidor vulnerable
docker build -f Dockerfile.vulnerable -t vuln-root .
docker run --rm vuln-root whoami
```

**Resultat esperat:**
```
root
```

```bash
# Veure l'UID del procés
docker run --rm vuln-root id
```

**Resultat esperat:**
```
uid=0(root) gid=0(root) groups=0(root)
```

---

## 🔓 Com Explotar

### Pas 1: Confirmar que corre com a root
```bash
docker exec -it vuln-running-as-root whoami
# Output: root
```

### Pas 2: Accedir a fitxers sensibles
```bash
docker exec -it vuln-running-as-root cat /etc/shadow
# Com a root, pot llegir contrasenyes del sistema
```

### Pas 3: Modificar fitxers de sistema
```bash
docker exec -it vuln-running-as-root bash -c "echo 'malware' > /usr/bin/python3"
# Pot sobreescriure binaris del sistema
```

### Pas 4: Escalar si hi ha muntatge del host
```bash
# Si el contenidor té /host muntat
docker exec -it vuln-running-as-root ls /host/etc/
# Accés complet al sistema de fitxers del host
```

---

## ✅ Solució — `Dockerfile.fixed`

```dockerfile
# arnaulo - Fixed: contenidor amb usuari no privilegiat
FROM ubuntu:20.04

RUN apt-get update && apt-get install -y python3

# ✅ Creem un usuari dedicat sense privilegis
RUN useradd -m -u 1001 appuser

WORKDIR /app
COPY . .

# ✅ Assignem propietat dels fitxers a l'usuari
RUN chown -R appuser:appuser /app

# ✅ Canviem a l'usuari no privilegiat
USER appuser

CMD ["python3", "-m", "http.server", "8080"]
```

### Verificació de la correcció

```bash
# Construir i executar el contenidor corregit
docker build -f Dockerfile.fixed -t fixed-root .
docker run --rm fixed-root whoami
```

**Resultat esperat:**
```
appuser
```

```bash
docker run --rm fixed-root id
```

**Resultat esperat:**
```
uid=1001(appuser) gid=1001(appuser) groups=1001(appuser)
```

---

## 📖 Explicació de la Solució

| Directiva | Funció |
|---|---|
| `RUN useradd -m -u 1001 appuser` | Crea un usuari sense privilegis amb UID fix |
| `RUN chown -R appuser:appuser /app` | Assigna els fitxers de l'aplicació a l'usuari |
| `USER appuser` | Tots els processos posteriors corren com aquest usuari |

L'ús d'un **UID numèric fix (1001)** és una bona pràctica perquè garanteix consistència entre diferents entorns i evita col·lisions amb usuaris del host.

---

## 🛡️ Bones Pràctiques

- Sempre especificar `USER` al Dockerfile abans del `CMD` o `ENTRYPOINT`
- Usar UIDs numèrics en lloc de noms (`USER 1001` en lloc de `USER appuser`)
- Mai executar serveis de producció com a root
- Aplicar el **principi de mínim privilegi**: l'usuari només ha de tenir accés al que necessita
- Revisar les imatges base — algunes imatges oficials ja inclouen usuaris no privilegiats

---

## 🔗 Referències

- [Docker Security - Non-root users](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user)
- [CWE-250: Execution with Unnecessary Privileges](https://cwe.mitre.org/data/definitions/250.html)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
