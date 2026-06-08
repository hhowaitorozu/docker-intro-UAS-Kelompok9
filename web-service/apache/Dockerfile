FROM httpd:2.4-alpine

# Aktifkan module yang dibutuhkan
RUN sed -i \
    -e 's/#LoadModule vhost_alias_module/LoadModule vhost_alias_module/' \
    -e 's/#LoadModule rewrite_module/LoadModule rewrite_module/' \
    /usr/local/apache2/conf/httpd.conf

# Include virtual host config
RUN echo "Include conf/extra/vhosts.conf" >> /usr/local/apache2/conf/httpd.conf

# Buat direktori log
RUN mkdir -p /var/log/apache2

# Copy virtual host config
COPY sites/vhosts.conf /usr/local/apache2/conf/extra/vhosts.conf

# Copy site files
COPY html-site1/ /usr/local/apache2/htdocs/site1/
COPY html-site2/ /usr/local/apache2/htdocs/site2/

EXPOSE 80
