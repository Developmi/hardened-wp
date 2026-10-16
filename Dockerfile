# ==========================================
# Stage 1: PHP Dependencies (Composer)
# ==========================================
FROM composer:2.10@sha256:af98f42dfff7c68ba8d53c2164fd9fde1087b7d449514baa38c418b1f6bc4bac AS php-builder
WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --classmap-authoritative \
    --no-scripts

COPY . .
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev

# ==========================================
# Stage 2: Production Image (FrankenPHP)
# ==========================================
FROM dunglas/frankenphp:1-php8.3-alpine@sha256:5babd75547a7dbbc424fa5e2d3566d5bd46173ed0fe09f17fe7f9e9001b2b936

# PHP extensions required by WordPress + Bedrock + Acorn
RUN install-php-extensions \
    mysqli \
    pdo_mysql \
    gd \
    intl \
    zip \
    opcache \
    exif

# WP-CLI from official WordPress CLI image
COPY --from=wordpress:cli-php8.3@sha256:36243da432a0f0a3b56dc3240ecee9b159108d71305e7c064d987a20a465bfde /usr/local/bin/wp /usr/local/bin/wp

WORKDIR /app
COPY --from=php-builder /app /app

ENV SERVER_NAME=":8080"

# Copy Caddy configuration (defaults to Caddyfile.example if Caddyfile is absent)
COPY Caddyfile* /etc/frankenphp/
RUN test -f /etc/frankenphp/Caddyfile || cp /etc/frankenphp/Caddyfile.example /etc/frankenphp/Caddyfile

# PHP runtime configuration (.ini overrides)
COPY config/php/ /usr/local/etc/php/conf.d/

# Writable directories and runtime permissions
RUN mkdir -p /app/web/app/uploads /app/web/app/cache /data/caddy /config/caddy \
 && chown -R www-data:www-data /app/web/app/uploads /app/web/app/cache /data /config \
 && chmod 775 /app/web/app/uploads /app/web/app/cache /data /config

# Health check - verify FrankenPHP is serving WordPress
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1

USER 82:82
EXPOSE 8080
