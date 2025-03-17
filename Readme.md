# n8n Self-Hosted con Nginx y SSL

Este proyecto configura una instalación completa de n8n con Nginx como proxy inverso, certificados SSL automáticos mediante Let's Encrypt, y almacenamiento de logs, basado en el [n8n Self-hosted AI Starter Kit](https://github.com/n8n-io/self-hosted-ai-starter-kit).

## Componentes

- **n8n**: Plataforma de automatización de flujos de trabajo
- **Nginx**: Servidor web que actúa como proxy inverso
- **Certbot**: Herramienta para obtener certificados SSL automáticamente de Let's Encrypt
- **PostgreSQL**: Base de datos para n8n
- **Ollama**: Motor de IA para n8n (parte del AI Starter Kit)
- **Qdrant**: Vector database para n8n (parte del AI Starter Kit)

## Prerrequisitos

- Una máquina virtual con Debian en Google Cloud
- Docker instalado (versión 20.10.0 o superior) con plugin de Compose
- Un nombre de dominio apuntando a la IP de tu servidor (en este caso, n8n-dev.alpacapurpura.lat)
- Puertos 80 y 443 abiertos en el firewall de Google Cloud

### Verificación de Docker y su plugin de Compose

Para verificar que Docker y el plugin de Compose están instalados correctamente:

```bash
# Verificar versión de Docker
docker --version

# Verificar que el plugin de Compose está disponible
docker compose version
```

Si no tienes Docker con el plugin de Compose, puedes instalarlo en
https://docs.docker.com/compose/install/linux/

```

## Estructura de directorios

```
.
├── docker-compose.yml     # Configuración de Docker Compose
├── .env                   # Variables de entorno (creado a partir de .env.example)
├── .env.example           # Plantilla para el archivo .env
├── .gitignore             # Archivos a excluir del control de versiones
├── setup-linux.sh         # Script de configuración para Linux
├── check-status.sh        # Script para verificar el estado de los servicios
├── n8n/                   # Directorio para datos de n8n (creado automáticamente)
│   ├── backup/            # Respaldos de n8n
│   └── logs/              # Logs de n8n
└── shared/                # Directorio compartido para archivos
```

## Guía de instalación paso a paso en Google Cloud

### 1. Configuración de la máquina virtual

1. Accede a la consola de Google Cloud y crea una instancia de VM con Debian.
2. Asegúrate de que la VM tenga al menos 2GB de RAM y 2 CPUs.
3. Abre los puertos 80 y 443 en el firewall de Google Cloud:
   ```bash
   # Desde la consola de Google Cloud o con gcloud
   gcloud compute firewall-rules create allow-http \
     --allow tcp:80 \
     --target-tags=http-server \
     --description="Allow HTTP traffic"
   
   gcloud compute firewall-rules create allow-https \
     --allow tcp:443 \
     --target-tags=https-server \
     --description="Allow HTTPS traffic"
   ```
4. Asigna estos tags a tu VM si usaste el comando anterior.

### 2. Configuración del dominio

1. Configura un registro A en tu proveedor de DNS para que `n8n-dev.alpacapurpura.lat` apunte a la IP externa de tu VM.
2. Verifica que el DNS se haya propagado:
   ```bash
   nslookup tu-dominio.com
   ```

### 3. Preparación del servidor

1. Conéctate a tu VM mediante SSH:
   ```bash
   ssh tu_usuario@IP_DE_TU_VM
   ```

2. Actualiza el sistema:
   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```

3. Instala herramientas básicas:
   ```bash
   sudo apt install -y git curl wget nano
   ```

4. Asegúrate de que Docker y el plugin de Compose estén instalados:
   ```bash
   docker --version
   docker compose version
   ```

### 4. Clonar el repositorio

1. Clona este repositorio:
   ```bash
   git clone https://github.com/alpacapurpura/n8n-docker-compose-nginx-certbot.git
   cd n8n-docker-compose-nginx-certbot
   ```

### 5. Configuración de variables de entorno

1. Crea tu archivo `.env` a partir del ejemplo:
   ```bash
   cp .env.example .env
   nano .env
   ```
   
