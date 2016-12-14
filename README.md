# docker-ssl-proxy

An Nginx & Docker-based HTTPS/SSL reverse proxy into other mounted docker services.

> Required: Generate certs using letsencrypt

### Docker compose example:

```sh
# Create docker registry - 4999 will be used to connect to ssl proxy port
docker run -d --restart=unless-stopped \
  --name docker-registry \
  -p 5000 \
  -v /data/registry/registry:/var/lib/registry \
  registry:2.5

docker run -d --restart=unless-stopped \
  --name docker-registry-ssl-proxy \
  -p 5000:443 \
  -e 'SERVER_NAME=hub.elph.io' \
  -e 'UPSTREAM_TARGET=docker-registry:5000' \
  -e 'SSL_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'SSL_PRIVATE_PATH=/certs/privkey.pem' \
  -v /certs:/certs \
  --link 'docker-registry:docker-registry' \
  justsml/ssl-proxy

```

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
    external_links:
      - 'rancher-server:rancher-server'

```

