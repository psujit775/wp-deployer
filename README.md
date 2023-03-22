# wp-deployer
A Bash script to automate the deployment of MariaDB, WordPress, and Nginx to a remote machine. The script also has the ability to upgrade the WordPress docker image without data loss.

This repo consist two bash scripts. `wp-deployer.sh` is resposible for installing docker and running containers of **mariadb**, **wordpress** and **Nginx** on remote machine.

You can use `wp-uninstaller.sh` is case you want to revert everything from stopping conatiners, deleting data and uninstalling the docker from the remote machine. **use with caution**.

## Prerequisite
You should have already set up passwordless SSH authentication.

## Usage:
Make the script executable by running below command.

`chmod +x wp-deployer.sh`

### To run the script use the below command.
</br>

./wp-deployer.sh \<remote server ip> \<user name> \<php version>

</br>

**Example**:

`./wp-deployer.sh 52.66.251.182 ubuntu php7.2`