#!/usr/bin/bash
#
# On the pi4, the GPIO edge triggers are screwed in Bookwork, bypass that:
# sudo apt remove -y python3-rpi.gpio && sudo apt update -y && sudo apt install -y python3-rpi-lgpio
#
sudo mkdir -p /logs
sudo chown -R pi:pi /logs
sudo chmod 777 /logs
export logfile=/logs/install.log
echo "" >$logfile

# Error management
set -o errexit
set -o pipefail
#set -o nounset

usage() {
    cat 1>&2 <<EOF

This script configures a base Pi with OS updates, darkweb software and supporting tools.
It provides scripts to also install ExpressVPN as well as the Rasbian desktop. An 
option also exists to install a WiFi access point on a second WiFi adapter.

USAGE:
	$(basename $0) [parameters]

PARAMETERS:
    -base <ROOT>  The root to use from git and in webroot
	-ge <EMAIL>   Your git registered email address. Default: nigel@nigeljohnson.net
	-gn <NAME>    Your pretty name for git checking in. Default: "Nigel Johnson"
	-gp <PASS>    The Personal Access Token you made on github 
	-kiosk        Enable Kiosk - auto login: a screen is attached (terminal by default)
	-python       Use python infrastructure
	-samba        Enable Samba (for accessing the webfiles on your local network)
	-ssd          Boot order: SSD -> SD Card
	-tor          Enable TOR (and web services)
	-web          Enable web services (and config chromium if in kiosk mode)
	-xwin         Enable xwindows in kiosk mode
	-nowin        Disable xwindows in kiosk mode (if you're using web things)
    -onion        Enable the onion hunt for address
    -zero         Setting up a zero - don't any some weird stuff
    -zero2        Setting up a zero2 - Like the zero, but with more overclocking
    -pi3          Setting up a pi3 - don't do some weird stuff
    -pi4          Setting up a pi4 - weird stuff is it's middle name (boot loader etc)
    -pi5          Setting up a pi5 - wooooo

	-h | --help Show this help and exit
	
    NOTE: If you want a kiosk, then enabling the web services will also install XWin as 
      well. You can install XWin separately if you're running scripts that interact 
      with it.

        * kiosk = a shell script terminal based application
        * kiosk + python = a terminal running a python application
        * kiosk + tor = (+web +xwin) a chromium front end with tor broadcast
        * kiosk + web = (+xwin) a local chromium front end
        * kiosk + xwin = a shell script application with XWindows
        * kiosk + python + xwin = a python application with xwin interface

      In kiosk mode you need a res/startup_term.sh script that is called when the pi 
      boots. This is created automatically if one is not provided. Python is a bit 
      finnnicky so it will also set up the operating environment and then go look for 
      res/startup_app.py which should be supplied in the source tree.

	NOTE: If you want to configure the wifi, you will need to supply the remote side
	  SSID and passphrase. You will also need to have a wifi dongle plugged in
	  and presenting itself as 'wlan1' in your ifconfig

EOF
}
die() {
    [ -n "$1" ] && echo -e "\nError: $1\n" >&2
    usage
    [ -z "$1" ]
    exit
}

BASE="darkpi"
BOOT="0xf41"
BOOT_ORDER="SD Card -> SSD"
GIT_USERMAIL="nigel@nigeljohnson.net"
GIT_USERNAME="Nigel Johnson"
GIT_PAT=""
KIOSK="no"
SAMBA="no"
TOR="no"
WEB="no"
XWIN="no"
PYTHON="no"
ONION="no"
NOWIN="no"
ZERO="no"
ZERO2="no"
PI3="no"
PI4="no"
PI5="no"

MODEL=$(tr -d '\0' </proc/device-tree/model)
if [[ "$MODEL" == *"Zero W"* ]]; then ZERO="yes"; fi
if [[ "$MODEL" == *"Zero 2 W"* ]]; then ZERO2="yes"; fi
if [[ "$MODEL" == *"Pi 4 Model B"* ]]; then PI4="yes"; fi
if [[ "$MODEL" == *"Pi 5 Model B"* ]]; then PI5="yes"; fi
if [[ "$MODEL" == *"Pi 3 Model B"* ]]; then PI3="yes"; fi

while [[ $# -gt 0 ]]; do
    case $1 in
    -base)
        BASE="$2"
        echo "BASE: '$2'"
        shift
        ;;
    -ge)
        GIT_USERMAIL="$2"
        echo "GIT email address: '$2'"
        shift
        ;;
    -gn)
        GIT_USERNAME="$2"
        echo "GIT name: '$2'"
        shift
        ;;
    -gp)
        GIT_PAT="$2"
        echo "GIT PAT: '$2'"
        shift
        ;;
    -kiosk)
        KIOSK="yes"
        echo "Kiosk mode: '$KIOSK'"
        ;;
    -python)
        PYTHON="yes"
        echo "Python services: '$PYTHON'"
        ;;
    -samba)
        SAMBA="yes"
        echo "SAMBA services: '$SAMBA'"
        ;;
    -ssd)
        BOOT="0xf14"
        BOOT_ORDER="SSD -> SD Card"
        echo "boot order '($BOOT) $BOOT_ORDER'"
        ;;
    -tor)
        TOR="yes"
        echo "TOR services: '$TOR'"
        if [ "$WEB" = "no" ]; then
            WEB="yes"
            echo "Web services: '$WEB'"
        fi
        ;;
    -web)
        WEB="yes"
        echo "Web services: '$WEB'"
        ;;
    -xwin)
        if [ "$KIOSK" = "no" ]; then
            KIOSK="yes"
            echo "Kiosk mode: '$KIOSK'"
        fi
        XWIN="yes"
        echo "X-Windows services: '$XWIN'"
        ;;
    -nowin)
        if [ "$KIOSK" = "no" ]; then
            KIOSK="yes"
            echo "Kiosk mode: '$KIOSK'"
        fi
        XWIN="no"
        NOWIN="yes"
        echo "X-Windows services: '$XWIN'"
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    -onion)
        ONION="yes"
        echo "Onion search: '$ONION'"
        ;;
    -zero)
        PI5="no"
        PI4="no"
        PI3="no"
        ZERO2="no"
        ZERO="yes"
        echo "Zero build: '$ZERO'"
        ;;
    -zero2)
        PI5="no"
        PI4="no"
        PI3="no"
        ZERO="no"
        ZERO2="yes"
        echo "Zero2 build: '$ZERO2'"
        ;;
    -pi3)
        PI5="no"
        PI4="no"
        PI3="yes"
        ZERO2="no"
        ZERO="no"
        echo "PI3 build: '$PI3'"
        ;;
    -pi4)
        PI5="no"
        PI4="yes"
        PI3="no"
        ZERO2="no"
        ZERO="no"
        echo "PI4 build: '$PI4'"
        ;;
    -pi5)
        PI5="yes"
        PI4="no"
        PI3="no"
        ZERO2="no"
        ZERO="no"
        echo "PI5 build: '$PI5'"
        ;;
    *)
        die "Unknown option '$1'"
        ;;
    esac
    shift
