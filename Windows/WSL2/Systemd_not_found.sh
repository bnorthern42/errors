#!/bin/bash


echo "Bugfix of systemd not working:"
echo "https://github.com/microsoft/WSL/issues/5126#issuecomment-653715201"


if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo "Get update " |sudo apt-get update
echo "install daemonize " | sudo apt-get install -yqq daemonize dbus-user-session fontconfig
echo "setup daemonize " |sudo daemonize /usr/bin/unshare --fork --pid --mount-proc /lib/systemd/systemd --system-unit=basic.target
echo "Almost there " |exec sudo nsenter -t $(pidof systemd) -a su - $LOGNAME

exec sudo 
echo "works"
