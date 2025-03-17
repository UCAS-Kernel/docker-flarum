FROM php:8.3.19-fpm-alpine3.20

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
RUN install-php-extensions \
      exif gd gmp \
      intl opcache apcu \
      pdo_mysql zip 
      
RUN cd /tmp \
  && curl --progress-bar http://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
  && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
  && sed -i 's/memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT}/' "$PHP_INI_DIR/php.ini" \
  && chmod +x /usr/local/bin/composer \
  && mkdir -p /run/php /flarum/app \
  && rm -rf /tmp/*

RUN COMPOSER_CACHE_DIR="/tmp" composer create-project karuboniru/flarum:$VERSION /flarum/app \
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
