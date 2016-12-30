# FROM openresty/openresty:1.11.2.2-alpine
FROM nginx:1.11-alpine

MAINTAINER Dan Levy <Dan@DanLevy.net>

WORKDIR /www/

COPY ./entrypoint.sh ./

EXPOSE 80 443

# RUN apt-get update && apt-get install apache2-utils openssl -y
RUN apk update && apk add bash && apk add apache2-utils && apk add openssl

ENTRYPOINT /www/entrypoint.sh

