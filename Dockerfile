FROM php:8.1-apache

ARG AKAUNTING_DOCKERFILE_VERSION=0.1
ARG SUPPORTED_LOCALES="en_US.UTF-8"

# 1. Install dependencies
RUN apt-get update \
 && apt-get -y upgrade --no-install-recommends \
 && apt-get install -y \
    build-essential \
    imagemagick \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libjpeg-dev \
    libmcrypt-dev \
    libonig-dev \
    libpng-dev \
    libpq-dev \
    libssl-dev \
    libxml2-dev \
    libxrender1 \
    libzip-dev \
    locales \
    openssl \
    unzip \
    zip \
    zlib1g-dev \
    --no-install-recommends \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Setup Locales
RUN for locale in ${SUPPORTED_LOCALES}; do \
    sed -i 's/^# '"${locale}/${locale}/" /etc/locale.gen; done \
 && locale-gen

# 3. Setup PHP Extensions
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
 && docker-php-ext-install -j$(nproc) \
    gd \
    bcmath \
    intl \
    mbstring \
    pcntl \
    pdo \
    pdo_mysql \
    zip

# 4. Download Akaunting to a BACKUP location (Not /var/www/html directly)
RUN mkdir -p /usr/src/akaunting \
 && curl -Lo /tmp/akaunting.zip 'https://akaunting.com/download.php?version=latest&utm_source=docker&utm_campaign=developers' \
 && unzip /tmp/akaunting.zip -d /usr/src/akaunting \
 && rm -f /tmp/akaunting.zip

COPY files/akaunting.sh /usr/local/bin/akaunting.sh
# We copy default html files to backup too, just in case
COPY files/html /usr/src/akaunting

# --- FINAL FIX: Restore files if Volume is empty ---
RUN echo '#!/bin/bash\n\
echo "Running Railway MPM Fix..."\n\
rm -f /etc/apache2/mods-enabled/mpm_event.load\n\
rm -f /etc/apache2/mods-enabled/mpm_event.conf\n\
a2enmod mpm_prefork\n\
\n\
# CHECK: Is the volume empty? If so, fill it from backup.\n\
if [ ! -f /var/www/html/artisan ]; then\n\
    echo "Volume is empty! Copying Akaunting source files..."\n\
    cp -rT /usr/src/akaunting /var/www/html\n\
    chown -R www-data:www-data /var/www/html\n\
fi\n\
\n\
echo "Fix applied. Starting Akaunting..."\n\
exec /usr/local/bin/akaunting.sh "$@"' > /usr/local/bin/railway-start.sh \
 && chmod +x /usr/local/bin/railway-start.sh

# Use our custom wrapper
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
CMD ["--start"]
