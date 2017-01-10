#!/bin/bash
set -e
set -x

printf "\n\n ********** STARTING NGINX HTTPS/AUTH PROXY ********** \n\n\n"

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
# if [ "$SERVER_NAME" == "" ]; then
#   echo "Sh*t, you forgot to set the env var 'SERVER_NAME'"
#   exit -69
# fi

export PASSWD_PATH=/etc/nginx/.htpasswd

if [ "$HTTP_USERNAME" != "" ]; then
  if [ ! -f $PASSWD_PATH ]; then
    printf "\n\nCreating Password File for user $HTTP_USERNAME\n\n"
    htpasswd -BbC 15 -c /tmp/.htpasswd $HTTP_USERNAME $HTTP_PASSWORD
    mv /tmp/.htpasswd $PASSWD_PATH
  elif [ "$(grep $HTTP_USERNAME $PASSWD_PATH)" == "" ]; then
    printf "\n\nAPPENDING TO EXISTING Password File - user $HTTP_USERNAME\n\n"
    htpasswd -BbC 15 -c $PASSWD_PATH $HTTP_USERNAME $HTTP_PASSWORD
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
  # limit_req_zone  $binary_remote_addr  zone=gulag:1m   rate=60r/m;


 ## Size Limits
 #client_body_buffer_size   8k;
 #client_header_buffer_size 1k;
 #large_client_header_buffers 4 4k/8k;

  #  # Timeouts, do not keep connections open longer then necessary to reduce
  #  # resource usage and deny Slowloris type attacks.
  #   client_body_timeout    5s; # maximum time between packets the client can pause when sending nginx any data
  #   client_header_timeout  5s; # maximum time the client has to send the entire header to nginx
  #   keepalive_timeout     180s; # timeout which a single keep-alive client connection will stay open
  #   send_timeout      5s; # maximum time between packets nginx is allowed to pause when sending the client data

  #  ## General Options
  #  #aio             on;  # asynchronous file I/O, fast with ZFS, make sure sendfile=off
  #   charset           utf-8; # adds the line "Content-Type" into response-header, same as "source_charset"
  #   default_type        application/octet-stream;
  #   ignore_invalid_headers  on;
  #   include           /etc/mime.types;
  #   keepalive_requests    50;  # number of requests per connection, does not affect SPDY
  #   keepalive_disable     none; # allow all browsers to use keepalive connections
  # max_ranges        1; # allow a single range header for resumed downloads and to stop large range header DoS attacks
  # msie_padding        off;
  # open_file_cache       max=1000 inactive=1h;
  # open_file_cache_errors  on;
  # open_file_cache_min_uses  1;
  # open_file_cache_valid   1h;
  # output_buffers      1 512;
  # postpone_output       1400;   # postpone sends to match our machine's MSS
  # read_ahead        512K;   # kernel read head set to the output_buffers
  # recursive_error_pages   on;
  # reset_timedout_connection on;  # reset timed out connections freeing ram
  # sendfile          on;  # on for decent direct disk I/O
  # server_tokens       on; # version number in error pages
  # server_name_in_redirect   off; # if off, nginx will use the requested Host header
  # source_charset      utf-8; # same value as "charset"
  # tcp_nodelay         on; # Nagle buffering algorithm, used for keepalive only
  # tcp_nopush          on;
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
    ssl_certificate       $SSL_PUBLIC_PATH;
    ssl_certificate_key   $SSL_PRIVATE_PATH;
    ssl_buffer_size 4k;
    ssl_session_timeout 2h;
    ssl_session_tickets on;
    ssl_session_cache shared:SSL:12m;
    # intermediate configuration. tweak to your needs.
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS";
    # Credit: https://blog.ivanristic.com/2013/08/configuring-apache-nginx-and-openssl-for-forward-secrecy.html

    # ssl_stapling on; # staple the ssl cert to the initial reply returned to the client for speed

    # Only allow GET, HEAD and POST request methods. Since this a proxy you may
    # want to be more restrictive with your request methods. The calls are going
    # to be passed to the back end server and nginx does not know what it
    # normally accepts, so everything gets passed. If we only need to accept GET
    # HEAD and POST then limit that here.
    # if ($request_method !~ ^(GET|HEAD|POST|PUT|DELETE)$ ) {
    #     return 403;
    # }

    # client_max_body_size 0; # disable any limits to avoid HTTP 413 for large image uploads

    # # Diffie-Hellman parameter for DHE ciphersuites, recommended 2048 bits
    # ssl_dhparam /etc/nginx/dh2048.pem;

    # client_body_timeout    2s; # maximum time between packets the client can pause when sending nginx any data
    # client_header_timeout  2s; # maximum time the client has to send the entire header to nginx
    # keepalive_timeout     28s; # timeout which a single keep-alive client connection will stay open
    # send_timeout      10s; # maximum time between packets nginx is allowed to pause when sending the client data
    # spdy_keepalive_timeout 128s; # inactivity timeout after which the SPDY connection is closed
    # spdy_recv_timeout    2s; # timeout if nginx is currently expecting data from the client but nothing arrives

    # expires     5m;

    location / {
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

      add_header Strict-Trans port-Security max-age=1768000 always;
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
      if ( \$http_sec_websocket_protocol != '' ) {
        proxy_set_header Sec-WebSocket-Protocol $http_sec_websocket_protocol;
      }
      if ( \$http_sec_websocket_extensions != '' ) {
        proxy_set_header Sec-WebSocket-Extensions $http_sec_websocket_extensions;
      }
      if ( \$http_sec_websocket_key != '' ) {
        proxy_set_header Sec-WebSocket-Key $http_sec_websocket_key;
      }
      if ( \$http_sec_websocket_version != '' ) {
        proxy_set_header Sec-WebSocket-Version $http_sec_websocket_version;
      }

      # Recommended:
      proxy_buffering off;
      proxy_buffer_size 4k;

      # proxy_buffering on;
      # proxy_buffer_size 2k;
      # proxy_buffers 16 4k;
      # proxy_busy_buffers_size 8k;
      # proxy_max_temp_file_size 2m; # remove?
      # proxy_temp_file_write_size 64k;

      proxy_intercept_errors off;
      # This allows the ability for the execute long connections (e.g. a web-based shell window)
      # Without this parameter, the default is 1 minute and will automatically close.
      proxy_read_timeout 900s;
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
    add_header Strict-Transport-Security always;
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
