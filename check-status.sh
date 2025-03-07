#!/bin/bash

# Script para verificar el estado de n8n, Docker, certificados SSL y logs
# Autor: AlpacaPurpura
# Fecha: 2025-03-07

# Colores para mensajes
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

print_title() {
  echo -e "\n${BLUE}$1${NC}"
  echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
}

# Verificar si el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  print_error "Este script debe ejecutarse como root (usar sudo)."
  exit 1
fi

# Verificar si Docker está en ejecución
print_title "VERIFICANDO DOCKER"
if systemctl is-active --quiet docker; then
  print_success "El servicio Docker está en ejecución."
else
  print_error "El servicio Docker no está en ejecución."
  print_message "Intentando iniciar Docker..."
  systemctl start docker
  if systemctl is-active --quiet docker; then
    print_success "El servicio Docker se ha iniciado correctamente."
  else
    print_error "No se pudo iniciar Docker. Por favor, verifica la instalación."
    exit 1
  fi
fi

# Verificar estado de los contenedores
print_title "ESTADO DE LOS CONTENEDORES"
docker compose ps

# Verificar si n8n está en ejecución
print_title "VERIFICANDO N8N"
if docker compose ps | grep -q "n8n.*Up"; then
  print_success "El servicio n8n está en ejecución."
else
  print_error "El servicio n8n no está en ejecución."
  print_message "Verificando los logs de n8n..."
  docker compose logs --tail=50 n8n
fi

# Verificar si Nginx está en ejecución
print_title "VERIFICANDO NGINX"
if docker compose ps | grep -q "nginx-proxy.*Up"; then
  print_success "El servicio nginx-proxy está en ejecución."
else
  print_error "El servicio nginx-proxy no está en ejecución."
  print_message "Verificando los logs de nginx-proxy..."
  docker compose logs --tail=50 nginx-proxy
fi

# Verificar certificados SSL
print_title "VERIFICANDO CERTIFICADOS SSL"
if docker compose ps | grep -q "certbot.*Up"; then
  print_success "El servicio certbot está en ejecución."
else
  print_error "El servicio certbot no está en ejecución."
  print_message "Verificando los logs de certbot..."
  docker compose logs --tail=50 certbot
fi

# Verificar archivos de certificados
DOMAIN=$(grep VIRTUAL_HOST .env | cut -d= -f2)
if [ -z "$DOMAIN" ]; then
  print_error "No se pudo obtener el dominio del archivo .env"
else
  print_message "Verificando certificados para dominio: $DOMAIN"
  if docker compose exec nginx-proxy ls -la /etc/nginx/certs/$DOMAIN.crt 2>/dev/null; then
    print_success "Certificado SSL encontrado para $DOMAIN"
    # Verificar fecha de vencimiento del certificado
    EXPIRY=$(docker compose exec nginx-proxy openssl x509 -in /etc/nginx/certs/$DOMAIN.crt -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -n "$EXPIRY" ]; then
      print_message "El certificado vence: $EXPIRY"
    fi
  else
    print_error "No se encontró certificado SSL para $DOMAIN"
    print_message "Puede tardar unos minutos en generarse el certificado SSL."
    print_message "Verificando si hay solicitudes pendientes..."
    docker compose logs --tail=20 certbot
  fi
fi

# Verificar puertos
print_title "VERIFICANDO PUERTOS"
print_message "Puerto 80 (HTTP):"
if command -v lsof &> /dev/null; then
  lsof -i :80 
else
  netstat -tulpn | grep ":80 "
fi

print_message "Puerto 443 (HTTPS):"
if command -v lsof &> /dev/null; then
  lsof -i :443
else
  netstat -tulpn | grep ":443 "
fi

# Verificar logs
print_title "VERIFICANDO LOGS"
if [ -d "n8n/logs" ]; then
  print_message "Directorio de logs encontrado:"
  ls -la n8n/logs/
  print_message "Últimas 5 líneas del log principal:"
  if [ -f "n8n/logs/n8n.log" ]; then
    tail -n5 n8n/logs/n8n.log
  else
    print_error "Archivo de log principal no encontrado."
  fi
else
  print_error "Directorio de logs no encontrado."
fi

# Verificar conectividad externa
print_title "VERIFICANDO CONECTIVIDAD EXTERNA"
print_message "Verificando DNS para $DOMAIN:"
if command -v dig &> /dev/null; then
  dig +short $DOMAIN
elif command -v nslookup &> /dev/null; then
  nslookup $DOMAIN
else
  print_error "No se encuentran herramientas para verificar DNS (dig o nslookup)."
fi

# Verificar si se puede acceder a la URL
print_message "Verificando acceso HTTP a $DOMAIN:"
if command -v curl &> /dev/null; then
  curl -I -L -s -o /dev/null -w "%{http_code}" http://$DOMAIN
  print_message "Verificando acceso HTTPS a $DOMAIN:"
  curl -I -L -s -o /dev/null -w "%{http_code}" https://$DOMAIN
else
  print_error "No se encuentra curl para verificar la accesibilidad web."
fi

# Resumen de uso de disco
print_title "USO DE DISCO"
df -h | grep -e Filesystem -e /dev/

# Información del sistema
print_title "INFORMACIÓN DEL SISTEMA"
print_message "Memoria:"
free -h

print_message "CPU:"
top -bn1 | head -5

print_message "Hora del sistema:"
date

# Mostrar instrucciones adicionales
print_title "INSTRUCCIONES ADICIONALES"
echo "Para reiniciar todos los servicios:"
echo "sudo docker compose --profile cpu down && sudo docker compose --profile cpu up -d"
echo ""
echo "Para ver logs en tiempo real:"
echo "sudo docker compose logs -f"
echo ""
echo "Para acceder a la interfaz de n8n:"
echo "https://$DOMAIN"

exit 0 