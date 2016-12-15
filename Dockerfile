FROM nginx:1-alpine

MAINTAINER Dan Levy <Dan@DanLevy.net>

WORKDIR /www/

COPY ./entrypoint.sh ./

EXPOSE 80 443

RUN apt-get update && apt-get install apache2-utils -y

ENTRYPOINT [ '/www/entrypoint.sh' ]

