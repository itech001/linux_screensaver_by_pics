linux_screensaver_by_pics
=========================

screensaver for Linux to show some pictures sequentially.  


##Requirements
* This program need run on many farm machines;
* Download pictures by json url when the machine boot and every 9am;
* Show the downloaded pictures sequentially by screensaver;
* The script must has random minutes delay before downloading the images, to avoid too many server requests at the same time;
* /mnt/screensaver is nfs share folder and mounted on all machines, my script and downloaded pictures will be saved to this folder;
* If one machine is running for download, other machines will wait;
* If the images are downloaded by one machine, other machines will do nothing;



##Deploy steps for ubuntu guest account
Tested on ubuntu 14.04

1. install perl modules ( root)
>cpan -fi JSON Data::GUID Sys::HostAddr File::NFSLock  

1. install xscreensaver (root)
>apt-get -y install xscreensaver xscreensaver-gl   

1. create special account for screensaver (root)
>useradd -d /home/ss -m ss  
passwd ss  
chown ss:ss /mnt/screensaver  

1. my script linux_screensaver_by_pics (root)
>chmod 777 /mnt/screensaver  
cd /mnt/screensaver  
cd linux_screensaver_by_pics(my script is copied here)  
overwrite default xscreensaver file:  
mv /usr/bin/xscreensaver-getimage-file /usr/bin/xscreensaver-getimage-file.bak  
cp /mnt/screensaver/linux_screensaver_by_pics/deploy_data/xscreensaver-getimage-file   /usr/bin/xscreensaver-getimage-file  
chmod a+x /usr/bin/xscreensaver-getimage-file  
for testing:  
/usr/bin/xscreensaver-getimage-file /mnt/screensaver/linux_screensaver_by_pics/result_data/current  

1. cp xscreensaver config for guest user (root)
>SKEL=/etc/skel/ or SKEL=/etc/guest-session/skel  
cp /mnt/screensaver/linux_screensaver_by_pics/deploy_data/.xscreensaver $SKEL  
cp /mnt/screensaver/linux_screensaver_by_pics/deploy_data/.xscreensaver-image-index $SKEL  

1. set xscreensaver autostart for guest user (root)
>mkdir /etc/guest-session  
chmod a+x /etc/guest-session/auto.sh  
auto.sh:   
echo start xscreensaver  
xscreensaver -no-splash -no-capture-stderr &  

1. set cron for download script (ss)
>manually testing:  
/mnt/screensaver/linux_screensaver_by_pics/test_data/start_server.sh  
/mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl  
below one is for testing:  
@reboot /mnt/screensaver/linux_screensaver_by_pics/test_data/start_server.sh
cron for download images:  
@reboot /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl  
0 9 * * * /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl  

1. set dir permission for guest user (root)
>chmod 777 /mnt/screensaver  
vi /etc/apparmor.d/abstractions/lightdm  
/var/guest-data/** rw, # allow to store files permanently  
/mnt/ rwlkmix,  
/mnt/** rwlkmix,  

1. reboot system and verity result (guest)
>xscreensaver-command -activate  

1. check if /mnt/screensaver mounted
>/mnt/screensaver/linux_screensaver_by_pics/deploy_data/linux_screensaver_wrapper.sh:
\#!/bin/bash
for (( i=1; i <= 5; i++ ))
do
    if mountpoint -q /mnt/screensaver
        then
            echo "download script will start!"
            echo "$1"
            $1
            echo "download script is started!"
            break
        fi
    echo "sleep 20"
    sleep 20
crons need be chagned to:
@reboot /mnt/screensaver/linux_screensaver_by_pics/deploy_data/linux_screensaver_wrapper.sh /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl  > ~/.linux_screensaver_wrapper.log 2>&1 
0 9 * * * /mnt/screensaver/linux_screensaver_by_pics/deploy_data/linux_screensaver_wrapper.sh /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl > ~/.linux_screensaver_wrapper.log 2>&1

##issues and logs
1. check mount log
~/.linux_screensaver_wrapper.log ( for ss acount)

1. check other logs
/mnt/screensaver/linux_screensaver_by_pics/.your_ip.log

##Reference
http://www.jwz.org/xscreensaver/man.html  
http://www.jwz.org/xscreensaver/faq.html  
https://help.ubuntu.com/community/CustomizeGuestSession  
