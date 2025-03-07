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
  print_error "Docker no está instalado. ¿Deseas instalarlo ahora? (s/n)"
  read -r respuesta
  if [[ "$respuesta" =~ ^[Ss]$ ]]; then
    print_message "Instalando Docker..."
    # Actualizar repositorios
    apt-get update
    
    # Instalar paquetes necesarios
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg
    
    # Añadir clave GPG oficial de Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Configurar repositorio
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Actualizar e instalar Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Verificar instalación
    systemctl status docker --no-pager
    print_success "Docker instalado correctamente."
  else
    print_error "Docker es necesario para continuar. Instalalo e intenta nuevamente."
    exit 1
  fi
fi

# Verificar si Docker Compose está instalado
if ! command -v docker-compose &> /dev/null; then
  print_error "Docker Compose no está instalado. ¿Deseas instalarlo ahora? (s/n)"
  read -r respuesta
  if [[ "$respuesta" =~ ^[Ss]$ ]]; then
    print_message "Instalando Docker Compose..."
    
    # Instalar Docker Compose
    curl -SL https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Verificar instalación
    docker-compose --version
    print_success "Docker Compose instalado correctamente."
  else
    print_error "Docker Compose es necesario para continuar. Instalalo e intenta nuevamente."
    exit 1
  fi
fi

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

# Verificar puertos 80 y 443
print_message "Verificando si los puertos 80 y 443 están abiertos..."
if command -v netstat &> /dev/null; then
  if netstat -tulpn | grep -q ":80 "; then
    print_error "El puerto 80 está siendo utilizado por otro servicio. Debes liberarlo antes de continuar."
    netstat -tulpn | grep ":80 "
  else
    print_success "Puerto 80 disponible."
  fi
  
  if netstat -tulpn | grep -q ":443 "; then
    print_error "El puerto 443 está siendo utilizado por otro servicio. Debes liberarlo antes de continuar."
    netstat -tulpn | grep ":443 "
  else
    print_success "Puerto 443 disponible."
  fi
else
  print_message "No se puede verificar los puertos. Asegúrate de que los puertos 80 y 443 estén disponibles."
fi

# Abrir puertos en el firewall si está activo
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
  print_message "Abriendo puertos en el firewall UFW..."
  ufw allow 80/tcp
  ufw allow 443/tcp
  print_success "Puertos abiertos en UFW."
fi

# Iniciar los servicios con Docker Compose usando el perfil CPU
print_message "Iniciando servicios con Docker Compose (perfil CPU)..."
docker-compose --profile cpu down
docker-compose --profile cpu up -d

# Verificar si los servicios están en funcionamiento
print_message "Verificando estado de los servicios..."
sleep 10

if docker-compose ps | grep -q "n8n"; then
  print_success "Servicio n8n iniciado correctamente."
else
  print_error "Error al iniciar el servicio n8n. Verificando logs..."
  docker-compose logs n8n
fi

if docker-compose ps | grep -q "nginx-proxy"; then
  print_success "Servicio nginx-proxy iniciado correctamente."
else
  print_error "Error al iniciar el servicio nginx-proxy. Verificando logs..."
  docker-compose logs nginx-proxy
fi

if docker-compose ps | grep -q "certbot"; then
  print_success "Servicio certbot iniciado correctamente."
else
  print_error "Error al iniciar el servicio certbot. Verificando logs..."
  docker-compose logs certbot
fi

# Mostrar información de acceso
DOMAIN=$(grep VIRTUAL_HOST .env | cut -d= -f2)
print_message "Configuración completada. Puedes acceder a n8n en https://$DOMAIN"
print_message "Puede tardar unos minutos hasta que el certificado SSL sea emitido por Let's Encrypt."
print_message "Si tienes problemas, puedes verificar los logs con: docker-compose logs -f"

# Mostrar instrucciones para monitorear los logs
print_message "Para monitorear los logs de n8n:"
print_message "  - Logs en tiempo real: docker-compose logs -f n8n"
print_message "  - Archivos de log: ls -la n8n/logs/"

exit 0 