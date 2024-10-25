#!bin/bash
#the print_color functions helps to identify if a service is installed or running with the help of colors.
function print_color() {
  case $1 in
  "green") COLOR="\033[0;32m"
  ;;
  "red") COLOR="\033[0;31m"
  ;;
  "*") COLOR="\033[0m"
  ;;
  esac
  echo -e "${COLOR} $2 ${NC}"
}

function active_state() {
 is_service_active=$(systemctl is-active $1)
if [ $is_service_active = "active" ]
then
  print_color "green" "$1 is active"
else
  print_color "red" "$1 is not running"
  exit 1
fi
}

function firewalld_port_rule() {
if [[ $firewalld_ports = *$1* ]]
then 
    print_color "green" "port $1 configured"
else
    print_color "red" "port $1 not configured"
    exit 1
fi
}

function check_item() {
  webpage=$(curl http://localhost)

if [[ $1 = *$2* ]]
then
  print_color "green" "Item $2 is available"
else 
    print_color "red" "Item $2 is not available"
fi
}
#---------Database configuration--------------
#install and configure FirewallD

print_green "installing firewalld"
sudo yum install -y firewalld
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo systemctl status firewalld

active_state firewalld


#Install and configure MariaDB
print_green "install and start mariaDB"
sudo yum install -y mariadb-server
sudo systemctl start mariadb
sudo systemctl enable mariadb
active_state mariadb

#Add FirewallD rules for database
print_green "add firewall rules to db"
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload
firewalld_port_rule 3306

#configure DB
print_green "configuring DB..."
cat > configure-db.sql <<-EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
EOF
sudo mysql < configure-db.sql

#loading inventory data
print_green "loading inventory data"
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");
EOF

sudo mysql < db-load-script.sql

mysql_result=$(sudo mysql -e "use ecomdb; select * from products;")
if [[ $mysql_results = *Laptop* ]]
then
    print_color "green" "inventory data loaded"
else
    print_color "red" "inventory data not loaded."
fi

#------web-server-configuration----------------------
print_green "configuring web-server"
#install apache web server and php
sudo yum install -y httpd php php-mysqlnd

#configure firewall rule for web server
print_green "configuring firewalld rule for webserver.."
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload
firewalld_port_rule 80


#start and enable httpd service
print_green "starting web-service..."
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf
sudo systemctl start httpd
sudo systemctl enable httpd
active_state httpd

#install git and download source code repo
print_green "cloning repo"
sudo yum install -y git
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/


#replace databse IP with localhost
sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php

#test web server if it is running
print_green "All set!"
web_page=$(curl http://localhost)
check_item $web_page Drone
check_item $web_page Laptop
check_item $web_page VR

for item in Laptop Drone VR Watch
do
    check_item $web_page $item
done