done

#[ -z "$GIT_PAT" ] && die "PAT for git access not configured"
#[ -z "$GIT_USERNAME" ] && die "git check-in name not configured"
#[ -z "$GIT_USERMAIL" ] && die "git check-in email address not configured"

echo ""
echo "####################################################################" | tee -a $logfile
echo "##" | tee -a $logfile
echo "## The configuration we will be using today:" | tee -a $logfile
echo "##" | tee -a $logfile
echo "##          Hardware : '${MODEL}'" | tee -a $logfile
echo "##         PI5 Build : '${PI5}'" | tee -a $logfile
echo "##         PI4 Build : '${PI4}'" | tee -a $logfile
echo "##       Zero2 Build : '${ZERO2}'" | tee -a $logfile
echo "##         PI3 Build : '${PI3}'" | tee -a $logfile
echo "##        Zero Build : '${ZERO}'" | tee -a $logfile
echo "##        Boot order : '${BOOT_ORDER}'" | tee -a $logfile
echo "##     Software root : '${BASE}'" | tee -a $logfile
if [[ -n "$GIT_PAT" ]]; then
    echo "## GIT email address : '${GIT_USERMAIL}'" | tee -a $logfile
    echo "##  GIT checkin name : '${GIT_USERNAME}'" | tee -a $logfile
    echo "##  GIT access token : '${GIT_PAT}'"
else
    echo "##        GIT access : 'READ-ONLY" | tee -a $logfile
