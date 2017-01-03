#!/bin/bash
set -e
set -x

printf "\n\n ********** STARTING HAPROXY HTTPS/AUTH PROXY ********** \n\n\n"

if [ "$SERVER_NAME" == "" ]; then
  echo "Sh*t, you forgot to set the env var 'SERVER_NAME'"
  exit -69
fi
if [ "$SSL_PUBLIC_PATH" == "" ]; then
  echo "Sh*t, you forgot to set the env var 'SSL_PUBLIC_PATH'"
  exit -68
fi
if [ "$SSL_PRIVATE_PATH" == "" ]; then
  echo "Sh*t, you forgot to set the env var 'SSL_PRIVATE_PATH'"
  exit -67
fi
if [ "$UPSTREAM_TARGET" == "" ]; then
  echo "Sh*t, you forgot to set the env var 'UPSTREAM_TARGET'"
  exit -66
fi
if [ "$HTTPS_PORT" == "" ]; then
  echo "Sh*t, you forgot to set the env var 'HTTPS_PORT'"
  exit -69
fi

mkdir -p /etc/haproxy/certs /run/haproxy
cat $SSL_PUBLIC_PATH $SSL_PRIVATE_PATH > /etc/haproxy/certs/all-certs.pem
chmod -R go-rwx /etc/haproxy/certs

# HAPROXY_USER_AUTH=""

# if [ "$HTTP_USERNAME" != "" ]; then
#   if [ "$HTTP_PASSWORD" != "" ]; then
#     printf "\n\nGenerating Password Hash for user $HTTP_USERNAME\n\n"
#     HAPROXY_USER_AUTH=$(htpasswd -BbnC 15 $HTTP_USERNAME $HTTP_PASSWORD)
#   fi
# fi

  cat << EOF > /usr/local/etc/haproxy/haproxy.cfg

global
  maxconn 4096
  # ssl-server-verify none
	# log /var/log	local0
	# log /var/log	local1 notice
	# chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
	# user haproxy
	# group haproxy
	# Default ciphers to use on SSL-enabled listening sockets.
	# For more information, see ciphers(1SSL). This list is from:
	#  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
	ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
	ssl-default-bind-options no-sslv3

defaults
	log	global
  mode http
  balance roundrobin
	option dontlognull
  option redispatch
  option forwardfor

  timeout tarpit            12s
  timeout http-request      40s
  timeout http-keep-alive   5s
  timeout check             7s

  timeout connect           5s
  timeout queue             5s
  timeout client            36000s
  timeout server            36000s

frontend http-in
  mode tcp
  bind *:$HTTPS_PORT ssl crt /etc/haproxy/certs/all-certs.pem
  default_backend backend_servers

  acl is_websocket hdr(Upgrade) -i WebSocket
  acl is_websocket hdr_beg(Host) -i ws
  use_backend backend_servers if is_websocket

backend backend_servers
  server $SERVER_NAME $UPSTREAM_TARGET weight 1 maxconn 1024

EOF


haproxy -f /usr/local/etc/haproxy/haproxy.cfg
