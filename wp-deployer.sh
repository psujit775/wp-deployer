#!/bin/bash
## Usage: ./wp-deployer.sh <remote server ip> <user name> <php version>
## Example: ./wp-deployer.sh 52.66.251.182 ubuntu php7.2
## Note: You should have already set up passwordless SSH authentication.

set -e

# Remote machine's IP address
remote_ip=$1

# SSH username
ssh_username=$2

# wordpress version
php_version=$3

db_name=$(LC_ALL=C tr -dc 'A-Za-z' </dev/urandom | head -c 8 ; echo)
db_user=$(LC_ALL=C tr -dc 'A-Za-z' </dev/urandom | head -c 8 ; echo)
db_password=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 13 ; echo)
root_db_password=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18 ; echo)

installDocker(){
    ssh $ssh_username@$remote_ip "curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
    # Adding current user to docker group
    ssh $ssh_username@$remote_ip "sudo usermod -aG docker $ssh_username"
    ssh $ssh_username@$remote_ip "rm -rf get-docker.sh"
}

genDockerCompose(){
    cat <<EOF > docker-compose.yml
version: '3'

services:
  mariadb:
    container_name: mariadb
    image: mariadb
    environment:
      MARIADB_ROOT_PASSWORD: $root_db_password
      MARIADB_DATABASE: $db_name
      MARIADB_USER: $db_user
      MARIADB_PASSWORD: $db_password
    volumes:
      - ./.db-data:/var/lib/mysql
    restart: unless-stopped

  wp:
    container_name: wordpress
    image: wordpress:$php_version-fpm-alpine
    environment:
      WORDPRESS_DB_HOST: mariadb:3306
      WORDPRESS_DB_NAME: $db_name
      WORDPRESS_DB_USER: $db_user
      WORDPRESS_DB_PASSWORD: $db_password
      WORDPRESS_TABLE_PREFIX: wp_
    depends_on:
      - mariadb
    volumes:
      - ./wordpress_data:/var/www/html
    restart: unless-stopped

  nginx:
    container_name: nginx
    image: nginx:alpine
    volumes:
      - /etc/nginx/conf.d:/etc/nginx/conf.d
      - ./wordpress_data:/var/www/html
      - /var/log/nginx/:/var/log/nginx/
    ports:
      - '80:80'
      - '443:443'
    depends_on:
      - wp
    restart: unless-stopped
EOF
}

genNginxConf(){
    cat <<EOF > wp.conf
gzip on;
server_tokens off;
log_format main1 '\$remote_addr - [\$time_local "\$request" ' '\$status \$body_bytes_sent "\$http_referer" ' '"\$http_user_agent" "\$http_x_forwarded_for"';
server {
    listen 80;
    listen [::]:80; 
    root /var/www/html;
    index index.php;
 
    access_log /var/log/nginx/access.log main1;
    error_log /var/log/nginx/error.log;
 
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    rewrite /wp-admin$ \$scheme://\$host\$uri/ permanent;
    location ~* ^.+\.(ogg|ogv|svg|svgz|eot|otf|woff|mp4|ttf|rss|atom|jpg|jpeg|gif|png|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf)$ {
        access_log off; log_not_found off; expires max;
    }

    location ~ [^/]\.php(/|$) {
      fastcgi_split_path_info ^(.+?\.php)(/.*)$;
      if (!-f \$document_root\$fastcgi_script_name) {
          return 404;
      }
      include fastcgi_params;
      fastcgi_index index.php;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      fastcgi_pass wp:9000;
    }
}
EOF
}

# Install docker on remote machine
# Check if Docker is running
if ssh $ssh_username@$remote_ip "sudo systemctl is-active docker > /dev/null"; then
    echo "Docker is already installed and running on $remote_ip"
else
    echo "Installing Docker on $remote_ip"
    installDocker
fi

# Copy Nginx wp.conf
if ssh $ssh_username@$remote_ip "[[ -f /etc/nginx/conf.d/wp.conf ]]"; then
    echo ""
else
    genNginxConf
    ssh $ssh_username@$remote_ip "sudo mkdir -p /etc/nginx/conf.d/"
    scp wp.conf $ssh_username@$remote_ip:~/wp.conf
    ssh $ssh_username@$remote_ip "sudo mv ~/wp.conf /etc/nginx/conf.d/wp.conf"
fi

# Copy the docker-compose.yml file to the remote machine
if ssh $ssh_username@$remote_ip "[[ -f ~/docker-compose.yml ]]"; then
    echo "updating php version"
    ssh $ssh_username@$remote_ip "sed -i 's/wordpress:.*/wordpress:$php_version-fpm-alpine/' docker-compose.yml"
    ssh $ssh_username@$remote_ip "cd ~/ && docker compose up -d wp"
    ssh $ssh_username@$remote_ip "docker image prune -af"
else
    genDockerCompose
    scp docker-compose.yml $ssh_username@$remote_ip:~/docker-compose.yml
fi

# Starting docker container
declare -a containers=(mariadb wp nginx)
for i in "${containers[@]}";do
    if ssh $ssh_username@$remote_ip "sudo docker ps | grep $i > /dev/null"; then
        echo ""
    else
        # If the container is not running, start it
        ssh $ssh_username@$remote_ip "cd ~/ && sudo docker compose up -d $i"
    fi
done