fi
echo "##    Python enabled : '${PYTHON}'" | tee -a $logfile
echo "##     Kiosk enabled : '${KIOSK}'" | tee -a $logfile
echo "##     Onion enabled : '${ONION}'" | tee -a $logfile
echo "##     SAMBA enabled : '${SAMBA}'" | tee -a $logfile
echo "##       WEB enabled : '${WEB}'" | tee -a $logfile
echo "##       TOR enabled : '${TOR}'" | tee -a $logfile
echo "##         X enabled : '${XWIN}'" | tee -a $logfile

APT_INSTALL="lsb-release apt-transport-https ca-certificates git automake autoconf pkg-config libcurl4-openssl-dev libjansson-dev libssl-dev libgmp-dev make g++ vim python3-pyqrcode qrencode"

if [ "$PYTHON" = "yes" ]; then
    APT_INSTALL="$APT_INSTALL python3-dev python3-pip python3-setuptools python3-wheel python3-pil libpcap-dev libgpgme-dev rustc swig"
fi

if [ "$XWIN" = "yes" ]; then
    APT_INSTALL="$APT_INSTALL screen xserver-xorg x11-xserver-utils xinit openbox chromium-browser xserver-xorg-input-evdev libhdf5-dev libhdf5-serial-dev python3-pyqt5 libatlas-base-dev libgtk2.0-dev pkg-config"
fi

if [ "$WEB" = "yes" ]; then
    APT_INSTALL="$APT_INSTALL nginx php-fpm"
fi

if [ "$TOR" = "yes" ]; then
    APT_INSTALL="$APT_INSTALL tor"
fi

if [ "$SAMBA" = "yes" ]; then
    APT_INSTALL="$APT_INSTALL samba samba-common-bin"
fi

if [ "$ONION" = "yes" ]; then
    APT_INSTALL="$APT_INSTALL  gcc libc6-dev libsodium-dev make autoconf"
fi

echo "##" | tee -a $logfile
echo "####################################################################" | tee -a $logfile
echo "" | tee -a $logfile
echo "Shall we get started? Press return to continue"
echo ""
read ok

echo "## Update BIOS and core OS" | tee -a $logfile
echo "" | tee -a $logfile

# Ensure the base packages are up to date
echo "## Update core OS" | tee -a $logfile
sudo apt update -y
echo "## Ensure we have latest firmware available" | tee -a $logfile
sudo apt full-upgrade -y
echo "## Cleanup loose packages" | tee -a $logfile
sudo apt autoremove -y

# if [ "$ZERO" = "no" -a "$ZERO2" = "no" -a "$PI3" = "no" ]; then
if [ "$PI4" = "yes" -o "$PI5" = "yes" ]; then
    echo "## Ensure we have latest firmware installed on a PI4" | tee -a $logfile
    sudo rpi-eeprom-update -a -d
    echo "## Update the bootloader order" | tee -a $logfile
    cat >/tmp/boot.conf <<EOF
[all]
BOOT_UART=0
WAKE_ON_GPIO=1
ENABLE_SELF_UPDATE=1
BOOT_ORDER=$BOOT
EOF
    sudo rpi-eeprom-config --apply /tmp/boot.conf
fi

# Install core packages we need to do the core stuff later
echo "## Install pacakges" | tee -a $logfile
echo "##     $APT_INSTALL" | tee -a $logfile
sudo apt install -y $APT_INSTALL

echo "## Enable syntax highlighting in VI" | tee -a $logfile
sudo find /etc/vim/vimrc -exec sed -i 's/^"syntax on/syntax on/g' '{}' \;

echo "## Disabling IPv6" | tee -a $logfile
sudo nmcli connection modify preconfigured ipv6.method ignore ipv6.ip6-privacy 0 connection.autoconnect yes | tee -a $logfile
# if [ -f "/etc/sysctl.conf" ]; then
#     cat /etc/sysctl.conf | grep -v disable_ipv6 >/tmp/ip6
#     echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/tmp/ip6
#     sudo mv /tmp/ip6 /etc/sysctl.conf
# fi

echo "## Setting system terminal font" | tee -a $logfile
sudo bash -c 'cat > /etc/default/console-setup' <<EOF
# CONFIGURATION FILE FOR SETUPCON
ACTIVE_CONSOLES="/dev/tty1"
CHARMAP="UTF-8"
CODESET="guess"
FONTFACE="Terminus"
FONTSIZE="6x12"
VIDEOMODE=
EOF

