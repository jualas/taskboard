# Dockerfile para servir aplicación Flutter Web
# Solo servidor web - NO incluye Flutter
# El build se hace localmente con: flutter build web --release

FROM nginx:alpine

# Copiar archivos build desde el directorio local
# Los archivos se montan como volumen en docker-compose.yml
# COPY build/web /usr/share/nginx/html

# Copiar configuración personalizada de Nginx
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Exponer puerto 80
EXPOSE 80

# Comando por defecto
CMD ["nginx", "-g", "daemon off;"]