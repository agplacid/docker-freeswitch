#!/bin/bash

set -e

app=freeswitch
user=freeswitch


# Use local cache proxy if it can be reached, else nothing.
eval $(detect-proxy enable)


echo "Creating user and group for $app ..."
useradd --home-dir ~ --create-home --shell=/bin/bash --user-group $user


echo "Installing erlang repo ..."
apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 434975BD900CCBE4F7EE1B1ED208507CA14F4FCA
echo 'deb http://packages.erlang-solutions.com/debian jessie contrib' > /etc/apt/sources.list.d/erlang.list


echo "Installing essentials ..."
apt-get update
apt-get install -y curl ca-certificates git


echo "Installing $app repo ..."
curl -sSL https://files.freeswitch.org/repo/deb/debian/freeswitch_archive_g0.pub | apt-key add - 
echo "deb http://files.freeswitch.org/repo/deb/freeswitch-1.6/ jessie main" > /etc/apt/sources.list.d/freeswitch.list
apt-get update


echo "Calculating versions ..."
apt_erlang_version=$(apt-cache show erlang-base | grep ^Version | grep $ERLANG_VERSION | sort -n | head -1 | awk '{print $2}')
apt_fs_version=$(apt-cache show freeswitch | grep ^Version | grep $FREESWITCH_VERSION | sort -n | head -1 | awk '{print $2}')
echo "erlang: $apt_erlang_version  freeswitch: $apt_fs_version"


echo "Installing dependencies ..."
apt-get install -y \
    erlang-base=$apt_erlang_version \
    flac \
    libgomp1 \
    libgsm1 \
    libmagic1 \
    libopencore-amrnb0 \
    libopencore-amrwb0 \
    libsox-fmt-alsa \
    libsox-fmt-base \
    libsox2 \
    libvorbisfile3 \
    libwavpack1 \
    sox


echo "Installing $app ..."
apt-get install -y \
    freeswitch=$apt_fs_version \
    freeswitch-lang \
    freeswitch-timezones \
    freeswitch-meta-codecs \
    freeswitch-meta-lang \
    freeswitch-meta-mod-say \
    freeswitch-mod-abstraction \
    freeswitch-mod-commands \
    freeswitch-mod-conference \
    freeswitch-mod-dptools \
    freeswitch-mod-dialplan-xml \
    freeswitch-mod-enum \
    freeswitch-mod-fifo \
    freeswitch-mod-http-cache \
    freeswitch-mod-spandsp \
    freeswitch-mod-flite \
    freeswitch-mod-dingaling \
    freeswitch-mod-loopback \
    freeswitch-mod-portaudio \
    freeswitch-mod-rtmp \
    freeswitch-mod-sofia \
    freeswitch-mod-erlang-event \
    freeswitch-mod-event-socket \
    freeswitch-mod-local-stream \
    freeswitch-mod-portaudio-stream \
    freeswitch-mod-sndfile \
    freeswitch-mod-tone-stream \
    freeswitch-mod-console \
    freeswitch-mod-xml-cdr \
    freeswitch-mod-xml-curl \
    freeswitch-mod-xml-rpc \
    freeswitch-mod-ilbc \
    freeswitch-mod-shout \
    freeswitch-mod-siren


echo "Installing mod_kazoo ..."
# install mod_kazoo manually because we only need a very 
# minimal erlang env for epmd
cd /tmp
    apt-get download freeswitch-mod-kazoo
    dpkg -x freeswitch-mod-kazoo* ov/
    mv ov/usr/lib/freeswitch/mod/mod_kazoo.so /usr/lib/freeswitch/mod/
    rm -rf ov freeswitch-mod-kazoo*.deb


echo "Downloading sounds and music packages ..."
# download the following packages so that they can generate the
# sound and music files on first container startup, this cuts the
# container size literally in half
cd /tmp
    apt-get download freeswitch-sounds-en-us-callie
    apt-get download freeswitch-music-default


echo "Fetching kazoo-configs for $app ..."
cd /tmp
    git clone -b master --single-branch --depth 1 https://github.com/2600hz/kazoo-configs
    cp -R kazoo-configs/freeswitch/* /etc/freeswitch/
    rm -rf kazoo-configs


echo "Creating directories ..."
mkdir -p \
    /var/run/freeswitch \
    /var/log/freeswitch \
    /var/cache/freeswitch


echo "Disabling broken or unnecessary modules ..."
# disable mod_speex since it's not installed anyway and its deprecated. 
sed -ir '/mod_speex/s/\(<.*>\)/<!--\1-->/' \
    /etc/freeswitch/autoload_configs/modules.conf.xml

# disable mod_logfile since we're in docker
sed -ir '/mod_logfile/s/\(<.*>\)/<!--\1-->/' \
    /etc/freeswitch/autoload_configs/modules.conf.xml

# disable mod_celt since it doesn't seem to be around anymore
sed -ir '/mod_celt/s/\(<.*>\)/<!--\1-->/' \
    /etc/freeswitch/autoload_configs/modules.conf.xml


echo "Cleaning up unneeded packages ..."
apt-get purge -y --auto-remove git


echo "Setting Ownership & Permissions ..."
chown -R freeswitch:freeswitch \
    ~ \
    /opt/freeswitch \
    /etc/freeswitch \
    /usr/lib/freeswitch \
    /var/lib/freeswitch \
    /usr/share/freeswitch \
    /var/run/freeswitch \
    /var/log/freeswitch \
    /var/cache/freeswitch

find /var/lib/freeswitch -type f -exec chmod 0755 {} \;
find /var/lib/freeswitch -type d -exec chmod 0755 {} \;

find /var/run/freeswitch -type f -exec chmod 0600 {} \;
find /var/run/freeswitch -type d -exec chmod 0750 {} \;

find /usr/share/freeswitch -type f -exec chmod 0755 {} \;
find /usr/share/freeswitch -type d -exec chmod 0755 {} \;

find /var/log/freeswitch -type f -exec chmod 0664 {} \;
find /var/log/freeswitch -type d -exec chmod 0775 {} \;


echo "Cleaning up ..."

apt-clean --aggressive

# if applicable, clean up after detect-proxy enable
eval $(detect-proxy disable)

rm -r -- "$0"
