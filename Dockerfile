FROM nginx:1-alpine

MAINTAINER Dan Levy <Dan@DanLevy.net>

COPY ./entrypoint.init.sh ./

EXPOSE 80 443

ENTRYPOINT [ './entrypoint.init.sh' ]
