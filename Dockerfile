FROM phusion/baseimage:0.9.22
MAINTAINER Daniel Peck <d9eckb@gmail.com>

ENV PHP_INI_DIR /usr/local/etc/php
ENV PHP_EXTRA_BUILD_DEPS apache2-dev
ENV PHP_EXTRA_CONFIGURE_ARGS --with-apxs2
ENV GPG_KEYS 1A4E8B7277C42E53DBA9C7B9BCAA30EA9C0D5763
ENV PHP_VERSION 7.0.24
ENV PHP_FILENAME php-7.0.24.tar.xz
ENV PHP_SHA256 4dba7aa365193c9229f89f1975fad4c01135d29922a338ffb4a27e840d6f1c98
ENV PHP_MEMORY_LIMIT "1024M"

ENV MAGENTO_VERSION "2.2.2"
ENV MYSQL_HOST "mpshop-mariadb"
ENV MYSQL_ROOT_PASSWORD "password"
ENV MYSQL_USER "magento"
ENV MYSQL_PASSWORD "password"
ENV MYSQL_DATABASE "magento"
ENV MAGENTO_LANGUAGE "en_US"
ENV MAGENTO_TIMEZONE "Europe/Madrid"
ENV MAGENTO_DEFAULT_CURRENCY "EUR"
ENV MAGENTO_URL "http://www.marypeckceramics.com/"
ENV MAGENTO_URL_SECURE "https://www.marypeckceramics.com/"
ENV MAGENTO_ADMIN_FIRSTNAME "Admin"
ENV MAGENTO_ADMIN_LASTNAME "MaryPeckCeramics"
ENV MAGENTO_ADMIN_EMAIL "daniel.co.so@gmail.com"
ENV MAGENTO_ADMIN_URI "admin"
ENV MAGENTO_ADMIN_USERNAME "marypeck"
ENV MAGENTO_ADMIN_PASSWORD "password"
ENV MAGENTO_MODE "developer"

# phpize deps
RUN apt-get update && apt-get install -y \
		autoconf \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkg-config \
		re2c \
	--no-install-recommends && rm -r /var/lib/apt/lists/*

# persistent / runtime deps
RUN apt-get update && apt-get install -y \
		ca-certificates \
		curl \
		libcurl3 \
		libedit2 \
		libsqlite3-0 \
		libxml2 \
		rsync \
		git \
	--no-install-recommends && rm -r /var/lib/apt/lists/*

COPY docker-php-ext-* /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-php-ext-*
# Set PHP config directory
RUN mkdir -p $PHP_INI_DIR/conf.d

# Install PHP & Apache2

RUN echo "memory_limit=$PHP_MEMORY_LIMIT" > /usr/local/etc/php/conf.d/memory-limit.ini

RUN apt-get update && apt-get install -y apache2 apache2-utils --no-install-recommends && rm -rf /var/lib/apt/lists/*

RUN rm -rf /var/www/html && mkdir -p /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html && chown -R www-data:www-data /var/lock/apache2 /var/run/apache2 /var/log/apache2 /var/www/html

# Apache + PHP requires preforking Apache for best results
RUN a2dismod mpm_event && a2enmod mpm_prefork

RUN mv /etc/apache2/apache2.conf /etc/apache2/apache2.conf.dist && rm /etc/apache2/conf-enabled/* /etc/apache2/sites-enabled/*
COPY apache2.conf /etc/apache2/apache2.conf
# it'd be nice if we could not COPY apache2.conf until the end of the Dockerfile, but its contents are checked by PHP during compilation

RUN set -xe \
	&& buildDeps=" \
		$PHP_EXTRA_BUILD_DEPS \
		libcurl4-openssl-dev \
		libedit-dev \
		libsqlite3-dev \
		libssl-dev \
		libxml2-dev \
		xz-utils \
	" \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/* \
	&& curl -fSL "http://php.net/get/$PHP_FILENAME/from/this/mirror" -o "$PHP_FILENAME" \
	&& echo "$PHP_SHA256 *$PHP_FILENAME" | sha256sum -c - \
	&& curl -fSL "http://php.net/get/$PHP_FILENAME.asc/from/this/mirror" -o "$PHP_FILENAME.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& for key in $GPG_KEYS; do \
		gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
	done \
	&& gpg --batch --verify "$PHP_FILENAME.asc" "$PHP_FILENAME" \
	&& rm -r "$GNUPGHOME" "$PHP_FILENAME.asc" \
	&& mkdir -p /usr/src/php \
	&& tar -xf "$PHP_FILENAME" -C /usr/src/php --strip-components=1 \
	&& rm "$PHP_FILENAME" \
	&& cd /usr/src/php \
	&& ./configure \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		$PHP_EXTRA_CONFIGURE_ARGS \
		--disable-cgi \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
		--enable-mbstring \
		--with-curl \
		--with-libedit \
		--with-openssl \
		--with-zlib \
	&& make -j"$(nproc)" \
	&& make install \
	&& { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
	&& make clean \
	&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps

RUN requirements="libpng12-dev libmcrypt-dev libmcrypt4 libcurl3-dev libfreetype6 libjpeg-turbo8 libjpeg-turbo8-dev libpng12-dev libfreetype6-dev libicu-dev libxslt1-dev" \
    && apt-get update && apt-get install -y $requirements && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd \
    && docker-php-ext-install mcrypt \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install zip \
    && docker-php-ext-install intl \
    && docker-php-ext-install xsl \
    && docker-php-ext-install soap \
    && requirementsToRemove="libpng12-dev libmcrypt-dev libcurl3-dev libpng12-dev libfreetype6-dev libjpeg-turbo8-dev" \
    && apt-get purge --auto-remove -y $requirementsToRemove

# Prepare Composer & Magento

RUN mkdir /temp && cd /temp \
	&& curl -sS https://getcomposer.org/installer | php \
	&& mv composer.phar /usr/local/bin/composer
COPY ./auth.json /temp/

RUN mkdir /var/www/html \
	&& chsh -s /bin/bash www-data \
	&& chown -R www-data:www-data /var/www

COPY ./bin/install-magento /usr/local/bin/install-magento
RUN chmod +x /usr/local/bin/install-magento

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add cron job
ADD crontab /etc/cron.d/magento2-cron
RUN chmod 0644 /etc/cron.d/magento2-cron \
	&& crontab -u www-data /etc/cron.d/magento2-cron

RUN a2enmod ssl && a2enmod rewrite
COPY marypeckceramics.* /etc/ssl/private/

RUN mkdir /etc/service/apache2
ADD apache2-foreground /etc/service/apache2/run
RUN chmod +x /etc/service/apache2/run

WORKDIR /var/www/html
EXPOSE 80 443
CMD ["/sbin/my_init"]
