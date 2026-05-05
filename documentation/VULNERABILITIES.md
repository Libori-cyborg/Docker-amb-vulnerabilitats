# VULNERABILITIES.md - Resum de Vulnerabilitats

**Autors:** Arnau Libori i Ayoub El Ballaoui

---

## Descripció

Aquest document recull el resum de totes les vulnerabilitats documentades al projecte DockerSecLab. El projecte esta dividit en dues categories principals: vulnerabilitats de configuracio de Docker i vulnerabilitats de serveis reals.

---

## Index General

| Num | Vulnerabilitat | Categoria | Risc |
|---|---|---|---|
| 1 | running-as-root | Configuracio Docker | Alt |
| 2 | exposed-ports | Configuracio Docker - Xarxa | Alt |
| 3 | hardcoded-credentials | Configuracio Docker | Critic |
| 4 | obsolete-versions | Configuracio Docker | Alt |
| 5 | no-resource-limits | Configuracio Docker - Host | Alt |
| 6 | unnecessary-capabilities | Configuracio Docker - Host | Alt |
| 7 | dangerous-mounts | Configuracio Docker - Host | Critic |
| 8 | unencrypted-communication | Configuracio Docker - Xarxa | Alt |
| 9 | insecure-network-config | Configuracio Docker - Xarxa | Alt |
| S1 | Apache CVE-2021-41773 | Serveis | Critic |
| S2 | Nginx Misconfiguracio | Serveis | Alt |
| S3 | MySQL Credencials Febles | Serveis | Critic |
| S4 | SSH Configuracio Insegura | Serveis | Alt |
| S5 | vsftpd CVE-2011-2523 | Serveis | Critic |

---

## Part 1 - Vulnerabilitats de Configuracio Docker

### Categoria: Configuracio de Serveis

#### Vulnerabilitat 1 - Execucio com a Root
**Ubicacio:** `vulnerabilities/configuration/running-as-root/`
**Documentacio:** `documentation/vulnerabilities/1-running-as-root.md`
**Nivell de risc:** Alt | **CWE:** CWE-250

Per defecte, els processos dins d'un contenidor Docker s'executen com a root si no s'especifica cap usuari al Dockerfile.

**Solucio aplicada:** Creacio d'un usuari no privilegiat amb UID fix i us de la directiva USER.

---

#### Vulnerabilitat 3 - Credencials Hardcodejades
**Ubicacio:** `vulnerabilities/configuration/hardcoded-credentials/`
**Documentacio:** `documentation/vulnerabilities/3-hardcoded-credentials.md`
**Nivell de risc:** Critic | **CWE:** CWE-798

Credencials visibles al Dockerfile i a l'historial de commits de GitHub permanentment.

**Solucio aplicada:** Variables buides al Dockerfile i fitxer .env extern no inclòs al repositori.

---

#### Vulnerabilitat 4 - Versions Obsoletes
**Ubicacio:** `vulnerabilities/configuration/obsolete-versions/`
**Documentacio:** `documentation/vulnerabilities/4-obsolete-versions.md`
**Nivell de risc:** Alt | **CWE:** CWE-1104

Ubuntu 20.04 (EOL) amb PHP 7.4 (EOL) sense pegats de seguretat oficials disponibles.

**Solucio aplicada:** Ubuntu 22.04 + PHP 8.1 amb suport actiu.

---

### Categoria: Xarxa

#### Vulnerabilitat 2 - Exposicio Innecessaria de Ports
**Ubicacio:** `vulnerabilities/network/exposed-ports/`
**Documentacio:** `documentation/vulnerabilities/2-exposed-ports.md`
**Nivell de risc:** Alt | **CWE:** CWE-16

Ports de serveis sensibles com bases de dades o SSH accessibles des de l'exterior.

**Solucio aplicada:** Exposar nomes el port estrictament necessari per a l'aplicacio.

---

#### Vulnerabilitat 8 - Comunicacio No Xifrada
**Ubicacio:** `vulnerabilities/network/unencrypted-communication/`
**Documentacio:** `documentation/vulnerabilities/8-unencrypted-communication.md`
**Nivell de risc:** Alt | **CWE:** CWE-319

HTTP sense xifrar permet interceptar credencials i dades sensibles en transit.

**Solucio aplicada:** Apache amb SSL/TLS i certificat autosignat.

---

#### Vulnerabilitat 9 - Configuracio de Xarxa Insegura
**Ubicacio:** `vulnerabilities/network/insecure-network-config/`
**Documentacio:** `documentation/vulnerabilities/9-insecure-network-config.md`
**Nivell de risc:** Alt | **CWE:** CWE-284

Binding a 0.0.0.0 i manca de segmentacio entre contenidors.

**Solucio aplicada:** Binding a 127.0.0.1 i xarxes Docker segmentades amb internal: true.

---

### Categoria: Contenidor/Host

#### Vulnerabilitat 5 - Sense Limits de Recursos
**Ubicacio:** `vulnerabilities/container-host/no-resource-limits/`
**Documentacio:** `documentation/vulnerabilities/5-no-resource-limits.md`
**Nivell de risc:** Alt | **CWE:** CWE-400

Un contenidor sense limits pot consumir tots els recursos del host causant DoS.

**Solucio aplicada:** Limits de CPU i memoria definits al docker-compose.yml.

---

#### Vulnerabilitat 6 - Capabilities Innecessaries
**Ubicacio:** `vulnerabilities/container-host/unnecessary-capabilities/`
**Documentacio:** `documentation/vulnerabilities/6-unnecessary-capabilities.md`
**Nivell de risc:** Alt | **CWE:** CWE-250

