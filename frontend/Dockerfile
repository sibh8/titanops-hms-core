# ─── Stage 1: Build ──────────────────────────────────────────────────────────
FROM node:20.18-alpine AS build

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --prefer-offline --legacy-peer-deps

COPY . .
RUN npm run build

# ─── Stage 2: Serve ──────────────────────────────────────────────────────────
FROM nginx:1.25.5-alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/medicore.conf

# Copy Vite build output
COPY --from=build /app/dist /usr/share/nginx/html

# Grant capability to bind to privileged port 80 as non-root and adjust runtime paths
RUN apk add --no-cache libcap \
    && setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx \
    && sed -i 's|^user |#user |' /etc/nginx/nginx.conf \
    && sed -i 's|/var/run/nginx.pid|/tmp/nginx.pid|' /etc/nginx/nginx.conf \
    && chown -R 101:101 /var/cache/nginx /var/log/nginx /etc/nginx /tmp /usr/share/nginx/html \
    && chmod -R 755 /var/cache/nginx /var/log/nginx /etc/nginx /tmp /usr/share/nginx/html

EXPOSE 80

# Switch to non-root nginx user (UID 101, GID 101)
USER 101:101

HEALTHCHECK --interval=15s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
