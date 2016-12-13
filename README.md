# docker-ssl-proxy

An Nginx & Docker-based HTTPS/SSL reverse proxy into other mounted docker services.

> Required: Generate certs using letsencrypt

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
    external_links:
      - 'rancher-server:rancher-server'

```