echo "## Setting up bash_profile" | tee -a $logfile
# On login, if we are not attached to a terminal, launch the X display system
bash -c 'cat > ~/.bash_profile' <<EOF
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi
EOF

#############
## The Software
##
# The software is held in github so set that up and clone it to the right place
if [ ! -d "/webroot" ]; then
    echo "## Creating web root folder" | tee -a $logfile
    sudo mkdir -p /webroot
fi
cd /webroot

if [ ! -d "$BASE" ]; then
    echo "## Cloning $BASE source code tree" | tee -a $logfile
    if [[ -n "$GIT_PAT" ]]; then
        git config --global credential.helper store
        git config --global user.email $GIT_USERMAIL
        git config --global user.name $GIT_USERNAME
        sudo git clone https://${GIT_PAT}:x-oauth-basic@github.com/nigeljohnson73/$BASE.git
    else
        sudo git clone https://github.com/nigeljohnson73/$BASE.git
    fi
    sudo chown -R pi:pi $BASE
else
    echo "## $BASE source code tree already exists" | tee -a $logfile
fi
cd $BASE

echo "## Install bashrc hooks" | tee -a $logfile
cat ~/.bashrc | grep -v '/webroot/' >/tmp/bashrc
mv /tmp/bashrc ~/.bashrc
echo "source /webroot/$BASE/res/bashrc" >>~/.bashrc

echo "## Install rc.local hooks" | tee -a $logfile
sudo cat /etc/rc.local | grep -v 'exit 0' | grep -v '/webroot/' | sudo tee /etc/rc.local.tmp >/dev/null
sudo rm /etc/rc.local
sudo mv /etc/rc.local.tmp /etc/rc.local
sudo bash -c 'cat >> /etc/rc.local' <<EOF
. /webroot/$BASE/res/rc.local
exit 0
EOF
sudo chmod 755 /etc/rc.local

if [ "$PI5" = "yes" ]; then
    echo "## Skipping of overclocking PI5" | tee -a $logfile
#     # if [ "$ZERO" = "no" -a "$ZERO2" = "no" -a "$PI3" = "no" ]; then
#     echo "## Overclocking PI5 to 3MHz" | tee -a $logfile
#     sudo sed -i '/# start overclocking/,/# end overclocking/d' /boot/firmware/config.txt
#     # sudo bash -c 'cat >> /boot/config.txt' <<EOF
#     sudo bash -c 'cat >> /boot/firmware/config.txt' <<EOF
# # start overclocking for PI5
# over_voltage_delta=50000
# arm_freq=3000
# gpu_freq=1000
# # end overclocking
# EOF
fi
if [ "$PI4" = "yes" ]; then
    # if [ "$ZERO" = "no" -a "$ZERO2" = "no" -a "$PI3" = "no" ]; then
    echo "## Overclocking PI4 to 2MHz" | tee -a $logfile
    sudo sed -i '/# start overclocking/,/# end overclocking/d' /boot/firmware/config.txt
    # sudo bash -c 'cat >> /boot/config.txt' <<EOF
    sudo bash -c 'cat >> /boot/firmware/config.txt' <<EOF
# start overclocking for PI4
over_voltage=6
arm_freq=2000
gpu_freq=750
# end overclocking
EOF
fi
if [ "$PI3" = "yes" ]; then
    echo "## Overclocking PI3 to 1.5MHz" | tee -a $logfile
    sudo sed -i '/# start overclocking/,/# end overclocking/d' /boot/firmware/config.txt
    # sudo bash -c 'cat >> /boot/config.txt' <<EOF
    sudo bash -c 'cat >> /boot/firmware/config.txt' <<EOF
# start overclocking for PI3
temp_soft_limit=70
force_turbo=1
arm_freq=1500
core_freq=500
gpu_freq=500
over_voltage=6
sdram_freq=500
# end overclocking
EOF
fi
if [ "$ZERO2" = "yes" ]; then
    echo "## Overclocking Zero2 to 1.3MHz" | tee -a $logfile
    sudo sed -i '/# start overclocking/,/# end overclocking/d' /boot/firmware/config.txt
    # sudo bash -c 'cat >> /boot/config.txt' <<EOF
    sudo bash -c 'cat >> /boot/firmware/config.txt' <<EOF
