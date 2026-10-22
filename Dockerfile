# ==========================================
# Stage 1: PHP Dependencies (Composer)
# ==========================================
FROM composer:2.10@sha256:b6dcd72ca98fa19d0e5b8476de179859704891fad06dd9e0b96833d4c430a5fc AS php-builder
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
FROM dunglas/frankenphp:1-php8.3-alpine@sha256:d945d1efb0400769ac1a2796b2af29899d8ecc1558df46cff45f9cb864963918

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
COPY --from=wordpress:cli-php8.3@sha256:661db880e953da051abcac6c0a769767b995a82cd52101c003ca7438dd427d7d /usr/local/bin/wp /usr/local/bin/wp

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
