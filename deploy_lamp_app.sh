#!/bin/bash

# This script installs all necessary packages and tools for a Laravel project
# Clones a PHP application from GitHub and Configures Apache Web server and MySQL

# Colors
Color_Off='\033[0m'       # default
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Cyan='\033[0;36m'         # Cyan

# Function to handle possible errors
error() {
    echo "Error: $1"
    exit 1
}

# Variables
REPO_LINK="$1"
REPO_LINK_CUT=${REPO_LINK%.git}
PROJECT_NAME=$(echo "$REPO_LINK_CUT" | cut -d '/' -f 5)
SITE_CONFIG="<VirtualHost *:80>
    ServerName '$PROJECT_NAME'.com
    DocumentRoot /var/www/$PROJECT_NAME/public

    <Directory /var/www/demo/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/$PROJECT_NAME-error.log
    CustomLog ${APACHE_LOG_DIR}/$PROJECT_NAME-access.log combined
</VirtualHost>"

# Check if the repo link is given
if [ -z "$1" ]; then
    echo "Please provide the GitHub repository link as an argument."
    exit 1
fi

# Update packages and Upgrade system
echo -e "$Cyan \n Updating System.. $Color_Off"
sudo apt update -y

# Installing php8.2
echo -e "$Cyan \n Checking & Installing PHP.. $Color_Off"
sudo add-apt-repository ppa:ondrej/php --yes
sudo apt update
sudo apt install php8.2 -y
php --version
echo -e "$Green \n Successfuly installed Php8.2"

# Install other LAMP Stack tools
echo -e "$Cyan \n Checking & Installing tools.. $Color_Off"
sudo apt install apache2 mysql-server git -y

# Install common PHP dependencies
echo -e "$Cyan \n Checkng & Installing dependencies.. $Color_Off"
sudo apt-get install -y php8.2-cli php8.2-common php8.2-fpm php8.2-mysql php8.2-zip php8.2-gd php8.2-mbstring php8.2-curl php8.2-xml php8.2-bcmath
# Install dependencies required by Laravel
sudo apt install php8.2-curl php8.2-dom php8.2-mbstring php8.2-xml php8.2-mysql zip unzip -y

# Configuring Apache
sudo a2enmod rewrite
sudo service apache2 restart

# Setup Composer
echo -e "$Cyan \n Setting up Composer.. $Color_Off"
cd /usr/local/bin
curl -sS https://getcomposer.org/installer | sudo php
sudo mv composer.phar composer
echo -e "$Green \n Composer setup complete.. $Color_Off"

# Clone PHP App
sudo find /var/www/ -mindepth 1 -delete
cd /var/www/
sudo git clone $REPO_LINK || error "$Red \n Failed to clone the repository. $Color_Off"
echo -e "$Green \n Successfully Cloned.. $Color_Off"

cd "$PROJECT_NAME"
sudo composer update --no-interaction

# APACHE and MYSQL CONFIGURATIONS

# Setup ENV file and generate app key
echo -e "$Cyan \n Configuring Apache and Mysql $Color_Off"
sudo cp .env.example .env
sudo sed -i "1 s/=Laravel/="$PROJECT_NAME"/" /var/www/"$PROJECT_NAME"/.env
sudo php artisan key:generate

# Set www-data as owner of staorage and boostrap directories
sudo chown -R www-data storage
sudo chown -R www-data bootstrap/cache

# Apache configurations
cd /etc/apache2/sites-available/
sudo sh -c "echo '$SITE_CONFIG' >> '${PROJECT_NAME}.conf'" || error "Could not create .conf file"
echo -e "$Cyan \n Config file created... $Color_Off"

sudo a2ensite "${PROJECT_NAME}.conf"
sudo systemctl restart apache2
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
echo -e "$Cyan \n Sites enabled and running... $Color_Off"

# Create database and configure MySQL
echo -e "$Cyan \n Setting up database $Color_Off"
cd ~
sudo systemctl start mysql
sudo mysql -uroot -e "CREATE DATABASE "${PROJECT_NAME}_db";"
sudo mysql -uroot -e "CREATE USER 'myuser'@'localhost' IDENTIFIED BY 'mypassword';"
sudo mysql -uroot -e "GRANT ALL PRIVILEGES ON "${PROJECT_NAME}_db".* TO 'myuser'@'localhost';"
sudo mysql -uroot -e "FLUSH PRIVILEGES;"
echo -e "$Green \n Database setup success... $Color_Off"

# Edit .env file to add database data
cd /var/www/"$PROJECT_NAME"

sudo sed -i "23 s/^#//g" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "24 s/^#//g" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "25 s/^#//g" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "26 s/^#//g" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "27 s/^#//g" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "22 s/=sqlite/=mysql/" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "23 s/=127.0.0.1/=localhost/" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "24 s/=3306/=3306/" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "25 s/=laravel/="${PROJECT_NAME}_db"/" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "26 s/=root/=myuser/" /var/www/"$PROJECT_NAME"/.env
sudo sed -i "27 s/=/=mypassword/" /var/www/"$PROJECT_NAME"/.env
echo -e "$Green \n Database linked.. $Color_Off"

# Migrate database and reload apache. This should ensure site is up
sudo php artisan migrate || error "$Red \n Deployment process encountered an error $Color_Off"
sudo systemctl reload apache2

echo -e "$Green \n ===== DEPLOYMENT COMPLETE ====="
echo " "