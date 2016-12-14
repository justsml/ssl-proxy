FROM nginx:1-alpine

COPY ./entrypoint.init.sh ./

EXPOSE 80 443


ENTRYPOINT [ './entrypoint.init.sh' ]