2. Actualiza las siguientes variables:
   - `POSTGRES_PASSWORD`: Una contraseña segura para PostgreSQL
   - `N8N_ENCRYPTION_KEY`: Una clave de encriptación larga y segura (mínimo 32 caracteres)
   - `N8N_USER_MANAGEMENT_JWT_SECRET`: Un secreto JWT largo y seguro (mínimo 32 caracteres)
   - `VIRTUAL_HOST`: Tu dominio (tudominio.com)
   - `N8N_HOST`: URL completa (https://tudominio.com)
   - `WEBHOOK_URL`: URL completa (https://tudominio.com/)
   - `CERTBOT_EMAIL`: Tu dirección de correo electrónico para Let's Encrypt

3. Guarda el archivo (Ctrl+O, luego Enter, luego Ctrl+X).

### 6. Ejecución del script de instalación

1. Haz el script ejecutable:
   ```bash
   chmod +x setup-linux.sh
   chmod +x check-status.sh
   ```

2. Ejecuta el script de instalación:
   ```bash
   sudo ./setup-linux.sh
   ```

3. El script realizará las siguientes acciones:
   - Verificará si Docker está instalado
   - Creará la estructura de directorios
   - Configurará los permisos
   - Verificará que los puertos 80 y 443 estén disponibles
   - Iniciará los servicios con Docker Compose

4. Si el script se detiene porque necesitas editar el archivo `.env`, hazlo y vuelve a ejecutar el script después.

### 7. Verificación de la instalación

1. El script verificará si todos los servicios se inician correctamente.
2. Puedes verificar manualmente el estado de los servicios usando el script de diagnóstico:
   ```bash
   sudo ./check-status.sh
   ```
   
   Este script verificará:
   - El estado de Docker
   - El estado de todos los contenedores
   - La configuración de los certificados SSL
   - Los puertos abiertos
   - Los logs de n8n
   - La conectividad DNS y web
   - Información sobre el sistema

3. También puedes verificar los contenedores manualmente:
   ```bash
   docker compose ps
   ```

4. Accede a n8n a través de tu dominio:
   ```
   https://tu-dominio.com
   ```

5. Nota: La emisión del certificado SSL puede tardar unos minutos. Puedes verificar el estado con:
   ```bash
   sudo ./check-status.sh
   ```

## Solución de problemas comunes con Docker Compose

### Error: "docker compose" comando no encontrado

Si el comando `docker compose` no está disponible, verifica:

1. La versión de Docker que estás usando (debe ser 20.10.0 o superior):
   ```bash
   docker --version
   ```

2. Si tienes el plugin de Compose instalado:
   ```bash
   docker-compose --version # Versión antigua
   docker compose version   # Nueva versión del plugin
   ```

3. Si necesitas instalar el plugin:
   ```bash
   sudo apt update
   sudo apt install -y docker-compose-plugin
   ```

### Error: "The Compose file './docker-compose.yml' is invalid"

Este error puede ocurrir cuando hay un problema con la sintaxis del archivo docker-compose.yml o cuando la versión de Docker Compose no es compatible. Soluciones:

1. Verifica que estás usando una versión actualizada de Docker Compose:
   ```bash
   docker compose version
   ```

2. Si el problema persiste, puedes validar tu archivo docker-compose.yml:
   ```bash
   docker compose config
   ```

## Seguridad y buenas prácticas

Este proyecto incluye un archivo `.gitignore` configurado para evitar que información sensible o archivos innecesarios sean incluidos en el repositorio:

- **No se versiona el archivo `.env`**: Contiene contraseñas, claves y otra información sensible.
- **Se proporciona `.env.example`**: Sirve como plantilla para crear tu propio archivo `.env`.
- **Directorios excluidos**: Los directorios de logs, backups y datos compartidos se excluyen del control de versiones.
- **Certificados SSL**: Los archivos de certificado SSL también se excluyen.

### Recomendaciones de seguridad

1. **Nunca** subas el archivo `.env` a repositorios remotos.
2. **Cambia las contraseñas por defecto** en el archivo `.env`.
3. Usa **claves de encriptación y JWT largas y aleatorias** (mínimo 32 caracteres).
4. Mantén las **credenciales en un lugar seguro** (gestor de contraseñas).
5. Realiza **copias de seguridad periódicas** del directorio de backups.
6. Configura **reglas de firewall restrictivas** en Google Cloud.
7. Monitoriza los **logs regularmente** para detectar actividades sospechosas.

## Gestión y mantenimiento

### Registros (Logs)

Los registros de n8n se almacenan en el directorio `n8n/logs` y se pueden consultar de varias formas:

```bash
# Ver todos los logs de Docker
docker compose logs -f

# Ver solo logs de n8n
docker compose logs -f n8n

# Ver logs de certbot (útil para problemas con SSL)
docker compose logs -f certbot

# Ver logs desde archivos
ls -la n8n/logs/
cat n8n/logs/n8n.log
```

### Configuración de los logs

La configuración de logs se realiza mediante variables de entorno en el archivo `.env`:

- `N8N_LOG_LEVEL`: Nivel de detalle de los logs (info, debug, warn, error)
- `N8N_LOG_OUTPUT`: Destino de los logs (file)
- `N8N_LOG_FILE_LOCATION`: Ruta del archivo de logs
- `N8N_LOG_FILE_MAX_SIZE`: Tamaño máximo del archivo de logs (en bytes)
- `N8N_LOG_FILE_MAX_FILES`: Número máximo de archivos de logs a mantener

### Respaldos

Los respaldos se guardan en el directorio `n8n/backup`. Puedes:

1. Crear respaldos manualmente desde la interfaz de n8n:
   - Ve a Ajustes > Respaldo
   - Haz clic en "Descargar copia de seguridad"

2. Respaldar el directorio completo:
   ```bash
   sudo tar -czvf n8n-backup-$(date +%Y%m%d).tar.gz n8n/backup/
   ```

3. Transferir respaldos a otro servidor:
   ```bash
   scp n8n-backup-*.tar.gz usuario@servidor-destino:/ruta/destino/
   ```

### Reinicio de servicios

Si necesitas reiniciar los servicios:

```bash
# Reiniciar todos los servicios
docker compose --profile cpu down
docker compose --profile cpu up -d

# Reiniciar solo n8n
docker compose restart n8n
```

### Monitoreo del sistema

Para verificar el estado completo del sistema en cualquier momento:

```bash
sudo ./check-status.sh
```

Este comando te dará un informe completo del estado de todos los componentes, certificados SSL, logs y estado del sistema.

## Solución de problemas

### Certificado SSL no se emite

- Verifica que el dominio `n8n-dev.alpacapurpura.lat` apunte correctamente a la IP de tu servidor:
  ```bash
  nslookup n8n-dev.alpacapurpura.lat
  ```
- Asegúrate de que los puertos 80 y 443 estén abiertos en el firewall de Google Cloud.
- Verifica los logs de Certbot: 
  ```bash
  docker compose logs certbot
  ```
- Intenta reiniciar el servicio de Certbot:
  ```bash
  docker compose restart certbot
  ```

### n8n no se inicia

- Revisa los logs: 
  ```bash
  docker compose logs n8n
  ```
- Verifica la configuración en el archivo `.env`
- Asegúrate de que todos los directorios tengan los permisos correctos:
  ```bash
  sudo chmod -R 777 n8n shared
  ```

### Problemas con Docker

- Reinicia el servicio de Docker:
  ```bash
  sudo systemctl restart docker
  ```
- Verifica el estado de Docker:
  ```bash
  sudo systemctl status docker
  ```

## Actualización

Para actualizar a una nueva versión de n8n:

1. Haz una copia de seguridad:
   ```bash
   docker compose exec n8n n8n export:workflow --all --output=/backup/workflows-$(date +%Y%m%d).json
   ```

2. Detén los servicios:
   ```bash
   docker compose --profile cpu down
   ```

3. Actualiza el código del repositorio:
   ```bash
   git pull
   ```

4. Inicia de nuevo:
   ```bash
   docker compose --profile cpu up -d
   ```

## Referencias

- [Documentación de n8n](https://docs.n8n.io/)
- [Self-hosted AI Starter Kit de n8n](https://github.com/n8n-io/self-hosted-ai-starter-kit)
- [Configuración de logs en n8n](https://docs.n8n.io/hosting/configuration/environment-variables/logs/)
- [Documentación de Docker Compose](https://docs.docker.com/compose/)
- [Documentación de Google Cloud Compute Engine](https://cloud.google.com/compute/docs)

## Para casos extremos: Forzar cierre y eliminación de contenedores e imágenes (Del compose)
1. Ubicarte en la carpeta donde se encuentra el archivo `docker-compose.yml`
2. Ejecutar el siguiente comando:
```bash
# Detener todos los contenedores
docker-compose down --rmi all --remove-orphans && \
docker network prune --force && \
docker image prune --all --force

# Reiniciar el servicio Docker (solo si persisten errores)
sudo systemctl restart docker
```

## Para casos extremos: Forzar cierre y eliminación de contenedores e imágenes (Afecta a todo el servidor)
1. Ubicarte en la carpeta donde se encuentra el archivo `docker-compose.yml`
2. Ejecutar el siguiente comando:
```bash
# Detener todos los contenedores
docker stop $(docker ps -aq)

# Eliminar contenedores persistentes (si el anterior falla)
docker rm -f $(docker ps -aq) 2>/dev/null || true

# Quitar todas las redes no usadas
docker network prune -f

# Eliminar todas las imágenes
docker rmi -f $(docker images -q) 2>/dev/null || true

# Reiniciar el servicio Docker (solo si persisten errores)
sudo systemctl restart docker
```

3. Verificar que no queden contenedores o imágenes
docker ps -a      # No debe mostrar contenedores
docker images     # Solo imágenes base del sistema
docker network ls # Solo redes por defecto

4. Reinstalar tu stack

## Versión nuclear para casos demasiado extremos y no recomendado: Eliminar volúmenes (Se eliminará toda la información avanzada en el servidor, por eso, trata de generar backups de manera recurrente)
NO USAR SI YA HAY DATA:
docker-compose down --rmi all --remove-orphans --volumes && \
docker system prune --all --force --volumes