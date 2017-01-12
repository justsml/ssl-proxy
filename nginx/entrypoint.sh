#!/bin/bash
set -e
# set -x

printf "\n\n ********** STARTING NGINX HTTPS/AUTH PROXY ********** \n\n\n"

# Default location, can be changed to another location or simply bind-mount w/ `-v ~/.htpasswd:/etc/nginx/.htpasswd:ro`
PASSWD_PATH=${PASSWD_PATH-"/etc/nginx/.htpasswd"}

USERNAME=${USERNAME-"$HTTP_USERNAME"}
PASSWORD=${PASSWORD-"$HTTP_PASSWORD"}
CERT_PUBLIC_PATH=${CERT_PUBLIC_PATH-"$SSL_PUBLIC_PATH"}
CERT_PRIVATE_PATH=${CERT_PRIVATE_PATH-"$SSL_PRIVATE_PATH"}
CERT_PUBLIC_PATH=${CERT_PUBLIC_PATH-"/certs/fullchain.pem"}
CERT_PRIVATE_PATH=${CERT_PRIVATE_PATH-"/certs/privkey.pem"}
HTTPS_PORT=${HTTPS_PORT-"443"}
TLS_PROTOCOLS=${TLS_PROTOCOLS-"TLSv1 TLSv1.1 TLSv1.2"}

if [ "$SERVER_NAME" == "" ]; then
  echo "Sh*t, you forgot to set the env var 'SERVER_NAME'"
  SERVER_NAME=`hostname -f`
  printf "\n###### GUESSING SERVER_NAME: $SERVER_NAME \n^^^^^ DETECTED ^^^^^\n"
fi
if [ ! -f "$CERT_PUBLIC_PATH" ]; then
  printf >&2 "Sh*t, '\$CERT_PUBLIC_PATH' not found!\nNOT_FOUND: $CERT_PUBLIC_PATH\n"
  exit -68
fi
if [ ! -f "$CERT_PRIVATE_PATH" ]; then
  printf >&2 "Sh*t, '\$CERT_PRIVATE_PATH' not found!\nNOT_FOUND: $CERT_PRIVATE_PATH\n"
  exit -67
fi
if [ "$UPSTREAM_TARGET" == "" ]; then
  echo "Sh*t, you forgot to set the env var 'UPSTREAM_TARGET'"
  exit -66
fi
if [ "$ALLOW_RC4" != "" ]; then
  HTTPS_RC4=" RC4 "
  printf "\n\nWARNING: Enabling RC4 Ciphers - IE8/WinXP & Java6 Requirement <<<<<<<<<<<<\n"
  printf "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AHHH! BAD IDEA ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n"
  printf "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AHHH! BAD IDEA ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n"
  printf "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AHHH! BAD IDEA ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n"
  printf "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ AHHH! BAD IDEA ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n"
  sleep 30s
else
  HTTPS_RC4=" !RC4 "
fi

if [ "$PASSWORD" != "" ]; then
  if [ ! -f $PASSWD_PATH ]; then
    printf "\n\nCreating Password File for user $USERNAME\n\n"
    htpasswd -BbC 12 -c /tmp/.htpasswd $USERNAME $PASSWORD
    mv /tmp/.htpasswd $PASSWD_PATH
  elif [ "$(grep $USERNAME $PASSWD_PATH)" == "" ]; then
    printf "\n\nAPPENDING TO EXISTING Password File - user $USERNAME\n\n"
    htpasswd -BbC 12 -c $PASSWD_PATH $USERNAME $PASSWORD
  fi
fi

# if [ -f "/etc/nginx/dh2048.pem" ]; then
#   echo 'Has dhparam file.'
# else
#   openssl dhparam 2048 > /etc/nginx/dh2048.pem
# fi

cat << EOF > /tmp/nginx.conf
worker_processes auto;

events { worker_connections 1024; }

error_log   /var/log/nginx/error.log warn;
pid         /var/run/nginx.pid;

