#!/bin/bash

# Script de configuración para n8n con Nginx y certificado SSL (para servidor Linux Debian)
# Autor: AlpacaPurpura
# Fecha: 2025-03-07

# Colores para mensajes
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Función para imprimir mensajes de estado
print_message() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar prerrequisitos
print_message "Verificando prerrequisitos..."

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null; then
  print_success "Docker está disponible."
else
  print_error "Docker no está instalado. Docker es necesario para continuar. Instalalo e intenta nuevamente."
  exit 1
fi

# Verificar Docker Compose
print_message "Verificando Docker Compose..."
if docker compose version &> /dev/null; then
  print_success "Docker Compose está disponible."
else
  print_error "Docker Compose no está disponible. Asegúrate de tener instalado Docker con compose plugin."
  exit 1
fi

# Add after Docker Compose verification
print_message "Verificando dependencias del sistema..."
# Check and install dnsutils
if ! dpkg -l | grep -q dnsutils; then
    print_message "Instalando dnsutils para herramientas DNS..."
    apt-get update
    apt-get install -y dnsutils
    print_success "dnsutils instalado correctamente"
else
    print_success "dnsutils ya está instalado"
fi

# Check and install ufw
if ! dpkg -l | grep -q ufw; then
    print_message "Instalando ufw para gestión del firewall..."
    apt-get install -y ufw
    print_success "ufw instalado correctamente"
else
    print_success "ufw ya está instalado"
fi

print_success "Dependencias del sistema verificadas"

print_success "Prerrequisitos verificados correctamente."

# Crear directorios necesarios
print_message "Creando estructura de directorios..."
mkdir -p n8n/backup shared n8n/logs

# Verificar si el archivo .env existe
if [ ! -f .env ]; then
  print_error "El archivo .env no existe. ¿Deseas crear uno a partir de .env.example? (s/n)"
  read -r respuesta
  if [[ "$respuesta" =~ ^[Ss]$ ]]; then
    if [ -f .env.example ]; then
      cp .env.example .env
      print_message "Archivo .env creado. Por favor, edítalo antes de continuar:"
      print_message "nano .env"
      print_message "Asegúrate de establecer contraseñas seguras y actualizar el dominio."
      exit 0
    else
      print_error "El archivo .env.example no existe. Por favor, crea un archivo .env manualmente."
      exit 1
    fi
  else
    print_error "El archivo .env es necesario para continuar. Créalo e intenta nuevamente."
    exit 1
  fi
fi

# Configurar permisos adecuados
print_message "Configurando permisos..."
chmod -R 777 n8n/logs
chmod -R 777 n8n/backup
chmod -R 777 shared
print_success "Permisos configurados correctamente."

# Iniciar los servicios con Docker Compose usando el perfil CPU
print_message "Iniciando servicios con Docker Compose (perfil CPU)..."
docker compose --profile cpu down
docker compose --profile cpu up -d

# Verificar si los servicios están en funcionamiento
print_message "Verificando estado de los servicios..."
sleep 10

if docker compose ps | grep -q "n8n"; then
  print_success "Servicio n8n iniciado correctamente."
else
  print_error "Error al iniciar el servicio n8n. Verificando logs..."
  docker compose logs n8n
fi

if docker compose ps | grep -q "nginx-proxy"; then
  print_success "Servicio nginx-proxy iniciado correctamente."
else
  print_error "Error al iniciar el servicio nginx-proxy. Verificando logs..."
  docker compose logs nginx-proxy
fi

if docker compose ps | grep -q "certbot"; then
  print_success "Servicio certbot iniciado correctamente."
else
  print_error "Error al iniciar el servicio certbot. Verificando logs..."
  docker compose logs certbot
fi

# Mostrar información de acceso
DOMAIN=$(grep VIRTUAL_HOST .env | cut -d= -f2)
print_message "Configuración completada. Puedes acceder a n8n en https://$DOMAIN"
print_message "Puede tardar unos minutos hasta que el certificado SSL sea emitido por Let's Encrypt."
print_message "Si tienes problemas, puedes verificar los logs con: docker compose logs -f"

# Mostrar instrucciones para monitorear los logs
print_message "Para monitorear los logs de n8n:"
print_message "  - Logs en tiempo real: docker compose logs -f n8n"
print_message "  - Archivos de log: ls -la n8n/logs/"

# Add after directory creation
print_message "Verifying Docker Compose persistence configuration..."
if ! command -v jq &> /dev/null; then
  apt-get install -y jq
fi

if docker compose config --format json | jq -e '.volumes.n8n_storage' >/dev/null 2>&1; then
  print_success "n8n data volume configured in Docker Compose"
else
  print_error "Missing n8n_storage volume in docker-compose.yml"
  exit 1
fi

# Modify permissions section to:
print_message "Configuring secure permissions..."
find n8n/logs -type d -exec chmod 755 {} \;
find n8n/logs -type f -exec chmod 644 {} \;
chown -R 1000:1000 n8n/backup shared

exit 0