# VULNERABILITIES.md - Resum de Vulnerabilitats

**Autors:** Arnau Libori i Ayoub El Ballaoui

---

## Descripció

Aquest document recull el resum de totes les vulnerabilitats documentades al projecte DockerSecLab. Per a cada vulnerabilitat s'indica la categoria, el nivell de risc, una breu descripció i l'enllaç a la documentació detallada.

---

## Index de Vulnerabilitats

| Num | Vulnerabilitat | Categoria | Risc |
|---|---|---|---|
| 1 | running-as-root | Configuració de serveis | Alt |
| 2 | exposed-ports | Xarxa | Alt |
| 3 | hardcoded-credentials | Configuració de serveis | Critic |
| 4 | obsolete-versions | Configuració de serveis | Alt |
| 5 | no-resource-limits | Contenidor/Host | Alt |
| 6 | unnecessary-capabilities | Contenidor/Host | Alt |
| 7 | dangerous-mounts | Contenidor/Host | Critic |
| 8 | unencrypted-communication | Xarxa | Alt |
| 9 | insecure-network-config | Xarxa | Alt |

---

## Categoria: Configuració de Serveis

### Vulnerabilitat 1 - Execució com a Root

**Ubicació:** `vulnerabilities/configuration/running-as-root/`
**Documentació:** `documentation/vulnerabilities/1-running-as-root.md`
**Nivell de risc:** Alt
**CWE:** CWE-250 (Execution with Unnecessary Privileges)

Per defecte, els processos dins d'un contenidor Docker s'executen com a root si no s'especifica cap usuari al Dockerfile. Qualsevol procés compromès dins del contenidor tindrà privilegis maxims i pot arribar a afectar el sistema host.

**Solució aplicada:** Creació d'un usuari no privilegiat amb UID fix i ús de la directiva USER al Dockerfile.

---

### Vulnerabilitat 3 - Credencials Hardcodejades

**Ubicació:** `vulnerabilities/configuration/hardcoded-credentials/`
**Documentació:** `documentation/vulnerabilities/3-hardcoded-credentials.md`
**Nivell de risc:** Critic
**CWE:** CWE-798 (Use of Hard-coded Credentials)

Les credencials escrites directament al Dockerfile, codi font o fitxers de configuració son accessibles per qualsevol persona amb acces al repositori o a la imatge Docker. Un cop pujat a GitHub, el secret queda a l'historial de commits de forma permanent.

**Solució aplicada:** Variables d'entorn buides al Dockerfile, fitxer `.env` extern no inclòs al repositori i `env_file` al docker-compose.yml.

---

### Vulnerabilitat 4 - Versions Obsoletes

**Ubicació:** `vulnerabilities/configuration/obsolete-versions/`
**Documentació:** `documentation/vulnerabilities/4-obsolete-versions.md`
**Nivell de risc:** Alt
**CWE:** CWE-1104 (Use of Unmaintained Third Party Components)

Usar versions antigues de serveis o imatges base exposa el sistema a vulnerabilitats conegudes i documentades públicament. Els atacants poden consultar bases de dades com NVD per trobar exploits ja desenvolupats.

**Solució aplicada:** Imatge base Ubuntu 22.04, versions actuals dels serveis i `apt-get upgrade` durant la construcció.

---

## Categoria: Xarxa

### Vulnerabilitat 2 - Exposició Innecessaria de Ports

**Ubicació:** `vulnerabilities/network/exposed-ports/`
**Documentació:** `documentation/vulnerabilities/2-exposed-ports.md`
**Nivell de risc:** Alt
**CWE:** CWE-16 (Configuration)

Exposar mes ports dels necessaris augmenta la superfície d'atac. Ports de serveis sensibles com bases de dades (3306), SSH (22) o panells d'administració no haurien de ser accessibles des de l'exterior.

**Solució aplicada:** Exposar nomes el port estrictament necessari per a l'aplicació i usar xarxes internes de Docker per a la comunicació entre contenidors.

---

### Vulnerabilitat 8 - Comunicació No Xifrada

**Ubicació:** `vulnerabilities/network/unencrypted-communication/`
**Documentació:** `documentation/vulnerabilities/8-unencrypted-communication.md`
**Nivell de risc:** Alt
**CWE:** CWE-319 (Cleartext Transmission of Sensitive Information)

Quan un contenidor ofereix serveis sense xifrar (HTTP, Telnet, FTP), tota la comunicació viatja en text pla. Qualsevol atacant amb acces a la xarxa pot interceptar credencials, dades sensibles o sessions actives.