http {
  map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
  }

  upstream upstream {
    server $UPSTREAM_TARGET max_fails=3 fail_timeout=20s;
  }

  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;
  log_format  main  '[\$time_local] \$status \$remote_addr "\$http_x_forwarded_for" "\$remote_user" "\$request" '
            '\$body_bytes_sent "\$http_referer" '
            '"\$http_user_agent"';

  access_log  /var/log/nginx/access.log  main;

  client_max_body_size    4g;

  # # Deny certain User-Agents (case insensitive)
  # # The ~* makes it case insensitive as opposed to just a ~
  # if ($http_user_agent ~* (Baiduspider|Jullo) ) {
  #   return 405;
  # }

  # # Deny certain Referers (case insensitive)
  # # The ~* makes it case insensitive as opposed to just a ~
  # if ($http_referer ~* (babes|click|diamond|forsale|girl|jewelry|love|nudit|organic|poker|porn|poweroversoftware|sex|teen|video|webcam|zippo) ) {
  #   return 405;
  # }

  ## Request limits
  # limit_req_zone  \$binary_remote_addr  zone=gulag:1m   rate=60r/m;

  ## Size Limits
  #client_body_buffer_size   8k;
  #client_header_buffer_size 1k;
  #large_client_header_buffers 4 4k/8k;

  #  ## General Options
  max_ranges        1; # allow a single range header for resumed downloads and to stop large range header DoS attacks
  # msie_padding        off;
  reset_timedout_connection on;  # reset timed out connections freeing ram
  server_name_in_redirect   off; # if off, nginx will use the requested Host header
  sendfile            on;
  keepalive_timeout   90;


  server {
    listen    $HTTPS_PORT       ssl http2;
    listen    [::]:$HTTPS_PORT  ssl http2;

    # Credit: https://www.keycdn.com/support/enable-gzip-compression/
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 1;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types application/javascript application/rss+xml application/vnd.ms-fontobject application/x-font application/x-font-opentype application/x-font-otf application/x-font-truetype application/x-font-ttf application/x-javascript application/xhtml+xml application/xml font/opentype font/otf font/ttf image/svg+xml image/x-icon text/css text/javascript text/plain text/xml;

    # limit_req   zone=gulag burst=500 nodelay;

    # chunkin on;

    server_name           $SERVER_NAME;
    ssl_certificate       $CERT_PUBLIC_PATH;
    ssl_certificate_key   $CERT_PRIVATE_PATH;
    ssl_buffer_size 4k;
    ssl_session_timeout 2h;
    ssl_session_tickets on;
    ssl_session_cache shared:SSL:12m;
    # intermediate configuration. tweak to your needs.

    ssl_protocols $TLS_PROTOCOLS; #TLSv1 TLSv1.1 TLSv1.2

    ssl_prefer_server_ciphers on;

    # NOTE: \$HTTPS_RC4 controls RC4 in entrypoint.sh
    # Credit: https://blog.ivanristic.com/2013/08/configuring-apache-nginx-and-openssl-for-forward-secrecy.html
    # ssl_ciphers "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA $HTTPS_RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS";
    # Credit: https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html#The_Cipher_Suite
    ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';

    # client_max_body_size 0; # disable any limits to avoid HTTP 413 for large image uploads

    # # Diffie-Hellman parameter for DHE ciphersuites, recommended 2048 bits
    # ssl_dhparam /etc/nginx/dh2048.pem;

    location / {
EOF

# Check expires var
if [ "$EXPIRES_DEFAULT" != "" ]; then
  cat << EOF >> /tmp/nginx.conf
      expires $EXPIRES_DEFAULT;
EOF
fi

cat << EOF >> /tmp/nginx.conf


      set \$acac true;
      if (\$http_origin = '') {
        set \$acac false;
        set \$http_origin "*";
      }

      if (\$request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' \$http_origin always;
        add_header 'Access-Control-Allow-Credentials' \$acac always;
        add_header 'Access-Control-Allow-Methods' ${CORS_METHODS-'GET, POST, PUT, DELETE, HEAD, OPTIONS'} always;
        add_header 'Access-Control-Allow-Headers' ${CORS_HEADERS-'Sec-WebSocket-Extensions,Sec-WebSocket-Key,Sec-WebSocket-Protocol,Sec-WebSocket-Version,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,x-api-action-links,x-api-csrf,x-api-no-challenge,X-Forwarded-For,X-Real-IP'} always;
        add_header 'Access-Control-Max-Age' 864000 always;
        add_header 'Content-Type' 'text/plain; charset=UTF-8' always;
        add_header 'Content-Length' 0 always;
        return 204;
      }

      add_header 'Access-Control-Allow-Origin' \$http_origin always;
      add_header 'Access-Control-Allow-Credentials' \$acac always;
      add_header 'Access-Control-Allow-Methods' ${CORS_METHODS-'GET, POST, PUT, DELETE, HEAD, OPTIONS'} always;
      add_header 'Access-Control-Allow-Headers' ${CORS_HEADERS-'Sec-WebSocket-Extensions,Sec-WebSocket-Key,Sec-WebSocket-Protocol,Sec-WebSocket-Version,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,x-api-action-links,x-api-csrf,x-api-no-challenge,X-Forwarded-For,X-Real-IP'} always;
      add_header 'Access-Control-Max-Age' 864000 always;


EOF

# Check if we need to add auth stuff (for docker registry now)
if [ -f "$PASSWD_PATH" ]; then
  cat << EOF >> /tmp/nginx.conf
      auth_basic "Restricted";
      auth_basic_user_file  "$PASSWD_PATH";
EOF
fi
# Check if we need to add auth stuff (for docker registry now)
if [ "$ADD_HEADER" != "" ]; then
  cat << EOF >> /tmp/nginx.conf
      add_header $ADD_HEADER;
EOF
fi

cat << EOF >> /tmp/nginx.conf

      add_header Strict-Transport-Security max-age=17968000 always;
      proxy_pass http://upstream;
      proxy_http_version 1.1;
      proxy_set_header Host \$host;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_set_header X-Real-IP  \$remote_addr;
      proxy_set_header X-Forwarded-Port \$server_port;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
      ## Socket Headers
      proxy_set_header Sec-Websocket-Key        \$http_sec_websocket_key;
      proxy_set_header Sec-Websocket-Version    \$http_sec_websocket_version;
      proxy_set_header Sec-WebSocket-Protocol   \$http_sec_websocket_protocol;
      proxy_set_header Sec-WebSocket-Extensions \$http_sec_websocket_extensions;

      # Recommended: ? Slow - Tested on greylog & rancher 2017-01-11 ?
      # proxy_buffering off;
      # proxy_buffer_size 4k;

      proxy_buffering on;
      proxy_buffer_size 2k;
      proxy_buffers 16 4k;
      proxy_busy_buffers_size 8k;
      proxy_temp_file_write_size 128k;
      # proxy_max_temp_file_size 2m; # remove?

      # proxy_intercept_errors off;
      # This allows the ability for the execute long connections (e.g. a web-based shell window)
      # Without this parameter, the default is 1 minute and will automatically close.
      proxy_read_timeout 180s;
    }

    # For docker registry support, will support injecting this stuff...
    # TODO: Support injecting or bind mounting this config:
    location /_ping {
      auth_basic off;
    }

    location /v1/_ping {
      auth_basic off;
    }

  }

  server {
    add_header Strict-Transport-Security max-age=17968000 always;
    listen    80;
    listen    [::]:80 default ipv6only=on;
    server_name $SERVER_NAME;
    return 301 https://\$server_name:\$server_port\$request_uri;
  }

  include /etc/nginx/conf.d/*.conf;
}
EOF

cat /tmp/nginx.conf

cp /tmp/nginx.conf /etc/nginx/

nginx -g "daemon off;"
