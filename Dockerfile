# ============================================================
# Stage 1: Frontend build
# ============================================================
FROM node:22-bookworm-slim AS frontend

WORKDIR /var/www/html

# Copy package manifests first for better layer caching
COPY package.json package-lock.json ./

# Install exact locked dependencies
RUN npm ci

# Copy frontend/build configuration and source
COPY vite.config.js ./
COPY resources ./resources
COPY public ./public
COPY .env.example ./.env.example

# Build production frontend assets
RUN npm run build


# ============================================================
# Stage 2: Composer dependencies
# ============================================================
FROM php:8.4-cli-alpine AS vendor

WORKDIR /var/www/html

RUN apk add --no-cache \
    icu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    libxml2-dev \
    $PHPIZE_DEPS

RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg

RUN docker-php-ext-install \
    bcmath \
    exif \
    gd \
    intl \
    mbstring \
    pcntl \
    pdo_mysql \
    xml \
    zip

RUN pecl install redis \
    && docker-php-ext-enable redis

RUN apk del $PHPIZE_DEPS

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./

RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts

# ============================================================
# Stage 3: Production PHP-FPM application
# ============================================================
FROM php:8.4-fpm-alpine

WORKDIR /var/www/html

# ============================================================
# System dependencies
# ============================================================
RUN apk add --no-cache \
    bash \
    curl \
    icu-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    oniguruma-dev \
    libxml2-dev \
    mysql-client \
    $PHPIZE_DEPS


# ============================================================
# GD configuration
# ============================================================
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg


# ============================================================
# PHP extensions
# ============================================================
RUN docker-php-ext-install \
    bcmath \
    exif \
    gd \
    intl \
    mbstring \
    opcache \
    pcntl \
    pdo_mysql \
    xml \
    zip


# ============================================================
# Redis PHP extension
# ============================================================
RUN pecl install redis \
    && docker-php-ext-enable redis


# ============================================================
# Remove build dependencies
# ============================================================
RUN apk del $PHPIZE_DEPS


# ============================================================
# Copy Composer dependencies
# ============================================================
COPY --from=vendor /var/www/html/vendor ./vendor


# ============================================================
# Copy Laravel application
# ============================================================
COPY . .


# Never use Vite dev server in the production image
RUN rm -f public/hot

COPY --from=frontend /var/www/html/public/build ./public/build


# ============================================================
# Copy production frontend build
# ============================================================
COPY --from=frontend /var/www/html/public/build ./public/build


# ============================================================
# PHP configuration
# ============================================================
COPY docker/php/php.ini \
    /usr/local/etc/php/conf.d/99-production.ini


# ============================================================
# PHP-FPM configuration
# ============================================================
COPY docker/php/www.conf \
    /usr/local/etc/php-fpm.d/www.conf


# ============================================================
# Laravel runtime directories
# ============================================================
RUN mkdir -p \
        storage/framework/cache \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        bootstrap/cache \
    && chown -R www-data:www-data \
        storage \
        bootstrap/cache \
    && chmod -R 775 \
        storage \
        bootstrap/cache

# ============================================================
# PHP-FPM health check
# ============================================================
HEALTHCHECK \
    --interval=30s \
    --timeout=10s \
    --start-period=20s \
    --retries=3 \
    CMD php-fpm -t


# ============================================================
# PHP-FPM
# ============================================================
EXPOSE 9000

CMD ["php-fpm", "-F"]