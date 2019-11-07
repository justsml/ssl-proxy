# Simple docker & nginx-based ssl-proxy

Protect any HTTP service with HTTPS!
> An Nginx & Docker-based HTTPS/SSL reverse proxy.

> Will upgrade to newest nginx

### Table of Contents

1. [Features](#features)
1. [Example](#example)
1. [Getting Started](#getting-started)
    1. [Secure Docker Registry Example](#secure-docker-registry-example)
    1. [Secure Rancher Server Example](#secure-rancher-server-example)
    1. [Docker Compose Example](#docker-compose-example)
1. [Arguments / Configuration](#arguments)
  
## Features

* Up-to-date Nginx & Alpine Linux.
* Fast HTTP2 TLS-enabled reverse proxy
* Advanced CORS Support (w/ credentials, auto hostname, smart headers)
* Automatic **WebSockets Support**
* NPN/ALPN Application-Layer Protocol Negotiation [test here](https://tools.keycdn.com/http2-test)
* TLS Forward Secrecy, PFS (aka Perfect Forward Secrecy).
* Supports Optional Username & Password (stored using bcrypt at 14+ rounds)
  * Alternately an `.htpasswd` file can be volume mounted. (Multiple named users)
* Great for securing a Docker Registry, Rancher server, Wordpress, etc

## Example

Sample SSL Labs/Qualys SSL & TLS Report:

> Here's a sample of what you can expect with default configuration.

![image](https://cloud.githubusercontent.com/assets/397632/21792469/4db4a768-d6a7-11e6-8728-97e80c3b5ed2.png)
![image](https://cloud.githubusercontent.com/assets/397632/21792860/f24203d2-d6a9-11e6-8e35-9138e55c81da.png)


## Getting Started

*Requirements*

> 1. [Generate a HTTPS/SSL certificate using letsencrypt.](https://gist.github.com/justsml/63d2884e1cd88d6785999a2eb09cf48e)

To provide secure, proxied access to local HTTP service:

1. Requires any working HTTP service (for UPSTREAM_TARGET.) (Supports **local, in-docker, even remote**).
1. Start an instance of `justsml/ssl-proxy:latest` as shown below.

### Secure Docker Registry Example

```sh
# Note: Small scale users can set certificates directly in the registry instance (v2+) 
docker run -d --restart=on-failure:5 \
  --name docker-registry \
  -v /data/registry/registry:/var/lib/registry \
  registry:2.5

# Create an ssl-proxy to point at the registry's port 5000 (via UPSTREAM_TARGET option - see below.)
docker run -d --restart=on-failure:5 \
  --name ssl-proxy \
  -p 5000:5000 \
  -e 'SERVER_NAME=hub.example.com' \
  -e 'UPSTREAM_TARGET=docker-registry:5000' \
  -e 'HTTPS_PORT=5000' \
  -e 'USERNAME=devops' \
  -e 'PASSWORD=secure' \
  -e 'CERT_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'CERT_PRIVATE_PATH=/certs/privkey.pem' \
  -e "ADD_HEADER='Docker-Distribution-Api-Version' 'registry/2.0' always" \
  -v '/certs:/certs:ro' \
  --link 'docker-registry:docker-registry' \
  justsml/ssl-proxy:latest

# ALT Options
# Create an ssl-proxy to point at the registry's port 5000 (via UPSTREAM_TARGET option - see below.)
docker run -d --restart=on-failure:5 \
  --name ssl-proxy \
  -p 5000:5000 \
  -e 'SERVER_NAME=hub.example.com' \
  -e 'UPSTREAM_TARGET=docker-registry:5000' \
  -e 'EXPIRES_DEFAULT=-1' \
  -e 'HTTPS_PORT=5000' \
  -e 'USERNAME=devops' \
  -e 'PASSWORD=secure' \
  -e 'CERT_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'CERT_PRIVATE_PATH=/certs/privkey.pem' \
  -e "ADD_HEADER='Docker-Distribution-Api-Version' 'registry/2.0' always" \
  -v '/certs:/certs:ro' \
  --link 'docker-registry:docker-registry' \
  justsml/ssl-proxy:latest


```

### Secure Rancher Server Example

```sh
# Update Cached Docker Images
docker pull rancher/server:latest
docker pull justsml/ssl-proxy:latest

# Start Rancher w/ default local port 8080
docker run -d --restart=always \
  --name rancher-server \
  -v /data/rancher/mysql:/var/lib/mysql \
  rancher/server:latest

# Create an ssl-proxy with certs in /certs, (w/o user/pass auth) to point at the local rancher-server's port 8080
docker run -d --restart=always \
  --name rancher-proxy \
  -p 8080:8080 \
  -e 'HTTPS_PORT=8080' \
  -e 'SERVER_NAME=_' \
  -e 'UPSTREAM_TARGET=rancher-server:8080' \
  -e 'CERT_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'CERT_PRIVATE_PATH=/certs/privkey.pem' \
  -v '/certs:/certs:ro' \
  --link 'rancher-server:rancher-server' \
  justsml/ssl-proxy:latest

```



### Docker Compose Example

```yaml
version: '2'
services:
  ssl-proxy:
    image: justsml/ssl-proxy:latest
    environment:
    - HTTPS_PORT=8080
    - SERVER_NAME=rancher.example.com
    - UPSTREAM_TARGET=rancher-server:8080
    - CERT_PUBLIC_PATH=/certs/fullchain.pem
    - CERT_PRIVATE_PATH=/certs/privkey.pem
    volumes:
    - /certs:/certs:ro
    links:
    - 'rancher-server:rancher-server'
    ports: [ '8080:8080' ]
  rancher-server:
    image: rancher/server:latest
    expose: [ '8080' ]
    volumes:
    - /data/rancher/mysql:/var/lib/mysql
```

---------------


## Arguments

|Name               | Default/Reqd  | Notes
|-------------------|---------------|-----------------------|
|CERT_AUTO          | Optional      | Set to `true` to automatically request certificate for $SERVER_NAME - caution: don't exceed let's encrypts API limits.
|CERT_PUBLIC_PATH   | Reqd. PEM file| Bind-mount certificate files to container path `/certs` - Or override path w/ this var.
|CERT_PRIVATE_PATH  | Reqd. PEM file| Bind-mount certificate files to container path `/certs` - Or override path w/ this var.
|SERVER_NAME        | Required      | Primary domain name. Not restricting.
|UPSTREAM_TARGET    | Required      | HTTP target host:port. Typically an internally routable address. e.g. `localhost:9090` or `rancher-server:8080`
|HTTPS_PORT         | 443/Required  | Needed for URL rewriting.
|ALLOW_RC4          | Not set       | Backwards Compatible Option Required for Java 6 or WinXP/IE8
|EXPIRES_DEFAULT    | Not set       | Set to apply a default expiration value for nginx `location /`. Useful for app & caching proxies. (For app use `-1` and for caching proxy something like `6h`)
|USERNAME           | admin         | Both PASSWORD and USERNAME must be set in order to use Basic authorization
|PASSWORD           |               | Both PASSWORD and USERNAME must be set in order to use Basic authorization
|PASSWD_PATH        | /etc/nginx/.htpasswd | Alternate auth support (don't combine with USERNAME/PASSWORD) Bind-mount a custom path to `/etc/nginx/.htpasswd`
|ADD_HEADER         | Not set       | Useful for tagging routes in your infrastructure.
|SERVER_NAMES_HASH_SIZE         | 32       | Variable conditionning maximum size of server name. Set it to 64/128/... if nginx fails to start with `could not build server_names_hash, you should increase server_names_hash_bucket_size` error message.


===================

-------------------


### Contributing / Dev Notes

> WORK IN PROGRESS:

1. HTTPS -> HTTPS proxying support. AKA End-to-end TLS. (skipped due to underwhelming performance and extra complexity in the bash startup script.)
1. Better CORS support: multi host name
1. haproxy alt version


```sh
# Publish 'latest' version
docker build -t ssl-proxy:latest .
docker tag ssl-proxy:latest justsml/ssl-proxy:latest
docker push justsml/ssl-proxy:latest
# Push a tagged version:
# docker tag ssl-proxy:latest justsml/ssl-proxy:v1.0.1
# docker push justsml/ssl-proxy:v1.0.1

# Remember to docker pull on servers
docker pull justsml/ssl-proxy:latest

# Local testing:
docker build -t ssl-proxy:latest .
docker rm -f TEST-ssl-proxy
docker run --rm \
  --name TEST-ssl-proxy \
  -v ~/certs/xray:/certs \
  -p 5000:5000 \
  -e 'HTTPS_PORT=5000' \
  -e 'USERNAME=devops' \
  -e 'PASSWORD=secure' \
  -e 'SERVER_NAME=hub.example.com' \
  -e 'UPSTREAM_TARGET=www.google.com:80' \
  -e 'CERT_PUBLIC_PATH=/certs/fullchain.pem' \
  -e 'CERT_PRIVATE_PATH=/certs/privkey.pem' \
  ssl-proxy:latest


```

