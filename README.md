Nu uita să-i dai permisiuni de execuție pe server:
chmod +x lamp_secure_blockroot.sh

Apoi rulează-l cu:
sudo ./lamp_secure_blockroot.sh
sau
sudo bash lamp_secure_blockroot.sh

Daca phpMyAdmin da eroare la rulare, se va inlocui linia 165, astfel: sudo nano /etc/phpmyadmin/config.inc.php
cu
$cfg['Servers'][$i]['AllowRoot'] = false;

Daca nu se poate accesa phpMyAdmin primind eroarea: mysqli::real_connect(): (HY000/1045): Access denied for user 'utilizator'@'localhost' (using password: YES)
atunci
CREATE USER 'utilizator'@'localhost' IDENTIFIED BY 'oParolaBlana123!';
GRANT ALL PRIVILEGES ON *.* TO 'utilizator'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
