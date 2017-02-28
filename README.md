# dman - a deadman switch
TODO: Write a project description

## Client Installation/Config

First. You will need to get the serial ( `ATTRS{serial}==` ) attribute from your falsh drive. Multiple devices can be added as separate rules.
```
# udevadm info -a -n /dev/sdb
```

Modify `99-unlock-luks-udev.rules` to include your serial number and copy it to `/etc/udev/rules.d/`

Reload udev
```
# udevadm control --reload-rules
# systemctl restart systemd-udevd.service
```

Generate a 2048 bit key
```
# dd if=/dev/urandom of=my_secretkey bs=2048 count=1
```

Copy your key into free space on the flash drive. This skips the first 2048 bytes, and places it after the partition table. You may want to zero out and dump the beginning of a freshly partitioned/formatted drive and review/verify that nothing important will be overwritten
```
# dd if=my_secretkey of=/dev/sdb bs=2048 seek=1
```

Set `MountFlags=shared` in `/usr/lib/systemd/system/systemd-udevd.service` or the mount command in autodecrypt.sh will fail

Copy scripts to client
```
mkdir /opt/dman/
cp autodecrypt.sh dman-client-config.sh dman-client.sh /opt/dman/
```

Modify `dman-client-config.sh` to suit your environment.

Add the following line to root's crontab ( `sudo crontab -e`).
```
* * * * /opt/dman/dman-cron.sh >>/opt/dman/dman_l.log 2>&1
```

## Server Installation/Config
Copy `dman-cgi.sh` and `dman-cgi-config.sh` to /var/www/html/dman (or equivalent web root)

Next, configure the directory to run CGI shell scripts. Here's a samlple nginx server block:
```
server {
    listen 80;
    server_name dman.yourdomain.com; 

    location / {
        root /var/www/html/dman;
        index index.html index.htm;
    }

    location ~ \.sh$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:/run/fcgiwrap.socket;
        fastcgi_index index.sh;
        fastcgi_param SCRIPT_FILENAME /var/www/html/dman/$fastcgi_script_name;
    }

}
```

Start the webserver and attempt to curl the cgi script.

That's it. You can now use the dman client to set/check the deadman status
## Usage

Check status
```
dman-client.sh
```

Set timeout to default (36 hours)
```
dman-client.sh set
```

Set timeout
```
dman-client.sh set <timeout>
```

Include this in your bashrc on the client for easy use.
```
dman(){
  /opt/dman/dman-cron.sh $1 $2
}
```

Set the default timeout:
```
> dman set
set:1
set_time:60*60*36
timeout:129600
uuid:foobarhost_167f83f77aa1cef99d4bb33e58924203
uuid_md5:34893ae759babdba27ccb439773da82f
future_epoc:1488373190
time_diff:129600
state:ALIVE
delta:129600
delta_h:1d 12h 0s
dman_mtime:1488373190
cur_epoch: 1488243590
```
## History
## License

