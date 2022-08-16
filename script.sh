#!/bin/bash

set -eu

trap cleanup EXIT

#
# Wait for internet connection
wait_internet() {
    echo "Waiting for network connection."
    while [ 1 ]; do
      if ping -q -c 1 -W 1 8.8.8.8 > /dev/null 2>&1; then
        break;
      fi
      sleep 1
    done 
}

#
# Install initial dependencies
install_dependencies() {
    # Update System
    sudo apt-get update

    # Install basic system packages
    sudo apt-get -yq install zip php-cli curl git
    
    # remove apache2 if already installed
    sudo apt-get -yq --purge remove apache2
    
    # Install nginx
    sudo apt-get -yq install nginx
    
    # remove index.nginx-debian.html
    rm -f /var/www/html/*
}

#
# Install composer
install_composer() {
    #
    # install composer
    sudo curl -sS https://getcomposer.org/installer | sudo php

    # remove the 2.* version
    sudo rm -f composer.phar

    # download v1.10.19
    sudo wget https://getcomposer.org/download/1.10.19/composer.phar

    # add execute bit and move into place
    sudo chmod +x composer.phar
    sudo mv composer.phar /usr/local/bin/composer

    # remove link
    sudo rm -f /usr/bin/composer
    sudo ln -s /usr/local/bin/composer /usr/bin/composer
}

#
# Install project with composer
install_project_git() {
    # make webroot and move into it
    mkdir -p /var/www/html && cd /var/www/html
    
    # clone the repo
    git clone git@bitbucket.org:wightsystems/conext.git .
    
    # setup project
    bash ./.api/files/setup.sh
}

#
# Install lxd
install_lxd() {
    # remove apt based LXD
    sudo apt-get -y remove lxd
    #
    sudo apt-get -y install zfsutils-linux
    #
    export PATH=/usr/bin:/bin:/snap/bin:$PATH
    
    #
    set -eo pipefail

    # install snapd
    sudo apt-get -y install snapd
    
    # install lxd snap package
    sudo snap install lxd
    
    #
    ln -s /snap/bin/lxc /usr/bin/lxc
    
    #
    sudo lxd waitready
    
    # initialise lxd (make sure you allow lxd over network - or the console wont work)
    sudo lxd init --auto --network-address 0.0.0.0 --network-port 8443 --storage-backend=dir

    # check lxd group is added
    if [ ! $(getent group lxd) ]; then
        addgroup lxd
    fi
    
    # add www-data to lxd group (seeded by nginx)
    sudo usermod -a -G lxd www-data
}

#
# Add www-data to sudoers so can run lxc commands
write_sudoers() {
    #
    cp /etc/sudoers /etc/sudoers.bak
    cp /etc/sudoers /etc/sudoers.tmp
    
    #
    chmod 0640 /etc/sudoers.tmp
    
    #
    echo -e "\nwww-data ALL=(ALL:ALL) NOPASSWD: /usr/bin/lxc\nwww-data ALL=(ALL:ALL) NOPASSWD: /snap/bin/lxc\n" >> /etc/sudoers.tmp
    
    #
    chmod 0440 /etc/sudoers.tmp
    
    #
    mv /etc/sudoers.tmp /etc/sudoers
}

#
##
cleanup() {
    #
    rm -f script.sh
}

#
# Main 
main() {
    # Check is root user
    if [[ $EUID -ne 0 ]]; then
       echo "This project must be install with root user."
       sudo su
    fi
    
    wait_internet
    
    install_dependencies
    
    install_lxd
    
    write_sudoers
    
    install_composer
    
    install_project_git
}

main
