#!/bin/ash

PACKAGES="
    libpq
    libuuid
    sqlite-dev
    sqlite-libs
    curl-dev
    pcre-dev
    speex-dev
    speexdsp-dev
    libedit-dev
    ncurses-dev
    zlib-dev
    openssl-dev
    libstdc++
    libgcc
    unixodbc-dev
    libssh-dev
    libtheora
    libogg
    libvorbis
    libjpeg-turbo-dev"


echo -e "Creating user and group for freeswitch ..."
addgroup freeswitch
adduser -h /var/lib/freeswitch -H -g freeswitch -s /bin/ash -D -G freeswitch freeswitch


echo "Installing dependencies ..."
apk update
apk add git curl tar bash

apk add $PACKAGES


echo "Installing freeswitch ..."
freeswitch_archive=/tmp/freeswitch.tar.gz
curl -L -o $freeswitch_archive https://github.com/sip-li/kazoo-freeswitch-muslc/releases/download/1.4.26-kazoo-muslc/freeswitch-alpine.02-16-2016.tar.gz
tar xzvf $freeswitch_archive -C /
rm -rf $freeswitch_archive

cd /tmp
    echo "Fetching kazoo-configs for freeswitch ..."
    git clone https://github.com/2600hz/kazoo-configs
    cp -R kazoo-configs/freeswitch/* /etc/freeswitch/
    rm -rf kazoo-configs
    cd /

mkdir -p /var/lib/freeswitch/bin
mkdir -p /var/run/freeswitch
mkdir -p /tmp/freeswitch


# disable mod_speex since it's not installed anyway and its deprecated. 
sed -ir 's/\(<load module="mod_speex"\/>\)/<!--\1-->/' /etc/freeswitch/autoload_configs/modules.conf.xml

# disable mod_logfile since we're in docker
sed -ir 's/\(<load module="mod_logfile"\/>\)/<!--\1-->/' /etc/freeswitch/autoload_configs/modules.conf.xml


echo "Writing Hostname override fix ..."
tee /var/lib/freeswitch/bin/hostname-fix <<'EOF'
#!/bin/bash

fqdn() {
    local IP=$(/bin/hostname -i | sed 's/\./-/g')
    local DOMAIN='default.pod.cluster.local'
    echo "${IP}.${DOMAIN}"
}

short() {
    local IP=$(/bin/hostname -i | sed 's/\./-/g')
    echo $IP
}

ip() {
    /bin/hostname -i
}

if [[ "$1" == "-f" ]]; then
    fqdn
elif [[ "$1" == "-s" ]]; then
    short
elif [[ "$1" == "-i" ]]; then
    ip
else
    short
fi
EOF
chmod +x /var/lib/freeswitch/bin/hostname-fix


echo "Setting Ownership & Permissions ..."
# chown -R freeswitch:freeswitch /opt/freeswitch /var/lib/freeswitch /var/log/freeswitch
# chmod -R 0775 /opt/freeswitch

# /etc/freeswitch
chown -R freeswitch:freeswitch /etc/freeswitch
find /etc/freeswitch -type f -exec chmod 0644 {} \;
find /etc/freeswitch -type d -exec chmod 0755 {} \;

# /etc/freeswitch/autoload_configs
chown -R freeswitch:freeswitch /etc/freeswitch/autoload_configs
find /etc/freeswitch/autoload_configs -type f -exec chmod 0644 {} \;
find /etc/freeswitch/autoload_configs -type d -exec chmod 0755 {} \;

# /etc/freeswitch/certs
chown -R freeswitch:freeswitch /etc/freeswitch/certs
find /etc/freeswitch/certs -type f -exec chmod 0600 {} \;
find /etc/freeswitch/certs -type d -exec chmod 0770 {} \;

# /etc/freeswitch/scripts
chown -R freeswitch:freeswitch /etc/freeswitch/scripts
find /etc/freeswitch/scripts -type f -exec chmod 0774 {} \;
find /etc/freeswitch/scripts -type d -exec chmod 0775 {} \;

# /etc/freeswitch/sip_profiles
chown -R freeswitch:freeswitch /etc/freeswitch/sip_profiles
find /etc/freeswitch/sip_profiles -type f -exec chmod 0644 {} \;
find /etc/freeswitch/sip_profiles -type d -exec chmod 0755 {} \;

# /usr/lib/freeswitch/mods
chown -R root:root /usr/lib/freeswitch/mod
find /usr/lib/freeswitch/mod -type f -exec chmod 0755 {} \;
find /usr/lib/freeswitch/mod -type d -exec chmod 0755 {} \;

# /var/lib/freeswitch
chown -R freeswitch:freeswitch /var/lib/freeswitch
find /var/lib/freeswitch -type f -exec chmod 0755 {} \;
find /var/lib/freeswitch -type d -exec chmod 0755 {} \;

# /var/run/freeswitch
chown -R freeswitch:freeswitch /var/run/freeswitch
find /var/run/freeswitch -type f -exec chmod 0600 {} \;
find /var/run/freeswitch -type d -exec chmod 0750 {} \;

# /var/log/freeswitch
chown -R freeswitch:freeswitch /var/log/freeswitch
find /var/log/freeswitch -type f -exec chmod 0664 {} \;
find /var/log/freeswitch -type d -exec chmod 0775 {} \;

# /usr/share/freeswitch
chown -R freeswitch:freeswitch /usr/share/freeswitch
find /usr/share/freeswitch -type f -exec chmod 0755 {} \;
find /usr/share/freeswitch -type d -exec chmod 0755 {} \;

# /tmp/freeswitch
chown freeswitch:freeswitch /tmp/freeswitch


echo "Cleaning up ..."
apk del --purge git curl tar
rm -rf /var/cache/apk/*
rm -r /tmp/setup.sh
