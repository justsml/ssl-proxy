FROM justsml/docker-nginx

MAINTAINER Dan Levy <Dan@DanLevy.net>

WORKDIR /www/

COPY ./entrypoint.sh ./

EXPOSE 80 443

# RUN apt-get update && apt-get install apache2-utils openssl -y
RUN apk --update add bash apache2-utils openssl-dev

ENTRYPOINT /www/entrypoint.sh