# start overclocking for Zero 2
arm_freq=1300
core_freq=525
over_voltage=6
gpu_freq=700
# end overclocking
EOF
fi
if [ "$ZERO" = "yes" ]; then
    echo "## Overclocking Zero to 1.15MHz" | tee -a $logfile
    sudo sed -i '/# start overclocking/,/# end overclocking/d' /boot/firmware/config.txt
    # sudo bash -c 'cat >> /boot/config.txt' <<EOF
    sudo bash -c 'cat >> /boot/firmware/config.txt' <<EOF
# start overclocking for Zero
arm_freq=1150
over_voltage=6
core_freq=600
sdram_freq=600
over_voltage_sdram=4
# end overclocking
EOF
fi
#####################################################################################
#####################################################################################
#####################################################################################
#####################################################################################
#####################################################################################
#####################################################################################
##
## The point of no return. anything past here needs to be unpicked quite hard. If
## you're not here yet you can just:
## sudo rm -rf /logs /webroot
##

if [ "$KIOSK" = "yes" ]; then
    echo "## Installing KIOSK components" | tee -a $logfile

    if [ ! -f "res/startup_term.sh" ]; then
        # There is a directory sensitivity so generate this file
        if [ "$PYTHON" = "yes" ]; then
            echo "## Building python app startup scripts" | tee -a $logfile

            bash -c 'cat > res/startup_term.sh' <<EOF
cd /webroot/$BASE
# This shouldn't be needed here as it should be in the bashrc - TODO: test this
if [ -f "env/bin/activate" ]; then
    source env/bin/activate
fi

until [ -f "/tmp/app_quit" ]; do
    echo "Starting terminal application..."
    sleep 1
    if [ -f "config.env" ]; then
        set -a
        source config.env
        set +a
    fi

    if [ -f "sh/app.py" ]; then
        python sh/app.py
    else
        echo "No applcation startp could be found."
        touch /tmp/app_quit
    fi

    sleep 1
    clear
done

rm -rf /tmp/app_quit
EOF
        else # A non-python terminal based application needs starting...
            echo "## Building shell app startup scripts" | tee -a $logfile
            bash -c 'cat > res/startup_term.sh' <<EOF
cd /webroot/$BASE
# Nothing to do here yet
EOF
        fi # PYTHON
    fi     # startup_term.sh already exists

    # There is a directory sensitivity so generate this file
    if [ "$WEB" == "yes" ] && [ "$XWIN" = "yes" ]; then
        bash -c 'cat > res/startup_xwin.sh' <<EOF
/usr/bin/chromium-browser --kiosk --noerrdialogs --enable-features=OverlayScrollbar --disable-restore-session-state http://localhost/
# . /webroot/$BASE/res/startup_term.sh
EOF
    else
        bash -c 'cat > res/startup_xwin.sh' <<EOF
# /usr/bin/chromium-browser --kiosk --noerrdialogs --enable-features=OverlayScrollbar --disable-restore-session-state http://localhost/
. /webroot/$BASE/res/startup_term.sh
EOF
    fi

    #############
    ## X Windows
    ##
    if [ "$XWIN" = "yes" ] || ([ "$WEB" = "yes" ] && [ "$NOWIN" = "no" ]); then
        echo "## Installing X-Windows components" | tee -a $logfile
        bash -c 'cat >> ~/.bash_profile' <<EOF

[[ -z "\$DISPLAY" && "\$XDG_VTNR" -eq 1 ]] && startx -- -nocursor
EOF

        # When the Xorg display starts, this is called
        echo "## Setting up openbox autostart" | tee -a $logfile
        sudo bash -c 'cat >> /etc/xdg/openbox/autostart' <<EOF

# Keep screen on
xset -dpms     # Disable DPMS (Energy Star) features
xset s off     # Disable screensaver
xset s noblank # Don't blank video device
# Remove exit errors from the config files that could trigger a warning
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/'Local State'
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"[^"]\+"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences
# Launch the application
. /webroot/$BASE/res/startup_xwin.sh
EOF
    else # XWIN
        echo "## Installing Terminal components" | tee -a $logfile
        bash -c 'cat >> ~/.bash_profile' <<EOF

if [ -f /webroot/$BASE/res/startup_term.sh ]; then
	[[ -z "\$DISPLAY" && "\$XDG_VTNR" -eq 1 ]] && bash /webroot/$BASE/res/startup_term.sh
else
	echo "No Terminal startup config found: '/webroot/$BASE/res/startup_term.sh'"
