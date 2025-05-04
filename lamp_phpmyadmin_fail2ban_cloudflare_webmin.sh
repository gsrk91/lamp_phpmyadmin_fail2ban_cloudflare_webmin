#!/bin/bash

echo "=== LAMP + phpMyAdmin + Fail2Ban Setup cu protecție HTTP Basic ==="

# Citire parolă MariaDB root
read -s -p "Introduceți parola pentru MariaDB root: " MYSQL_ROOT_PASS
echo
# Citire user și parolă HTTP Basic
read -p "Introduceți username pentru protecția HTTP Basic (phpMyAdmin): " HTTP_USER
read -s -p "Introduceți parola pentru acest user: " HTTP_PASS
echo

# Update și upgrade
apt update && apt upgrade -y

# Instalare LAMP stack + utilitare
apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-cli php-curl php-xml php-mbstring unzip curl apache2-utils fail2ban

# Activare servicii
systemctl enable --now apache2
systemctl enable --now mariadb
systemctl enable --now fail2ban

# Configurare MariaDB securizată
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host!='localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Fișier test PHP
cat <<EOL > /var/www/html/info.php
<?php
phpinfo();
?>
EOL

# Instalare phpMyAdmin
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_ROOT_PASS" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_ROOT_PASS" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_ROOT_PASS" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
apt install -y phpmyadmin

# Activare .htaccess și mod_rewrite
a2enmod rewrite

# Protecție HTTP Basic pentru phpMyAdmin
htpasswd -cb /etc/apache2/.htpasswd "$HTTP_USER" "$HTTP_PASS"

# Adaugă protecție în configurarea Apache pentru phpMyAdmin
cat <<EOL > /etc/apache2/conf-available/phpmyadmin.conf
Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
    Options SymLinksIfOwnerMatch
    DirectoryIndex index.php

    <IfModule mod_authz_core.c>
        Require all granted
    </IfModule>

    AuthType Basic
    AuthName "phpMyAdmin Secure"
    AuthUserFile /etc/apache2/.htpasswd
    Require valid-user
</Directory>
EOL

a2enconf phpmyadmin
systemctl restart apache2

# Permisiuni corecte
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Fail2Ban configurare pentru Apache
cat <<EOL > /etc/fail2ban/jail.local
[apache-auth]
enabled = true
port    = http,https
filter  = apache-auth
logpath = /var/log/apache2/error.log
maxretry = 3
bantime = 3600
findtime = 600

[phpmyadmin]
enabled = true
port     = http,https
filter   = phpmyadmin
logpath  = /var/log/apache2/error.log
maxretry = 3
bantime = 3600
findtime = 600
EOL

# Filtru Fail2Ban pentru phpMyAdmin brute force
cat <<EOL > /etc/fail2ban/filter.d/phpmyadmin.conf
[Definition]
failregex = .*client denied by server configuration:.*phpmyadmin.*
ignoreregex =
EOL

# Restart Fail2Ban
systemctl restart fail2ban

# UFW firewall
ufw allow 'OpenSSH'
ufw allow 'Apache Full'
ufw --force enable

echo "Instalare LAMP completă cu protecție HTTP Basic și Fail2Ban activ. Accesează http://<ip-server>/phpmyadmin"


# Instalare actualizări automate de securitate
apt install -y unattended-upgrades apt-listchanges
dpkg-reconfigure -f noninteractive unattended-upgrades

# Activare auto-upgrade complet (zilnic)
cat <<EOL > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Autoremove "1";
EOL

# Instalare Webmin
echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
wget -qO - http://www.webmin.com/jcameron-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/webmin.gpg
apt update
apt install -y webmin

# Activare Webmin în firewall
ufw allow 10000/tcp

echo "Webmin este instalat la https://<ip-server>:10000"
echo "Instalare completă cu actualizări automate și suport Webmin."
