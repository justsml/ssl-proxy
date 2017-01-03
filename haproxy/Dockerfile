FROM haproxy:1.7-alpine

MAINTAINER Dan Levy <Dan@DanLevy.net>

WORKDIR /www/

COPY ./entrypoint.sh ./

EXPOSE 80 443

RUN apk --update add bash apache2-utils sudo

ENTRYPOINT /www/entrypoint.sh

