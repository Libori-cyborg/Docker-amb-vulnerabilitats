# Vulnerabilitat 5: Sense Limits de Recursos

## Descripció Breu

Quan un contenidor Docker no té definits limits de CPU, memoria o I/O, pot consumir tots els recursos disponibles del sistema host. Això permet que un sol contenidor compromès o mal funcionant afecti tots els altres contenidors i el propi host, causant una denegació de servei (DoS) no intencionada o provocada per un atacant.

---

## Objectius de Seguretat Afectats

- **Disponibilitat** -> Un contenidor sense limits pot exhaurir els recursos del host i aturar tots els serveis
- **Integritat** -> Un atacant pot forçar el sistema a un estat inestable
- **Confidencialitat** -> En alguns escenaris, l'esgotament de recursos pot provocar comportaments inesperats que exposin dades

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | CWE-400 (Uncontrolled Resource Consumption) |
| **Impacte real** | Denegació de servei de tot el sistema host |
| **Escenari tipic** | Un atacant envia peticions massives a un contenidor vulnerable que no te limit de CPU ni memoria |

### Recursos afectats sense limits

| Recurs | Consequencia sense limit |
|---|---|
| CPU | El contenidor pot usar el 100% de tots els nuclis |
| Memoria RAM | El sistema pot quedar sense memoria i activar l'OOM Killer |
| I/O de disc | Pot saturar el disc i bloquejar altres processos |
| Xarxa | Pot saturar l'amplada de banda disponible |

---

## Implementació Vulnerable

```dockerfile
# Vulnerable: contenidor sense limits de recursos
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y python3 stress

WORKDIR /app

# Sense cap limit de CPU, memoria ni I/O
CMD ["python3", "-m", "http.server", "8080"]
```

### Verificació de la vulnerabilitat

```bash
# Construir i executar el contenidor vulnerable
docker build -f Dockerfile.vulnerable -t vuln-resources .
docker run -d -p 8087:8080 --name vuln-no-resource-limits vuln-resources

# Comprovar que no te limits definits
docker inspect vuln-no-resource-limits | grep -A5 "HostConfig" | grep -E "Memory|Cpu"
```

**Resultat esperat (sense limits):**
```
"Memory": 0,
"CpuShares": 0,
"CpuPeriod": 0,
"CpuQuota": 0,
```

---

## Com Explotar

### Pas 1: Confirmar que no hi ha limits
```bash
docker stats vuln-no-resource-limits
# Veure que el limit de memoria i CPU apareix com a 0 o sense limit
```

### Pas 2: Simular un atac de consum de CPU (Fork Bomb de CPU)
```bash
# Entrar al contenidor vulnerable
docker exec -it vuln-no-resource-limits bash

# Executar stress per consumir tots els nuclis de CPU
stress --cpu 8 --timeout 60

# En una altra terminal, observar l'impacte al host
top
```

### Pas 3: Simular un atac de consum de memoria
```bash
# Des de dins del contenidor vulnerable
stress --vm 4 --vm-bytes 512M --timeout 60

# Observar des del host
free -h
docker stats
```

### Pas 4: Observar l'impacte als altres contenidors
```bash
# Des del host, veure com tots els contenidors es veuen afectats
docker stats --no-stream

# L'OOM Killer pot arribar a matar processos del host
dmesg | grep -i "oom"
```

---

## Solució — Dockerfile.fixed i docker-compose.yml

La solució principal no esta al Dockerfile sino al docker-compose.yml, on es defineixen els limits:

```yaml
services:
  fixed-resources:
    build:
      context: .
      dockerfile: Dockerfile.fixed
    container_name: fixed-no-resource-limits
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M
```

### Verificació de la correcció

```bash
# Construir i executar el contenidor corregit
docker-compose up -d fixed-resources

# Comprovar que te limits definits
docker inspect fixed-no-resource-limits | grep -E "Memory|CpuQuota"
```

**Resultat esperat:**
```
"Memory": 268435456,
"CpuQuota": 50000,
```

```bash
# Intentar el mateix atac de stress
docker exec -it fixed-no-resource-limits bash
stress --cpu 8 --timeout 60

# El contenidor quedara limitat i no afectara el host
docker stats fixed-no-resource-limits
# CPU max: ~50% | MEM max: ~256MB
```

---

## Explicació de la Solució

| Parametre | Valor | Funcio |
|---|---|---|
| `cpus: '0.50'` | 50% d'un nucli | Limita el temps de CPU que pot usar el contenidor |
| `memory: 256M` | 256 megabytes | Limit dur de memoria RAM |
| `reservations.cpus` | 25% | CPU garantida minima per al contenidor |
| `reservations.memory` | 128M | Memoria garantida minima |

### Com calcular els limits adequats

Els limits s'han d'ajustar segons les necessitats reals de l'aplicació:

```bash
# Monitoritzar el consum real en condicions normals
docker stats --no-stream

# Establir el limit com a 2x el consum maxim normal
# Exemple: si l'app usa 128MB de pic, posar limit a 256MB
```

---

## Bones Practiques

- Definir sempre limits de CPU i memoria a tots els contenidors de produccio
- Usar `reservations` per garantir recursos minims als serveis critics
- Monitoritzar el consum amb `docker stats` o eines com Prometheus + cAdvisor
- Configurar alertes quan un contenidor s'apropi al seu limit
- Usar Linux cgroups per a un control mes granular si cal
- Revisar periodacament els limits i ajustar-los segons el creixement de l'aplicació

---

## Referencies

- [Docker Resource Constraints](https://docs.docker.com/config/containers/resource_constraints/)
- [CWE-400: Uncontrolled Resource Consumption](https://cwe.mitre.org/data/definitions/400.html)
- [Linux cgroups Documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html)
- [cAdvisor - Container Monitoring](https://github.com/google/cadvisor)
- [Prometheus + Docker](https://prometheus.io/docs/guides/dockerswarm/)
