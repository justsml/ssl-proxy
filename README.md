# docker-ssl-proxy

An Nginx & Docker-based HTTPS/SSL reverse proxy -- loosely coupled docker service.

> Required:
1. [Generate a HTTPS/SSL certificate using letsencrypt.](https://gist.github.com/justsml/63d2884e1cd88d6785999a2eb09cf48e)
2. Define Passwords using `htpasswd`, we'll 'mount' the file later.


### Docker CLI example:

For example, to protect a docker registry:

1. Requires any working HTTP service. (Supports **local, in-docker, even remote**).
1. Start an instance of `justsml/ssl-proxy:latest` as shown below.

```sh

# Create docker registry - use non-standard port 4999 (or what you prefer)
docker run -d --restart=unless-stopped \
  --name docker-registry \
  -p 4999:5000 \
  -v /data/registry/registry:/var/lib/registry \
  registry:2.5

# Create an ssl-proxy to point at port 4999 via it's UPSTREAM_TARGET option (see below).
docker run -d --restart=unless-stopped \
  --name docker-registry-ssl-proxy \
  -p 5000:443 \
  -e 'HTTP_USERNAME=devops' \
  -e 'HTTP_PASSWORD=secure?' \
  -e 'SERVER_NAME=hub.elph.io' \
  -e 'UPSTREAM_TARGET=docker-registry:4999' \
  -e 'SSL_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'SSL_PRIVATE_PATH=/certs/privkey.pem' \
  -v /certs:/certs \
  -v /data/registry:/registry \
  --link 'docker-registry:docker-registry' \
  justsml/ssl-proxy:latest

```



### Docker compose example:

```yaml
version: '2'
services:
  ssl-proxy:
    image: justsml/ssl-proxy
    environment:
      - SERVER_NAME=rancher.example.com
      - UPSTREAM_TARGET=rancher-server:8080
      - SSL_PUBLIC_PATH=/certs/fullchain.pem
      - SSL_PRIVATE_PATH=/certs/privkey.pem
    volumes:
      - /etc/letsencrypt/live/rancher.example.com:/certs
      - /data/registry:/registry
    external_links:
      - 'rancher-server:rancher-server'

```

