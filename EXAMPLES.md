
### External Proxy Target

```sh

docker run --rm -it \
  --name docker-registry-ssl-proxy \
  -p 5000:443 \
  -e 'HTTPS_PORT=5000' \
  -e 'HTTP_USERNAME=elasticsuite' \
  -e 'HTTP_PASSWORD=N3yBFkT6D3K59jkNuVjN' \
  -e 'SERVER_NAME=hub.elph.io' \
  -e 'UPSTREAM_TARGET=www.google.com' \
  -e 'SSL_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'SSL_PRIVATE_PATH=/certs/privkey.pem' \
  -v ~/xray-letsencrypt/live/beta.keyitonce.com/:/certs \
  -v /tmp/registry:/registry \
  justsml/ssl-proxy:latest

```


# Linked docker target

```sh

docker run -it --restart=unless-stopped \
  --name rancher-server-ssl-proxy \
  -p 4040:443 \
  -e 'PASSWD_PATH=/registry/.passwd' \
  -e 'SERVER_NAME=cluster1.elph.io' \
  -e 'UPSTREAM_TARGET=rancher-server:8080' \
  -e 'SSL_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'SSL_PRIVATE_PATH=/certs/privkey.pem' \
  -v /certs:/certs \
  -v /data/registry:/registry \
  --link 'rancher-server:rancher-server' \
  justsml/ssl-proxy:latest





HTTP_USERNAME=devops HTTP_PASSWORD=secure SERVER_NAME=hub.elph.io UPSTREAM_TARGET=docker-registry:4999 SSL_PUBLIC_PATH=/certs/fullchain.pem SSL_PRIVATE_PATH=/certs/privkey.pem ./entrypoint.sh

```


