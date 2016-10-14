#!/bin/bash

set -e

app=freeswitch
user=$app


# Use local cache proxy if it can be reached, else nothing.
eval $(detect-proxy enable)


echo "Creating user and group for $app ..."
useradd --system --home-dir ~ --create-home --shell /bin/false --user-group $user


echo "Installing erlang repo ..."
apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 434975BD900CCBE4F7EE1B1ED208507CA14F4FCA
echo 'deb http://packages.erlang-solutions.com/debian jessie contrib' > /etc/apt/sources.list.d/erlang.list


echo "Installing essentials ..."
apt-get update
apt-get install -y curl ca-certificates git


echo "Installing $app repo ..."
apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 79CD0F88
echo "deb http://files.freeswitch.org/repo/deb/freeswitch-1.6/ jessie main" > /etc/apt/sources.list.d/freeswitch.list
apt-get update


echo "Calculating versions ..."
apt_erlang_version=$(apt-cache show erlang-base | grep ^Version | grep $ERLANG_VERSION | sort -n | head -1 | awk '{print $2}')
apt_fs_version=$(apt-cache show freeswitch | grep ^Version | grep $FREESWITCH_VERSION | sort -n | head -1 | awk '{print $2}')
echo "erlang: $apt_erlang_version  freeswitch: $apt_fs_version"


[[ FREESWITCH_INSTALL_DEBUG = true ]] && ifdbg='-dbg'