Capabilities excessives com CAP_NET_RAW permeten sniffing i possible escapament al host.

**Solucio aplicada:** cap_drop: ALL i cap_add nomes amb les capabilities necessaries.

---

#### Vulnerabilitat 7 - Muntatges Perillosos
**Ubicacio:** `vulnerabilities/container-host/dangerous-mounts/`
**Documentacio:** `documentation/vulnerabilities/7-dangerous-mounts.md`
**Nivell de risc:** Critic | **CWE:** CWE-284

Muntar / o /var/run/docker.sock permet escapament complet al host.

**Solucio aplicada:** Eliminar muntatges del sistema i usar :ro per a nomes lectura.

---

## Part 2 - Vulnerabilitats de Serveis

### Servei 1 - Apache CVE-2021-41773
**Ubicacio:** `vulnerabilities/services/apache/`
**Documentacio:** `documentation/vulnerabilities/s1-apache-cve-2021-41773.md`
**Nivell de risc:** Critic | **CVE:** CVE-2021-41773 | **CVSS:** 9.8
**Ports:** Vulnerable: 9001 | Fixed: 9002

Apache 2.4.49 permet Path Traversal i RCE via CGI. Explotada activament en la natura.

**Solucio aplicada:** Actualitzacio a Apache 2.4.51+ i desactivacio de CGI.

---

### Servei 2 - Nginx Misconfiguracio
**Ubicacio:** `vulnerabilities/services/nginx/`
**Documentacio:** `documentation/vulnerabilities/s2-nginx-misconfiguracio.md`
**Nivell de risc:** Alt | **CWE:** CWE-548
**Ports:** Vulnerable: 9003 | Fixed: 9004

Directory listing i server_tokens on permeten enumerar fitxers i obtenir la versio exacta.

**Solucio aplicada:** autoindex off, server_tokens off i bloqueig de fitxers sensibles.

---

### Servei 3 - MySQL Credencials Febles
**Ubicacio:** `vulnerabilities/services/mysql/`
**Documentacio:** `documentation/vulnerabilities/s3-mysql-credencials-febles.md`
**Nivell de risc:** Critic | **CWE:** CWE-521
**Ports:** Vulnerable: 3308 | Fixed: 3309 (nomes local)

MySQL accessible remotament sense contrasenya de root permet acces i exfiltracio completa.

**Solucio aplicada:** bind-address 127.0.0.1, contrasenya forta i eliminacio d'usuaris anonims.

---

### Servei 4 - SSH Configuracio Insegura
**Ubicacio:** `vulnerabilities/services/ssh/`
**Documentacio:** `documentation/vulnerabilities/s4-ssh-configuracio-insegura.md`
**Nivell de risc:** Alt | **CWE:** CWE-521
**Ports:** Vulnerable: 2223 | Fixed: 2224

PermitRootLogin yes amb contrasenya feble permet acces root via força bruta automatitzada.

**Solucio aplicada:** PermitRootLogin no, nomes clau publica i MaxAuthTries 3.

---

### Servei 5 - vsftpd CVE-2011-2523 Backdoor
**Ubicacio:** `vulnerabilities/services/ftp/`
**Documentacio:** `documentation/vulnerabilities/s5-ftp-vsftpd-backdoor.md`
**Nivell de risc:** Critic | **CVE:** CVE-2011-2523 | **CVSS:** 10.0
**Ports:** Vulnerable: 2121 | Fixed: 2122

Backdoor al codi font de vsftpd 2.3.4 que obre shell root al port 6200 sense autenticacio.

**Solucio aplicada:** Actualitzacio a vsftpd 3.0.x des dels repositoris oficials del sistema.

---

## Resum per Nivell de Risc

### Critic
- Vulnerabilitat 3: Credencials Hardcodejades
- Vulnerabilitat 7: Muntatges Perillosos
- Servei 1: Apache CVE-2021-41773
- Servei 3: MySQL Credencials Febles
- Servei 5: vsftpd CVE-2011-2523

### Alt
- Vulnerabilitat 1: Execucio com a Root
- Vulnerabilitat 2: Exposicio Innecessaria de Ports
- Vulnerabilitat 4: Versions Obsoletes
- Vulnerabilitat 5: Sense Limits de Recursos
- Vulnerabilitat 6: Capabilities Innecessaries
- Vulnerabilitat 8: Comunicacio No Xifrada
- Vulnerabilitat 9: Configuracio de Xarxa Insegura
- Servei 2: Nginx Misconfiguracio
- Servei 4: SSH Configuracio Insegura

---

## Eines Utilitzades

| Eina | Funcio |
|---|---|
| Trivy | Escaneig de vulnerabilitats en imatges Docker |
| nmap | Descobriment de ports i versions de serveis |
| Hydra | Proves de força bruta (SSH, FTP) |
| tcpdump | Captura i analisi de trafic de xarxa |
| Metasploit | Explotacio de CVEs (vsftpd backdoor) |
| docker inspect | Inspeccio de configuracio de contenidors |
| capsh | Verificacio de capabilities actives |
| docker stats | Monitoritzacio de consum de recursos |
| curl | Proves de vulnerabilitats web (Apache, Nginx) |

---

## References Generals

- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [NVD - National Vulnerability Database](https://nvd.nist.gov/)
- [Trivy - Vulnerability Scanner](https://github.com/aquasecurity/trivy)

---

**Ultima actualitzacio:** Marc 2026
**Versio:** 2.0.0
