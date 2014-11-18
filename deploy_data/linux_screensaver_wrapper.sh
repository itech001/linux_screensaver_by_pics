
#!/bin/bash
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
done
