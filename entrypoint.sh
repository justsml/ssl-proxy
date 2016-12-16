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

if [ "$HTTP_USERNAME" != "" ]; then
    printf "\n\nCreating Password File for user $HTTP_USERNAME\n\n"
    htpasswd -BbC 15 -c /tmp/.htpasswd $HTTP_USERNAME $HTTP_PASSWORD
    cp /tmp/.htpasswd /etc/nginx/
    export PASSWD_PATH=/etc/nginx/.htpasswd
fi

cat << EOF > /tmp/nginx.conf
worker_processes auto;

events { worker_connections 1024; }

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

http {

    upstream upstream {
        server $UPSTREAM_TARGET;
    }

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr \$remote_user [\$time_local] "\$request" '
                        '\$status \$body_bytes_sent "\$http_referer" '
                        '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

EOF



# Check if we need to add auth stuff (for docker registry now)
if [ "$PASSWD_PATH" != "" ]; then
        cat << EOF >> /tmp/nginx.conf
        auth_basic "$SERVER_NAME";
        auth_basic_user_file  "$PASSWD_PATH";
        add_header 'Docker-Distribution-Api-Version' 'registry/2.0' always;
EOF
fi




cat << EOF >> /tmp/nginx.conf

    # gzip                off;
    # gzip_comp_level   	2;
    # gzip_min_length  		4096;
    # gzip_proxied     		expired no-cache no-store private auth;
    # gzip_types       		application/x-javascript application/javascript text/javascript text/plain text/xml text/css application/xml;

    #tcp_nopush     		on;
    sendfile        		on;
    keepalive_timeout 	90;


    server {
        listen 443 ssl;
        server_name           $SERVER_NAME;
        ssl_certificate       $SSL_PUBLIC_PATH;
        ssl_certificate_key   $SSL_PRIVATE_PATH;
        ssl_session_timeout 1d;
        ssl_session_tickets on;
        ssl_session_cache shared:SSL:72m;
        ssl_prefer_server_ciphers on;
        # intermediate configuration. tweak to your needs.
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';

        # # Diffie-Hellman parameter for DHE ciphersuites, recommended 2048 bits
        # ssl_dhparam /etc/pki/nginx/dh2048.pem;


        location / {
            add_header Strict-Transport-Security max-age=15768000;
            proxy_set_header Host \$host;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Port \$server_port;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_pass http://upstream;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_buffering off;
            # This allows the ability for the execute shell window to
            # remain open for up to 30 minutes. Without this parameter,
            # the default is 1 minute and will automatically close.
            proxy_read_timeout 3600s;
        }
    }

    server {
        add_header Strict-Transport-Security max-age=15768000;
        listen 80;
        server_name $SERVER_NAME;
        return 301 https://\$server_name\$request_uri;
    }

    include /etc/nginx/conf.d/*.conf;
}
EOF

cat /tmp/nginx.conf

cp /tmp/nginx.conf /etc/nginx/

nginx -g "daemon off;"
