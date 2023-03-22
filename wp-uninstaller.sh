#!/bin/bash
## Usage: ./wp-uninstaller.sh <remote server ip> <user name>
## Example: ./wp-uninstaller.sh 52.66.251.182 ubuntu
## Note: You should have already set up passwordless SSH authentication.

remote_ip=$1

ssh_username=$2

# Remove the WordPress container
ssh $ssh_username@$remote_ip "cd ~/ && sudo docker compose down"

# Remove the docker-compose.yml file
ssh $ssh_username@$remote_ip "cd ~/ && rm docker-compose.yml"

# Uninstall Docker and Docker Compose
ssh $ssh_username@$remote_ip "sudo apt-get purge -y docker-ce docker-ce-cli containerd.io"
ssh $ssh_username@$remote_ip "sudo rm -rf /var/lib/docker /etc/docker"
ssh $ssh_username@$remote_ip "sudo rm -rf /etc/systemd/system/docker.service.d"
ssh $ssh_username@$remote_ip "rm -rf ~/.db-data/ ~/wordpress_data/"
ssh $ssh_username@$remote_ip "sudo rm -rf /var/log/nginx /etc/nginx"

