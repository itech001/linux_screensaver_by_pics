linux_screensaver_by_pics
=========================

screensaver for Linux to show some pictures orderly.


## Requirements##
* linux screensaver to show some pictures orderly;
* get pictures from url json file;
* all machines in farm has same setting, and they will run the image download script at the same time;  
* the script must has random delay before downloading the images, to avoid too many server requests at the same time;
* /mnt/screensaver is nfs and shared for all machines;
* if one machine is running for download, other machines will wait;
* if the images are downloaded by one machine, other machines will do nothing;



## Deploy steps##
1. download linux_screensaver_by_pics
```sh
chmod 777 /mnt/screensaver
cd /mnt/screensaver
wget https://github.com/itech001/linux_screensaver_by_pics/archive/master.zip
unzip master.zip
```

2. install perl modules
```sh
cpan -fi JSON Data::GUID Sys::HostAddr
```

3. install xscreensaver
```sh
apt-get -y install xscreensaver xscreensaver-gl
mv /usr/bin/xscreensaver-getimage-file /usr/bin/xscreensaver-getimage-file.bak
cp  /mnt/screensaver/linux_screensaver_by_pics/deploy_data/xscreensaver-getimage-file /usr/bin/xscreensaver-getimage-file 
chmod a+x /usr/bin/xscreensaver-getimage-file

for testing
/usr/bin/xscreensaver-getimage-file /mnt/screensaver/test
```

4. cp config  (for ubuntu guest)
```sh
SKEL=/etc/skel/
cp /mnt/screensaver/linux_screensaver_by_pics/deploy_data/.xscreensaver $SKEL
cp /mnt/screensaver/linux_screensaver_by_pics/deploy_data/.xscreensaver-image-index $SKEL
#cp $HOME/linux_screensaver_by_pics/deploy_data/xscreensaver.desktop $SKEL/.config/autostart/xscreensaver.desktop
#cp $HOME/linux_screensaver_by_pics/deploy_data/xscreensaver_service.desktop $SKEL/.config/autostart/xscreensaver_service.desktop
#cp $HOME/linux_screensaver_by_pics/deploy_data/xscreensaver_mytest.desktop $SKEL/.config/autostart/xscreensaver_mytest.desktop
```

5. autostart xscreensaver and set cron (for ubuntu guest)
```sh
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
#(crontab -l 2>/dev/null; echo "0 9 * * * /mnt/screensaver/linux_screensaver_by_pics/deloy_data/download_pics.pl") | crontab -
```

6. root cron 
```sh
for testing:
/mnt/screensaver/linux_screensaver_by_pics/test_data/start_server.sh
/mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl

# m h  dom mon dow   command
@reboot xscreensaver -no-splash -no-capture-stderr
@reboot /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl
0 9 * * * /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl
#below one is for testing
@reboot /mnt/screensaver/linux_screensaver_by_pics/test_data/start_server.sh
```

7. set dir permission for guest (for ubuntu guest) 
```sh
mkdir /var/guest-data
chmod 777 /var/guest-data
vi /etc/apparmor.d/abstractions/lightdm
  /mnt/** rwlkmix,
  /var/guest-data/** rw,
```

8. ctrl+alt+l to lock (doesn't work,ignored)
```sh
sudo ln -s /usr/bin/xscreensaver-command /usr/bin/gnome-screensaver-command
```

9. reboot system to verity result
```sh
xscreensaver-command -activate
```

## testing ##
