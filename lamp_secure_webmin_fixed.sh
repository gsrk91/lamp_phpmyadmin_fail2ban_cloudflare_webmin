
#!/bin/bash

echo "=== Instalare LAMP + phpMyAdmin + Fail2Ban + Webmin + Hardening Securitate ==="

# Citire parolă MariaDB root
read -s -p "Introduceți parola pentru MariaDB root: " MYSQL_ROOT_PASS
echo
read -p "Introduceți username pentru protecția HTTP Basic (phpMyAdmin): " HTTP_USER
read -s -p "Introduceți parola pentru acest user: " HTTP_PASS
echo

# Update și upgrade
apt update && apt upgrade -y

# Instalare pachete
apt install -y apache2 mariadb-server php libapache2-mod-php php-mysql php-cli php-curl php-xml php-mbstring php-opcache unzip curl apache2-utils fail2ban unattended-upgrades apt-listchanges wget gnupg2

# Activare servicii
systemctl enable --now apache2 mariadb fail2ban

# Configurare securizată MariaDB
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';"
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
a2enmod rewrite headers ssl

# Protecție HTTP Basic
htpasswd -cb /etc/apache2/.htpasswd "$HTTP_USER" "$HTTP_PASS"

# Config Apache pentru phpMyAdmin
cat <<EOL > /etc/apache2/conf-available/phpmyadmin.conf
Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
    Options -Indexes +FollowSymLinks
    DirectoryIndex index.php
    AllowOverride All

    AuthType Basic
    AuthName "phpMyAdmin Secure"
    AuthUserFile /etc/apache2/.htpasswd
    Require valid-user
</Directory>
EOL

a2enconf phpmyadmin
systemctl restart apache2

# Permisiuni
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Fail2Ban - Apache, SSH, phpMyAdmin
cat <<EOL > /etc/fail2ban/jail.local
[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log
maxretry = 3

[apache-auth]
enabled = true
port    = http,https
filter  = apache-auth
logpath = /var/log/apache2/error.log
maxretry = 3

[phpmyadmin]
enabled = true
port     = http,https
filter   = phpmyadmin
logpath  = /var/log/apache2/error.log
maxretry = 3
EOL

cat <<EOL > /etc/fail2ban/filter.d/phpmyadmin.conf
[Definition]
failregex = .*client denied by server configuration:.*phpmyadmin.*
ignoreregex =
EOL

systemctl restart fail2ban

# Hardening Apache headers
cat <<EOL > /etc/apache2/conf-available/security-hardening.conf
Header always set X-Content-Type-Options "nosniff"
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
EOL

a2enconf security-hardening
systemctl reload apache2

# Activare actualizări automate
dpkg-reconfigure -f noninteractive unattended-upgrades
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
ufw allow 10000/tcp

# Firewall UFW
ufw allow 'OpenSSH'
ufw allow 'Apache Full'
ufw --force enable

# Cleanup
apt autoremove -y
apt autoclean

echo "✅ Instalare completă cu optimizare, securitate și Webmin. Accesează http://<IP>/phpmyadmin și https://<IP>:10000 pentru Webmin."
