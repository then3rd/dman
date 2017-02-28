#DMAN
#Root location of dman-client* and autodecrypt.sh
#If you change this value, you MUST modify 'PATH=/opt/dman:' in dman-client.sh and autodecrypt.sh
DMANROOT="/opt/dman/"
LOGFILE="${DMANROOT}/dman.log"
#domain+scriptname to query
DMAN_URL='http://yourdomain.com/dman-cgi.sh'
#Default deadman set timeout.
DMAN_DEFAULT_TIMEOUT='60*60*36' #36 hours
##Name of encrypted LUKS device (i'm using LVM)
LUKSOPEN="/dev/system/encryptedvolume"
#name of cryptsetup luksopen device to be created (/dev/mapper/decryptedname)
DECRYPT="decryptedname" 
#Location to mount decrypted device
MOUNTDIR="/mnt/decryptmount/"