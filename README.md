linux_screensaver_by_pics
=========================

screensaver for Linux to show some pictures sequentially.  


## Requirements##
* This program need run on many farm machines;
* Download pictures by json url when the machine boot and every 9am;
* Show the downloaded pictures sequentially by screensaver;
* The script must has random minutes delay before downloading the images, to avoid too many server requests at the same time;
* /mnt/screensaver is nfs share folder and mounted on all machines, the downloaded pictures wil l be saved to this folder;
* If one machine is running for download, other machines will wait;
* If the images are downloaded by one machine, other machines will do nothing;


## Deploy steps##  
0. install perl modules 
>cpan -fi JSON Data::GUID Sys::HostAddr File::NFSLock   

1. install xscreensaver
>apt-get -y install xscreensaver xscreensaver-gl  

2. create account to run this program (root)
>useradd -d /home/ss -m ss  
passwd ss  
su - ss  

3. download this program linux_screensaver_by_pics
>chmod 777 /mnt/screensaver  
cd /mnt/screensaver  
wget https://github.com/itech001/linux_screensaver_by_pics/archive/master.zip  
unzip master.zip  
cd linux_screensaver_by_pics  
mv /usr/bin/xscreensaver-getimage-file /usr/bin/xscreensaver-getimage-file.bak  
cp  /mnt/screensaver/linux_screensaver_by_pics/deploy_data/xscreensaver-getimage-file /usr/bin/xscreensaver-getimage-file  
chmod a+x /usr/bin/xscreensaver-getimage-file  
for testing  
/usr/bin/xscreensaver-getimage-file /mnt/screensaver/linux_screensaver_by_pics/result_data/current  

4. cp config  for guest user (to ubuntu guest home)
>SKEL=/etc/skel/  or SKEL=/etc/guest-session/skel    
cp /mnt/screensaver/linux_screensaver_by_pics/deploy_data/.xscreensaver $SKEL  
cp /mnt/screensaver/linux_screensaver_by_pics/deploy_data/.xscreensaver-image-index $SKEL  

5. autostart xscreensaver for guest user (for ubuntu guest)
>mkdir /etc/guest-session  
chmod a+x /etc/guest-session/auto.sh  
auto.sh : 
echo start xscreensaver  
xscreensaver -no-splash -no-capture-stderr & 

6. cron on ss account 
>manually testing:  
/mnt/screensaver/linux_screensaver_by_pics/test_data/start_server.sh  
/mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl  
\#below one is for testing 
@reboot /mnt/screensaver/linux_screensaver_by_pics/test_data/start_server.sh
\# dont need for guest user 
@reboot xscreensaver -no-splash -no-capture-stderr & 
@reboot /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl  
0 9 * * * /mnt/screensaver/linux_screensaver_by_pics/deploy_data/download_pics.pl  

7. set dir permission for guest user (for ubuntu guest) 
>mkdir /var/guest-data  
chmod 777 /var/guest-data  
chmod 777 /mnt/screensaver  
vi /etc/apparmor.d/abstractions/lightdm  
  /var/guest-data/** rw, # allow to store files permanently  
  /mnt/ rwlkmix,  
  /mnt/** rwlkmix,  


8. ctrl+alt+l to lock (lock is disabled by default for guest, below also doesn't work)
>sudo ln -s /usr/bin/xscreensaver-command /usr/bin/gnome-screensaver-command  

9. reboot system to verity result
>xscreensaver-command -activate  

## testing ##

## reference##
http://www.jwz.org/xscreensaver/man.html
http://www.jwz.org/xscreensaver/faq.html  
https://help.ubuntu.com/community/CustomizeGuestSession
