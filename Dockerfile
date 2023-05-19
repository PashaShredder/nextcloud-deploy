FROM nextcloud:23.0.2-apache

RUN apt-get update \
    && apt-get install -y nano \
    && rm -rf /var/lib/apt/lists/*

CMD ["apache2-foreground"]
