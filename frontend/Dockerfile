
# Etape 1 : Build Angular
FROM node:24-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Recuperer le dossier de compilation Angular
RUN set -eux; \
    INDEX_FILE="$(find dist -type f -name index.html -print -quit)"; \
    test -n "$INDEX_FILE"; \
    APP_DIR="${INDEX_FILE%/index.html}"; \
    mkdir -p /output; \
    cp -a "$APP_DIR"/. /output/

# Etape 2 : Serveur Nginx
FROM nginx:alpine

COPY --from=build /output/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