echo "Installing $app ..."
apt-get install -y \
    freeswitch${ifdbg}=$apt_fs_version \
    freeswitch-timezones \
    $(for mod in ${FREESWITCH_INSTALL_LANGS//,/ }; 
      do 
        echo -n "freeswitch-lang-${mod} "
      done) \
    $(for mod in ${FREESWITCH_INSTALL_MODS//,/ }; 
      do 
        echo -n "freeswitch-mod-${mod}${ifdbg} "
      done) \
    $(for mod in ${FREESWITCH_INSTALL_CODECS//,/ }; 
      do 
        echo -n "freeswitch-mod-${mod}${ifdbg} "
      done) \
    $(for meta in ${FREESWITCH_INSTALL_META//,/ }; 
      do 
        echo -n "freeswitch-meta-${meta}${ifdbg} "
      done)


echo "Installing mod_kazoo manually ..."
# install mod_kazoo manually because we only need a very 
# minimal erlang env for epmd
mkdir /tmp/kz
pushd $_
    apt-get download freeswitch-mod-kazoo
    dpkg -x freeswitch-mod-kazoo* .
    mv usr/lib/freeswitch/mod/mod_kazoo.so /usr/lib/freeswitch/mod/
    popd && rm -rf $OLDPWD


echo "Installing epmd manually ..."
mkdir /tmp/erl 
pushd $_
    apt-get download erlang-base
    dpkg -x erlang-base* .
    mv usr/lib/erlang/erts-*/bin/epmd /usr/bin/
    popd && rm -rf $OLDPWD


# Note:
# The package freeswitch-sounds-en-us-callie has the following requirements
# but they are only required for the postinst trigger script which converts
# the base flac files to different bitrates.  Because it's a dependency of
# the package, trying to remove them afterwards removes the sounds also
#
# What I'm doing here is installing the requirements, downloading the package
# extracting it, running the postinst trigger, then removing the requirements
#
# If you wish to uninstall the sounds later, use: 
#   rm -rf /usr/share/freeswitch/sounds/en/us/callie

echo "Installing sounds ..."
apt-get install -y \
    flac \
    libasound2 \
    libasound2-data \
    libgomp1 \
    libgsm1 \
    libmagic1 \
    libopencore-amrnb0 \
    libopencore-amrwb0 \
    libpng12-0 \
    libsox-fmt-alsa \
    libsox-fmt-base \
    libsox2 \
    libvorbisfile3 \
    libwavpack1 \
    sox

mkdir /tmp/sounds
pushd $_
    apt-get download freeswitch-sounds-en-us-callie
    dpkg -e freeswitch-sounds-en-us-callie*
    dpkg -x freeswitch-sounds-en-us-callie* .
    mv usr/share/freeswitch/sounds/ /usr/share/freeswitch/
    DEBIAN/postinst configure
    popd && rm -rf $OLDPWD

apt-get purge -y --auto-remove \
    flac \
    libasound2 \
    libasound2-data \
    libgomp1 \
    libgsm1 \
    libmagic1 \
    libopencore-amrnb0 \
    libopencore-amrwb0 \
    libpng12-0 \
    libsox-fmt-alsa \
    libsox-fmt-base \
    libsox2 \
    libvorbisfile3 \
    libwavpack1 \
    sox


echo "Creating directories ..."
mkdir -p \
    /volumes/ram/{log,run,db,cache,http_cache} \
    /volumes/freeswitch/{storage,recordings} \
    /volumes/tls \
    /var/lib/freeswitch/images \
    /usr/share/freeswitch/images \
    /etc/freeswitch/gateways \
    /tmp/freeswitch


echo "Fetching kazoo-configs for $app ..."
rm -rf /etc/freeswitch
cd /tmp
    git clone -b $KAZOO_CONFIGS_BRANCH --single-branch --depth 1 https://github.com/2600hz/kazoo-configs kazoo-configs
    pushd $_
        mv freeswitch /etc/
        popd && rm -rf $OLDPWD


echo "Config fixes ..."
pushd /etc/freeswitch
    echo "Fixing paths containing kazoo ..."
for f in $(grep -rl '/etc/kazoo' *)
do
    sed -i 's|/etc/kazoo|/etc|g' $f
    grep '/etc/freeswitch' $f || true
done
    
    # let's download the file that's referenced in conferences.conf.xml yet
    # doesn't exist.
    curl -sSL -o /usr/share/freeswitch/images/no_video_avatar.png \
        'https://freeswitch.org/stash/projects/FS/repos/freeswitch/browse/images/default-avatar.png?at=9c459f881eb8deb09697aba2f965b77a2de25330&raw'

    # we're using the tls dir now
    rm -rf certs

    echo "Fixing ${app}.xml ..."
    sed -i '\|recordings_dir|s|/tmp/|/volumes/freeswitch/recordings|' freeswitch.xml
    sed -i '\|recordings_dir|a \
    <X-PRE-PROCESS cmd="set" data="storage_dir=/volumes/freeswitch/storage"/> \
    <X-PRE-PROCESS cmd="set" data="conf_dir=/etc/freeswitch"/> \
    <X-PRE-PROCESS cmd="set" data="log_dir=/volumes/ram/log"/> \
    <X-PRE-PROCESS cmd="set" data="run_dir=/volumes/ram/run"/> \
    <X-PRE-PROCESS cmd="set" data="db_dir=/volumes/ram/db"/> \
    <X-PRE-PROCESS cmd="set" data="cache_dir=/volumes/ram/cache"/> \
    <X-PRE-PROCESS cmd="set" data="temp_dir=/tmp/freeswitch"/> \
    <X-PRE-PROCESS cmd="set" data="certs_dir=/volumes/tls"/> \
    <X-PRE-PROCESS cmd="set" data="images_dir=/usr/share/freeswitch/images"/>' $_

    echo "Adding codecs: VP9,SILK,G729 ..."
    sed -i '/codecs=/s/VP8/VP9,VP8/;/codecs=/s/OPUS/OPUS,SILK/;/codecs=/s/G722/G729,G722/' freeswitch.xml
    grep 'hold_music\|recordings_dir\|codecs' $_

    pushd sip_profiles
        echo "fixing sip_profile ..."
        sed -i '\|hold-music|s|local_stream://default|$${hold_music}|' sipinterface_1.xml
        sed -i '\|tls-cert-dir|s|/etc/freeswitch/certs|$${certs_dir}|' $_
        sed -i '/recordings_dir/s/temp/recordings/' $_
        sed -i '/in-dialog-chat/s/<!--\(.*\)-->/\1/' $_
        sed -i '/in-dialog-chat/a \
            \
            <!-- MESSAGES --> \
            <param name="fire-message-events" value="true"/>' $_
        grep 'fire-message-events\|hold-music' $_
        popd

    pushd autoload_configs
        echo "Disabling broken or unnecessary modules ..."
        # these loggers are unused in docker and these codecs are now in core
        rm -f {logfile,syslog}.conf.xml
        sed -i '/mod_syslog/d;/mod_logfile/d;/mod_speex/d;/mod_celt/d;' modules.conf.xml

        echo "Fixing path in conference.conf.xml ..."
        sed -i '\|video-no-video-avatar|s|value="/etc/images\(.*\)"|value="$${images_dir}\1"|' conference.conf.xml
        grep video-no-video-avatar $_
        
        echo "Fixing http_cache path ..."
        sed -i '\|location|s|value=".*"|value="/volumes/ram/http_cache"|' http_cache.conf.xml
        grep location $_

        echo "Fixing path in spandsp.conf.xml ..."
        sed -i '\|spool-dir|s|/tmp|$${temp_dir}|' spandsp.conf.xml
        grep spool-dir $_

        echo "Adding modules to modules.conf.xml ..."
        for mod in ${FREESWITCH_LOAD_MODS//,/ }
        do 
            sed -i "/Codec Interfaces/a \
                \        <load module=\"mod_${mod}\"/>" modules.conf.xml
        done
        cat $_ | grep -v '<!' | awk 'NF'
        popd


echo "Cleaning up unneeded packages ..."
apt-get purge -y --auto-remove git


echo "Setting Ownership & Permissions ..."
chown -R $user:$user \
    ~ \
    /etc/freeswitch \
    /volumes/{freeswitch,ram,tls} \
    /usr/lib/freeswitch \
    /var/lib/freeswitch \
    /usr/share/freeswitch

chmod -R 0777 /tmp/freeswitch /volumes/freeswitch/{storage,recordings}


echo "Cleaning up ..."
apt-clean --aggressive

# if applicable, clean up after detect-proxy enable
eval $(detect-proxy disable)

rm -r -- "$0"
