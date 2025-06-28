FROM centos:9

# Install system dependencies
RUN dnf update -y && dnf install -y \
    httpd \
    gcc \
    gcc-c++ \
    make \
    unzip \
    git \
    wget \
    nano \
    openssl \
    mod_ssl \
    && dnf clean all

# Install Remi repository for newer PHP versions
RUN dnf install -y epel-release && \
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm && \
    dnf module enable -y php:remi-8.1 && \
    dnf install -y \
    php \
    php-cli \
    php-common \
    php-gd \
    php-mbstring \
    php-mysqlnd \
    php-xml \
    php-curl \
    php-zip \
    php-opcache \
    php-json \
    php-pear \
    php-devel \
    php-fpm \
    && dnf clean all

# Enable Apache modules
RUN a2enmod rewrite ssl headers || \
    (echo "LoadModule rewrite_module modules/mod_rewrite.so" >> /etc/httpd/conf/httpd.conf && \
     echo "LoadModule ssl_module modules/mod_ssl.so" >> /etc/httpd/conf/httpd.conf && \
     echo "LoadModule headers_module modules/mod_headers.so" >> /etc/httpd/conf/httpd.conf)

# Create SSL certificate
RUN mkdir -p /etc/pki/tls/private /etc/pki/tls/certs && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/pki/tls/private/apache-selfsigned.key \
    -out /etc/pki/tls/certs/apache-selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=localhost"

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install Drush
RUN wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar \
    && chmod +x drush.phar \
    && mv drush.phar /usr/local/bin/drush

# Set working directory
WORKDIR /var/www/html

# Copy Drupal installation script
COPY docker/install-drupal.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/install-drupal.sh

# Copy custom Apache configuration
COPY docker/apache.conf /etc/httpd/conf.d/000-default.conf

# Create health check script
RUN echo '#!/bin/bash\n\
curl -f http://localhost/ || exit 1' > /usr/local/bin/healthcheck.sh \
    && chmod +x /usr/local/bin/healthcheck.sh

# Remove any mod_php config lines
RUN sed -i '/LoadModule php_module modules\/libphp.so/d' /etc/httpd/conf/httpd.conf || true
RUN sed -i '/AddHandler php-script .php/d' /etc/httpd/conf/httpd.conf || true
RUN sed -i '/DirectoryIndex index.php index.html/d' /etc/httpd/conf/httpd.conf || true

# Create startup script to run both services
RUN printf '#!/bin/bash\n\
# Create PHP-FPM socket directory\n\
mkdir -p /run/php-fpm\n\
\n\
# Run Drupal installation\n\
/usr/local/bin/install-drupal.sh\n\
\n\
# Start PHP-FPM\n\
php-fpm --nodaemonize &\n\
\n\
# Wait a moment for PHP-FPM to start\n\
sleep 2\n\
\n\
# Start Apache\n\
httpd -D FOREGROUND\n\
' > /usr/local/bin/start.sh && chmod +x /usr/local/bin/start.sh

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Patch default SSL config to use our self-signed cert and correct DocumentRoot
RUN sed -i 's|^\s*SSLCertificateFile.*|    SSLCertificateFile /etc/pki/tls/certs/apache-selfsigned.crt|' /etc/httpd/conf.d/ssl.conf && \
    sed -i 's|^\s*SSLCertificateKeyFile.*|    SSLCertificateKeyFile /etc/pki/tls/private/apache-selfsigned.key|' /etc/httpd/conf.d/ssl.conf && \
    sed -i 's|^\s*DocumentRoot.*|    DocumentRoot /var/www/html/web|' /etc/httpd/conf.d/ssl.conf

# Start with installation script
CMD ["/usr/local/bin/start.sh"]