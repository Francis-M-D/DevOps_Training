FROM alpine:latest

RUN apk update && apk upgrade

RUN apk add --no-cache apache2

COPY index.html /var/www/localhost/htdocs/index.html

COPY style.css /var/www/localhost/htdocs/style.css

EXPOSE 80

CMD ["httpd", "-D", "FOREGROUND"]

