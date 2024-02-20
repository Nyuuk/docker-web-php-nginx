#!/bin/bash

# PATH CONF
PATH_CONF=conf.d

# Function to display usage
usage() {
    echo "Usage: $0 -h <domain_host> -p <port>"
    exit 1
}

# Parse command line options
while getopts ":h:p:" opt; do
    case ${opt} in
        h)
            domain_host=$OPTARG
            ;;
        p)
            port=$OPTARG
            ;;
        \?)
            echo "Invalid option: $OPTARG" 1>&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." 1>&2
            usage
            ;;
    esac
done
shift $((OPTIND -1))

# Check if required arguments are provided
if [[ -z $domain_host || -z $port ]]; then
    usage
fi

# Create Nginx configuration file
cat > $PATH_CONF/$domain_host.conf << EOF
server {
    listen 80;
    server_name $domain_host;
    error_log  /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;
    root /var/www/html;
    location / {
        proxy_pass http://host.docker.internal:$port;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
    }
}
EOF

# Symlink the configuration file to sites-enabled
# ln -s /etc/nginx/sites-available/$domain_host.conf /etc/nginx/sites-enabled/

# Test Nginx configuration
docker-compose exec web nginx -t

# If configuration test passes, reload Nginx
if [ $? -eq 0 ]; then
    docker-compose exec web nginx -s reload
    echo "Nginx configuration reloaded successfully."
else
    echo "Nginx configuration test failed. Please check the configuration file."
fi