fi
EOF
    fi # XWIN

    echo "## Setting autologin as pi user (kiosk)" | tee -a $logfile
    sudo systemctl set-default multi-user.target
    sudo ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
    sudo bash -c 'cat > /etc/systemd/system/getty\@tty1.service.d/autologin.conf' <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
EOF
fi # KISOK

if [ "$WEB" = "yes" ]; then
    echo "## Installing WEB components" | tee -a $logfile
    #############
    ## PHP
    ##
    echo "## Installing PHP" | tee -a $logfile
    # # Update the package list with a repository that supports our needs and ensure we are up to date with that
    # echo "## Get repository signature" | tee -a $logfile
    # sudo wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    # echo "## Install ARM repository for latest PHP builds" | tee -a $logfile
    # echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
    # echo "## Ensure we are up to date with that repository" | tee -a $logfile
    # sudo apt update -y
    # echo "## Install out-of-date packages" | tee -a $logfile
    # sudo apt upgrade -y
    # echo "## Remove the latest PHP (v8)" | tee -a $logfile
    # sudo apt remove -y --purge php8.0
    # echo "## Install the required version of PHP (v7.4)" | tee -a $logfile
    # sudo apt install -y nginx php-fpm
    # echo "## Cleanup loose packages" | tee -a $logfile
    # sudo apt autoremove -y

    ## Install composer
    echo "## Install Composer for PHP" | tee -a $logfile
    cd /tmp
    wget -O composer-setup.php https://getcomposer.org/installer
    sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    sudo composer self-update

    ## install the composer dependancies
    if [ -f "composer.json" ]; then
        echo "## Installing composer dependancies" | tee -a $logfile
        composer install
    else
        echo "## No composer dependancies to install" | tee -a $logfile
    fi

    # ## install the mySQL components
    # if [ -f "res/setup_db.sql" ]; then
    #     sudo mysql -uroot <res/setup_db.sql
    # fi

    # ## lock down database root
    # if [ -f "res/setup_root.sql" ]; then
    #     sudo mysql -uroot <res/setup_root.sql
    # fi

    #############
    ## Nginx
    ##
    echo "## Configuring Nginx" | tee -a $logfile
    cd /var/www/
    sudo mv html html_orig
    sudo ln -s /webroot/$BASE html
    #     sudo bash -c 'cat > /etc/php/7.4/fpm/pool.d/www.conf' <<EOF
    # [www]
    # user = www-data
    # group = www-data
    # listen = /run/php/php7.4-fpm.sock
    # listen.owner = www-data
    # listen.group = www-data
    # pm = dynamic
    # pm.max_children = 10
    # pm.start_servers = 3
    # pm.min_spare_servers = 1
    # pm.max_spare_servers = 5
    # EOF
    # This is for an index only setup where all files go through index.php - for handling file service in-app
    #     sudo bash -c 'cat > /etc/nginx/sites-enabled/default' <<EOF
    # server {
    #     listen       80;
    #     server_name  _;
    #     root         /var/www/html;

    #     try_files \$uri \$uri/ /index.php\$is_args\$args;

    #     location / {
    #         fastcgi_connect_timeout 3s;
    #         fastcgi_read_timeout 10s;
    #         include fastcgi_params;
    #         fastcgi_param  SCRIPT_FILENAME  \$document_root/index.php;
    #         fastcgi_pass unix:/run/php/php7.4-fpm.sock;
    #     }
    # }
    # EOF

    sudo bash -c 'cat > /etc/nginx/sites-enabled/default' <<EOF
server {
        listen 80 default_server;
        server_name _;
        root /var/www/html;
        index index.php index.html;
        location / {
                try_files \$uri \$uri/ =404;
        }
        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php-fpm.sock;
        }
        location ~ /\.ht {
                deny all;
        }
}
EOF
    # server {
    #     listen       80;
    #     root         /var/www/html;
    #     index        index.php index.html
    #     server_name  _;

    #     location / {
    #        try_files $uri $uri/ =404;
    #     }

    #     # pass PHP scripts on Nginx to FastCGI (PHP-FPM) server
    #     location ~ \.php$ {
    #        include snippets/fastcgi-php.conf;

    #        # Nginx php-fpm sock config:
    #        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
    #        # Nginx php-cgi config :
    #        # Nginx PHP fastcgi_pass 127.0.0.1:9000;
    #     }

    #     # deny access to Apache .htaccess on Nginx with PHP,
    #     # if Apache and Nginx document roots concur
    #     location ~ /\.ht {
    #         deny all;
    #     }
    # }
    # EOF
    # Add to video group so you can call vcgencmd from within scripts - FIX this for throttled
    sudo usermod -G video www-data
    sudo systemctl reload php*-fpm
    sudo systemctl restart nginx

    #############
    ## TOR
    ##
    if [ "$TOR" = "yes" ]; then
        echo "## Installing TOR components" | tee -a $logfile
        echo "## Configuring TOR" | tee -a $logfile
        sudo cp /etc/tor/torrc /etc/tor/torrc.orig
        sudo bash -c 'cat > /etc/tor/torrc' <<EOF
