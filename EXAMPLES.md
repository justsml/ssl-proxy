
### External Proxy Target

```sh

docker run --rm -it \
  --name ssl-proxy-test \
  -p 5001:443 \
  -e 'HTTPS_PORT=5001' \
  -e 'HTTP_USERNAME=test' \
  -e 'HTTP_PASSWORD=test' \
  -e 'SERVER_NAME=hub.example.com' \
  -e 'UPSTREAM_TARGET=www.danlevy.net' \
  -e 'SSL_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'SSL_PRIVATE_PATH=/certs/privkey.pem' \
  -v ~/code/elastic/certs/:/certs \
  ssl-proxy:latest

```


# Linked docker target

```sh

docker run -it --restart=unless-stopped \
  --name rancher-server-ssl-proxy \
  -p 4040:443 \
  -e 'HTTPS_PORT=4040' \
  -e 'PASSWD_PATH=/registry/.passwd' \
  -e 'SERVER_NAME=cluster1.example.com' \
  -e 'UPSTREAM_TARGET=rancher-server:8080' \
  -e 'SSL_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'SSL_PRIVATE_PATH=/certs/privkey.pem' \
  -v /certs:/certs \
  -v /data/registry:/registry \
  --link 'rancher-server:rancher-server' \
  ssl-proxy:latest

docker run --rm -it \
  --name ssl-proxy-test \
  -p 5001:443 \
  -e 'HTTPS_PORT=5001' \
  -e 'HTTP_USERNAME=test' \
  -e 'HTTP_PASSWORD=test' \
  -e 'SERVER_NAME=hub.example.com' \
  -e 'UPSTREAM_TARGET=scramble4:3000' \
  -e 'SSL_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'SSL_PRIVATE_PATH=/certs/privkey.pem' \
  --link 'scramble4:scramble4' \
  -v ~/code/elastic/certs/:/certs \
  -v /tmp/registry:/registry \
  ssl-proxy:latest



docker run -d --restart=unless-stopped \
  --name ssl-proxy \
  -p 8181:443 \
  -e 'HTTPS_PORT=8181' \
  -e 'HTTP_USERNAME=devops' \
  -e 'HTTP_PASSWORD=secure' \
  -e 'SERVER_NAME=cluster1.example.com' \
  -e 'UPSTREAM_TARGET=rancher-server:8080' \
  -e 'SSL_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'SSL_PRIVATE_PATH=/certs/privkey.pem' \
  -v /certs:/certs \
  --link 'rancher-server:rancher-server' \
  justsml/ssl-proxy:latest



HTTP_USERNAME=devops HTTP_PASSWORD=secure SERVER_NAME=hub.example.com UPSTREAM_TARGET=docker-registry:4999 SSL_PUBLIC_PATH=/certs/fullchain.pem SSL_PRIVATE_PATH=/certs/privkey.pem ./entrypoint.sh

```




