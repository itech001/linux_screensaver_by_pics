linux_screensaver_by_pics
=========================

screensaver for Linux to show some pictures orderly.


## Requirements##
* linux screensaver to show some pictures orderly;
* get pictures from url json file;
* has random delay before downloading the images, to avoid too many server requests at the same time;
* /mnt/screensaver is nfs and shared for all machines;


## Deploy steps##
* 1) download linux_screensaver_by_pics
chmod 777 /mnt/screensaver
cd /mnt/screensaver
wget https://github.com/itech001/linux_screensaver_by_pics/archive/master.zip
unzip master.zip

* 2) install perl modules
cpan -fi JSON Data::GUID Sys::HostAddr

* 3) install xscreensaver
apt-get -y install xscreensaver xscreensaver-gl
mv /usr/bin/xscreensaver-getimage-file /usr/bin/xscreensaver-getimage-file.bak
cp  /mnt/screensaver/linux_screensaver_by_pics/deploy_data/xscreensaver-getimage-file /usr/bin/xscreensaver-getimage-file 
chmod a+x /usr/bin/xscreensaver-getimage-file

for testing
/usr/bin/xscreensaver-getimage-file /mnt/screensaver/test

* 4) cp config  (for ubuntu guest)
SKEL=/etc/skel/
cp /mnt/screensaver/linux_screensaver_by_pics/deploy_data/.xscreensaver $SKEL
#cp $HOME/linux_screensaver_by_pics/deploy_data/xscreensaver.desktop $SKEL/.config/autostart/xscreensaver.desktop
#cp $HOME/linux_screensaver_by_pics/deploy_data/xscreensaver_service.desktop $SKEL/.config/autostart/xscreensaver_service.desktop
#cp $HOME/linux_screensaver_by_pics/deploy_data/xscreensaver_mytest.desktop $SKEL/.config/autostart/xscreensaver_mytest.desktop

* 5) autostart xscreensaver and set cron (for ubuntu guest)
mkdir /etc/guest-session
chmod a+x /etc/guest-session/auto.sh
auto.sh
#!/bin/sh
echo xscreensaver
#xscreensaver -no-splash
echo start_server
#/mnt/screensaver/linux_screensaver_by_pics/test_data/start_server.sh  &
echo start_download
#/mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl &
#(crontab -l 2>/dev/null; echo "*/5 * * * * /mnt/screensaver/linux_screensaver_by_pics/deloy_data/download_pics.pl") | crontab -

* 6)root cron 
for testing:
/mnt/screensaver/linux_screensaver_by_pics/test_data/start_server.sh
/mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl

# m h  dom mon dow   command
@reboot xscreensaver -no-splash -no-capture-stderr
@reboot /mnt/screensaver/linux_screensaver_by_pics/test_data/start_server.sh
@reboot /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl
0 9 * * * /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl

* 7) set dir permission for guest (for ubuntu guest) 
mkdir /var/guest-data
chmod 777 /var/guest-data
vi /etc/apparmor.d/abstractions/lightdm
  /mnt/** rwlkmix,
  /var/guest-data/** rw,

* 8) ctrl+alt+l to lock (doesn't work)
sudo ln -s /usr/bin/xscreensaver-command /usr/bin/gnome-screensaver-command

* 9)reboot system to verity result
xscreensaver-command -activate


## testing ##
