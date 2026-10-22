FROM php:8.3.36-fpm-alpine3.23

LABEL description="Simple forum software for building great communities" \
      maintainer="Magicalex <magicalex@mondedie.fr>, Hardware <hardware@mondedie.fr>"

ARG VERSION=dev-dev

ENV GID=991 \
    UID=991 \
    UPLOAD_MAX_SIZE=50M \
    PHP_MEMORY_LIMIT=128M \
    OPCACHE_MEMORY_LIMIT=128 \
    DB_HOST=mariadb \
    DB_USER=flarum \
    DB_NAME=flarum \
    DB_PORT=3306 \
    FLARUM_TITLE=Docker-Flarum \
    DEBUG=false \
    LOG_TO_STDOUT=false \
    GITHUB_TOKEN_AUTH=false \
    FLARUM_PORT=8888

RUN apk add --no-progress --no-cache \
    curl \
    git \
    libcap \
    nginx \
    su-exec \
    s6 
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
# Use the upstream APCu release source to avoid PECL REST metadata failures.
RUN install-php-extensions \
      exif gd gmp \
      intl opcache krakjoe/apcu@v5.1.28 \
      pdo_mysql zip 
      
RUN cd /tmp \
  && curl --progress-bar http://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
  && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
  && sed -i 's/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/' "$PHP_INI_DIR/php.ini" \
  && chmod +x /usr/local/bin/composer \
  && mkdir -p /run/php /flarum/app \
  && rm -rf /tmp/*

# Override the skeleton's outdated pins before resolving dependencies.
# Flarum 1.x requires Flysystem 1.x, which has no fix for GHSA-cxf4-7mrp-vvpr.
# Keep all other advisory blocking enabled: https://docs.flarum.org/update/
RUN COMPOSER_CACHE_DIR="/tmp" composer create-project --no-install karuboniru/flarum:$VERSION /flarum/app \
  && composer --working-dir=/flarum/app remove --no-update kyrne/websocket \
  && composer --working-dir=/flarum/app require --no-update flarum/core:1.8.20 \
  && composer --working-dir=/flarum/app config --json audit.ignore '{"GHSA-cxf4-7mrp-vvpr":"Flarum 1.x requires Flysystem 1.x, which has no patched release"}' \
  && COMPOSER_CACHE_DIR="/tmp" composer --working-dir=/flarum/app update --no-interaction \
  && composer clear-cache \
  && rm -rf /flarum/.composer /tmp/* \
  && setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/nginx

COPY rootfs /
RUN cp -a /etc/php8/conf.d /usr/local/etc/php/ && \
    cp -a /etc/php8/php-fpm.d /usr/local/etc/ && \
    rm -rf /etc/php8/conf.d /etc/php8/php-fpm.d && \
    ln -s /usr/local/etc/php/conf.d /etc/php8 && \
    ln -s /usr/local/etc/php-fpm.d /etc/php8 && \
    rm /usr/local/etc/php-fpm.d/zz-docker.conf

RUN chmod +x /usr/local/bin/* /etc/s6.d/*/run /etc/s6.d/.s6-svscan/*
VOLUME /etc/nginx/flarum /flarum/app/extensions /flarum/app/public/assets /flarum/app/storage/logs
CMD ["/usr/local/bin/startup"]
