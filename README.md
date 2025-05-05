Nu uita să-i dai permisiuni de execuție pe server:
chmod +x lamp_secure_blockroot.sh

Apoi rulează-l cu:
sudo ./lamp_secure_blockroot.sh
sau
sudo bash lamp_secure_blockroot.sh

Daca phpMyAdmin da eroare la rulare, se va inlocui linia 165, astfel: sudo nano /etc/phpmyadmin/config.inc.php
cu
$cfg['Servers'][$i]['AllowRoot'] = false;
