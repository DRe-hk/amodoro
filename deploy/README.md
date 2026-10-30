# Guía de Despliegue de Amodoro en Azure VPS (Ubuntu/Debian)

Esta guía describe el despliegue de **Amodoro** en una máquina virtual de Azure con Ubuntu/Debian, utilizando el bundle standalone de Next.js, Caddy como proxy inverso con HTTPS automático, y el empaquetado para Android (TWA/PWA) mediante `@bubblewrap/cli`.

---

## 1. Configurar el Azure Network Security Group (NSG)

Para permitir el tráfico web y la emisión automática de certificados SSL/TLS con Let's Encrypt:

1. Ve a tu máquina virtual en el **Azure Portal** y accede a **Networking** (Redes) > **Network Security Group** (Grupo de seguridad de red).
2. Agrega las siguientes reglas de entrada (**Inbound Security Rules**):
   - **HTTP**: Puerto destino `80`, Protocolo `TCP`, Acción `Allow`, Prioridad `300`.
   - **HTTPS**: Puerto destino `443`, Protocolo `TCP`, Acción `Allow`, Prioridad `310`.
   - **SSH**: Puerto destino `22` (restringido idealmente a tu dirección IP).
3. Asegúrate de asociar una **IP pública estática** (o DNS name label) y configura el registro DNS (tipo `A` o `CNAME`) de tu dominio (ej. `amodoro.tudominio.com`) apuntando a dicha IP pública.

---

## 2. Preparar el VPS (Ubuntu/Debian)

Conéctate por SSH al VPS e instala las dependencias base (Node.js 22 LTS, SQLite3, Caddy y utilidades):

```bash
# Actualizar repositorios
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl debian-keyring debian-archive-keyring apt-transport-https sqlite3 rsync

# Instalar Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy

# Instalar Node.js 22 LTS
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

Crea el usuario del sistema `amodoro` y las carpetas con permisos aislados:

```bash
sudo useradd --system --create-home --home-dir /opt/amodoro --shell /usr/sbin/nologin amodoro
sudo mkdir -p /opt/amodoro /var/lib/amodoro/uploads /etc/amodoro /var/log/caddy
sudo chown -R amodoro:amodoro /var/lib/amodoro /opt/amodoro /etc/amodoro
sudo chmod 700 /var/lib/amodoro
sudo chmod 750 /etc/amodoro
```

---

## 3. Configuración y Servicio Systemd

Crea el archivo de variables de entorno de producción en `/etc/amodoro/env`:

```bash
sudo tee /etc/amodoro/env > /dev/null << 'EOF'
PORT=3000
HOSTNAME=127.0.0.1
NODE_ENV=production
DB_PATH=/var/lib/amodoro/amodoro.db
UPLOADS_PATH=/var/lib/amodoro/uploads
ANDROID_PACKAGE_NAME=com.amodoro.app
# Añadir la huella digital tras crear el keystore con bubblewrap:
ANDROID_SHA256_FINGERPRINT=
EOF

sudo chmod 600 /etc/amodoro/env
sudo chown amodoro:amodoro /etc/amodoro/env
```

Instala y activa el servicio systemd:

```bash
sudo cp deploy/amodoro.service /etc/systemd/system/amodoro.service
sudo systemctl daemon-reload
sudo systemctl enable amodoro
```

---

## 4. Despliegue de la Aplicación

En tu máquina local, compila la aplicación standalone:

```bash
npm run build
```

Sincroniza los archivos compilados hacia `/opt/amodoro` en el VPS:

```bash
# Sincronizar el servidor standalone y dependencias empaquetadas
rsync -avz --delete .next/standalone/ amodoro@TU_DOMINIO:/opt/amodoro/

# Sincronizar archivos estáticos y carpeta public
rsync -avz .next/static/ amodoro@TU_DOMINIO:/opt/amodoro/.next/static/
rsync -avz public/ amodoro@TU_DOMINIO:/opt/amodoro/public/
```

En el VPS, asegura la propiedad de los archivos y levanta el servicio:

```bash
sudo chown -R amodoro:amodoro /opt/amodoro
sudo systemctl restart amodoro
sudo systemctl status amodoro
```

---

## 5. Configurar Caddy (Reverse Proxy & TLS Automático)

Edita `deploy/Caddyfile` cambiando `amodoro.tudominio.com` por tu dominio público:

```bash
sudo cp deploy/Caddyfile /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Caddy se comunicará automáticamente con Let's Encrypt o ZeroSSL mediante los puertos 80 y 443 para obtener un certificado SSL válido. Las peticiones a `https://amodoro.tudominio.com` se redirigirán internamente a `127.0.0.1:3000` con un límite de cuerpo de petición de 55 MB.

---

## 6. Generación de Códigos de Invitación (`npm run user:invite`)

Amodoro es un espacio exclusivo y privado para dos. Para vincular a tu pareja o autorizar un nuevo dispositivo, genera un código de invitación desde la línea de comandos en el servidor:

```bash
cd /opt/amodoro
sudo -u amodoro DB_PATH=/var/lib/amodoro/amodoro.db npm run user:invite
```

El script imprimirá en pantalla el código de un solo uso generado y el enlace de registro para compartir con tu pareja.

---

## 7. Construir el APK de Android con `@bubblewrap/cli` (TWA)

Bubblewrap empaqueta tu PWA en una aplicación Android nativa mediante Trusted Web Activities (TWA), eliminando la barra del navegador gracias a la verificación de Digital Asset Links.

### 7.1. Instalación de Bubblewrap
En tu máquina local con Node.js y JDK 17 o 21 instalado:

```bash
npm install -g @bubblewrap/cli
```

### 7.2. Inicializar el proyecto TWA
Ejecuta la inicialización apuntando al manifest público de tu servidor:

```bash
bubblewrap init --manifest="https://amodoro.tudominio.com/manifest.webmanifest"
```

El asistente detectará el nombre de la app, colores (`#FCF9F5` y `#F2B8B5`), y te guiará para:
- Confirmar el Application ID: `com.amodoro.app`
- Crear el keystore para firmar el APK (`android.keystore`).

### 7.3. Obtener y configurar la huella digital SHA-256
Obtén la huella SHA-256 del certificado con `keytool`:

```bash
keytool -list -v -keystore ./android.keystore -alias android
```

Copia el valor del fingerprint (formato `XX:XX:XX:...`).

En el VPS, añade dicho valor en `/etc/amodoro/env`:
```ini
ANDROID_SHA256_FINGERPRINT="14:6D:E9:..."
```

Reinicia el servicio para aplicar los cambios:
```bash
sudo systemctl restart amodoro
```

Verifica que el endpoint responda correctamente con tu huella digital:
```bash
curl -s https://amodoro.tudominio.com/.well-known/assetlinks.json
```

### 7.4. Compilar el APK final
En tu máquina local, compila el APK firmado:

```bash
bubblewrap build
```

Obtendrás el archivo `app-release-signed.apk`. Puedes instalarlo directamente en tu dispositivo Android vía ADB o descargándolo al móvil:

```bash
adb install app-release-signed.apk
```

Al abrir la aplicación, Android comprobará la relación mediante `/.well-known/assetlinks.json` y la ejecutará en modo nativo a pantalla completa sin elementos del navegador.