HiddenServiceDir /var/lib/tor/hidden_service/
HiddenServicePort 80 127.0.0.1:80
SocksPort 0.0.0.0:9050
SocksPolicy accept *
EOF
        sudo service tor stop
        sleep 1
        echo "Starting TOR service"
        sudo service tor start
        echo "## Waiting for cryptographic subsystem to complete installation"
        sudo bash -c 'while [ ! -f /var/lib/tor/hidden_service/hostname ]; do sleep 1; done'
        sudo cat /var/lib/tor/hidden_service/hostname | tee /logs/darkweb_hostname.txt
    else
        echo "## Skipping TOR components" | tee -a $logfile
    fi # TOR
else
    echo "## Skipping WEB components" | tee -a $logfile
fi # WEB

## Install crontab entries to start the services
echo "## Installing service management startup in crontab" | tee -a $logfile
echo "# $BASE configuration" | {
    cat
    sudo bash -c 'cat' <<EOF
#1 0 * * * /usr/bin/php /webroot/$BASE/sh/service_update.php > /tmp/service_update.txt 2>&1
#* * * * * /usr/bin/php /webroot/$BASE/sh/service_tick.php > /tmp/service_tick.txt 2>&1
#* * * * * /webroot/$BASE/sh/onion_exec.sh > /tmp/service_tick.txt 2>&1
EOF
} | crontab -

#############
## SAMBA
##
if [ "$SAMBA" = "yes" ]; then
    echo "## Configuring SAMBA for webserver file editing" | tee -a $logfile
    sudo bash -c 'cat > /etc/samba/smb.conf' <<__EOF
[global]
	log file = /var/log/samba/log.%m
	logging = file
	max log size = 1000
	obey pam restrictions = Yes
	pam password change = Yes
	panic action = /usr/share/samba/panic-action %d
	passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
	passwd program = /usr/bin/passwd %u
	server role = standalone server
	unix password sync = Yes
	usershare allow guests = Yes
	idmap config * : backend = tdb
	map to guest = Bad User
	log level = 1
	server role = standalone server
    unix extensions = yes

[webroot]
	comment = webroot
	path = /webroot/$BASE
	valid users = pi
	browsable = Yes
	writeable = Yes
	create mask = 0644
	directory mask = 0755
	public = yes
	read only = no
__EOF

    sudo systemctl restart smbd
    echo "Enter your local password for the 'pi' user so they are synchronised"
    sudo smbpasswd -a pi
else
    echo "## Skipping SAMBA components" | tee -a $logfile
fi

if [ "$ONION" = "yes" ]; then
    echo "## Installing onion address searcher" | tee -a $logfile
    cd ~
    # sudo apt install -y gcc libc6-dev libsodium-dev make autoconf
    git clone https://github.com/cathugger/mkp224o.git
    cd mkp224o
    ./autogen.sh
    ./configure
    make
    sudo cp mkp224o /bin
fi

cd /webroot/$BASE
#sh/torqr

if [ -f res/setup_app.sh ]; then
    echo "## Installing application components" | tee -a $logfile
    source res/setup_app.sh
fi

echo "" | tee -a $logfile
echo "####################################################################" | tee -a $logfile
echo "" | tee -a $logfile
echo "A summary of this install can be foung in $logfile" | tee -a $logfile
echo "" | tee -a $logfile
echo "We are all done. Thanks for flying with us today and we value your" | tee -a $logfile
echo "custom as we know you have choices. The next steps for you are:" | tee -a $logfile
echo "" | tee -a $logfile
echo " * Reboot this raspberry pi for overclocking to kick in" | tee -a $logfile
echo "" | tee -a $logfile
echo "####################################################################" | tee -a $logfile