**Solució aplicada:** Configuració d'Apache amb SSL/TLS, certificat autosignat i exposició nomes del port HTTPS.

---

### Vulnerabilitat 9 - Configuració de Xarxa Insegura

**Ubicació:** `vulnerabilities/network/insecure-network-config/`
**Documentació:** `documentation/vulnerabilities/9-insecure-network-config.md`
**Nivell de risc:** Alt
**CWE:** CWE-284 (Improper Access Control)

Quan els serveis escolten a totes les interficies (0.0.0.0) o no hi ha segmentació entre contenidors, serveis interns poden ser accessibles des de qualsevol origen. Sense segmentació, un contenidor compromès pot atacar la resta de la xarxa interna.

**Solució aplicada:** Binding a 127.0.0.1, xarxes Docker separades per capa i ús de `internal: true` per a xarxes sense acces a Internet.

---

## Categoria: Contenidor/Host

### Vulnerabilitat 5 - Sense Limits de Recursos

**Ubicació:** `vulnerabilities/container-host/no-resource-limits/`
**Documentació:** `documentation/vulnerabilities/5-no-resource-limits.md`
**Nivell de risc:** Alt
**CWE:** CWE-400 (Uncontrolled Resource Consumption)

Sense limits de CPU, memoria o I/O, un sol contenidor pot consumir tots els recursos del host i causar una denegació de servei que afecti tots els altres contenidors i el propi sistema.

**Solució aplicada:** Definició de limits i reserves de CPU i memoria al docker-compose.yml mitjançant el bloc `deploy.resources`.

---

### Vulnerabilitat 6 - Capabilities Innecessaries

**Ubicació:** `vulnerabilities/container-host/unnecessary-capabilities/`
**Documentació:** `documentation/vulnerabilities/6-unnecessary-capabilities.md`
**Nivell de risc:** Alt
**CWE:** CWE-250 (Execution with Unnecessary Privileges)

Docker assigna per defecte un conjunt de capabilities als contenidors que en molts casos son excessives. Capabilities com CAP_NET_RAW, CAP_SYS_ADMIN o CAP_SETUID poden ser aprofitades per escalar privilegis o escapar al host.

**Solució aplicada:** `cap_drop: ALL` per eliminar totes les capabilities i `cap_add` per afegir nomes les estrictament necessaries. Ús de `no-new-privileges: true`.

---

### Vulnerabilitat 7 - Muntatges Perillosos

**Ubicació:** `vulnerabilities/container-host/dangerous-mounts/`
**Documentació:** `documentation/vulnerabilities/7-dangerous-mounts.md`
**Nivell de risc:** Critic
**CWE:** CWE-284 (Improper Access Control)

Muntar directoris sensibles del host com l'arrel del sistema (/) o el socket de Docker (/var/run/docker.sock) permet que un atacant que comprometi el contenidor obtingui control total sobre el host. Es una de les tecniques d'escapament de contenidors mes habituals.

**Solució aplicada:** Eliminar muntatges de directoris del sistema, muntar nomes directoris especifics de l'aplicació i usar `:ro` per a muntatges de nomes lectura.

---

## Resum per Nivell de Risc

### Critic
- Vulnerabilitat 3: Credencials Hardcodejades
- Vulnerabilitat 7: Muntatges Perillosos

### Alt
- Vulnerabilitat 1: Execució com a Root
- Vulnerabilitat 2: Exposició Innecessaria de Ports
- Vulnerabilitat 4: Versions Obsoletes
- Vulnerabilitat 5: Sense Limits de Recursos
- Vulnerabilitat 6: Capabilities Innecessaries
- Vulnerabilitat 8: Comunicació No Xifrada
- Vulnerabilitat 9: Configuració de Xarxa Insegura

---

## Eines Utilitzades per a la Verificació

| Eina | Funcio |
|---|---|
| Trivy | Escaneig de vulnerabilitats en imatges Docker |
| nmap | Descobriment de ports oberts |
| tcpdump | Captura i analisi de trafic de xarxa |
| docker inspect | Inspeccio de configuració de contenidors |
| capsh | Verificació de capabilities actives |
| docker stats | Monitorització de consum de recursos |

---

## Referències Generals

- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [NVD - National Vulnerability Database](https://nvd.nist.gov/)
- [Trivy - Vulnerability Scanner](https://github.com/aquasecurity/trivy)

---

**Ultima actualitzacio:** Marc 2026
**Versio:** 1.0.0
