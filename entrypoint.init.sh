#!/bin/bash
set -e

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


cat << EOF > /tmp/nginx.conf
worker_processes auto;

events { worker_connections 4096; }

upstream rancher {
    server $UPSTREAM_TARGET;
}

http {

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '$remote_addr $remote_user [$time_local] "$request" '
                        '$status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

EOF





# Check if we need to add auth stuff (for docker registry now)
if [ "$HTPASSWD_PATH" != "" ]; then
        cat << EOF >> /tmp/nginx.conf
        auth_basic "$SERVER_NAME";
        auth_basic_user_file  "$HTPASSWD_PATH";
        add_header 'Docker-Distribution-Api-Version' 'registry/2.0' always;
EOF
fi







cat << EOF >> /tmp/nginx.conf

    gzip  							on;
    gzip_comp_level   	2;
    gzip_min_length  		4096;
    gzip_proxied     		expired no-cache no-store private auth;
    gzip_types       		application/x-javascript application/javascript text/javascript text/plain text/xml text/css application/xml;

    #tcp_nopush     		on;
    sendfile        		on;
    keepalive_timeout 	90;


    server {
        listen 443 ssl;
        server_name           $SERVER_NAME;
        ssl_certificate       $SSL_PUBLIC_PATH;
        ssl_certificate_key   $SSL_PRIVATE_PATH;

        location / {
            proxy_set_header Host \$host;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Port \$server_port;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_pass http://rancher;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "Upgrade";
            # This allows the ability for the execute shell window to
            # remain open for up to 30 minutes. Without this parameter,
            # the default is 1 minute and will automatically close.
            proxy_read_timeout 3600s;
        }
    }

    server {
        listen 80;
        server_name <server>;
        return 301 https://\$server_name\$request_uri;
    }
}
EOF

cat /tmp/nginx.conf

cp /tmp/nginx.conf /etc/nginx/

./entrypoint.sh
