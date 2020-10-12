
#!/usr/bin/env bash

echo -e "\nChecking that minimal requirements are ok"

#Ensure the OS is compatible with the launcher
if [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
elif [ -f /etc/os-release ]; then
    OS=$(grep -w ID /etc/os-release | sed 's/^.*=//')
    VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/')
 else
    OS=$(uname -s)
    VER=$(uname -r)
fi
ARCH=$(uname -m)

echo "Detected : $OS  $VER  $ARCH"

if [[ "$OS" = "Ubuntu" ]] ; then
	echo "Ok."
else
    echo "Sorry, this OS is not supported." 
    exit 1
fi

echo -e "\nCheck if the user is 'root' before allowing installation to commence"
if [ $UID -ne 0 ]; then
    echo "Install failed: you must be logged in as 'root' to install."
    echo "Use command 'sudo -i', then enter root password and then try again."
    exit 1
fi

if [[ "$OS" = "Ubuntu" || "$OS" = "debian" ]]; then
    apt-get -yqq update   #ensure we can install
fi

while true; do
	read -e -p "All is ok. Do you want to setup now (y/n)? " yn
	case $yn in
	    [Yy]* ) break;;
	    [Nn]* ) exit;;
	esac
done

uname -a

echo -e "\nInstall PHP 7.4"

if [[ "$VER" == "20.04" ]] ; then
	sudo apt install -y php php-cli php-fpm php-json php-pdo php-mysql php-zip php-gd  php-mbstring php-curl php-xml php-pear php-bcmath
else
	apt -y install software-properties-common
	add-apt-repository ppa:ondrej/php
	apt-get -yqq update
fi


echo -e "\nStop and disable Apache service"
sudo systemctl disable --now apache2

echo -e "\nInstall Nginx"
sudo apt-get install -y nginx php7.4-fpm

echo -e "\nUnzip Zip"
sudo apt-get -y install unzip zip

echo -e "\nUpdate"
sudo apt-get update

echo -e "\nRemove default Nginx host"

rm -f /etc/nginx/sites-enabled/*
rm -f /etc/nginx/sites-available/*


echo -e "\nCreate default host"

while true; do
    read -e -p "Enter domain: " domain
    break;
done

rootdir="/var/www/html/$domain"

sudo mkdir -p $rootdir

cat <<EOF > /etc/nginx/sites-available/$domain
# Application with PHP 4.2
#
server {
    listen 80;
    listen 443 ssl http2;
    root $rootdir;
    index index.php index.html;
    server_name $domain;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    charset utf-8;
    sendfile off;
    client_max_body_size 100m;
    location ~* \.php\$ {
        # With php-fpm unix sockets
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_index   index.php;
        include         fastcgi_params;
        fastcgi_param   SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;
        fastcgi_param   SCRIPT_NAME        \$fastcgi_script_name;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/

sudo systemctl restart nginx


# Wait until the user have read before restarts the server...
while true; do
    read -e -p "Restart your server now to complete the install (y/n)? " rsn
    case $rsn in
        [Yy]* ) break;;
        [Nn]* ) exit;
    esac
done
shutdown -r now