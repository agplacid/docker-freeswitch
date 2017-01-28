#!/bin/bash -l

set -e

# Use local cache proxy if it can be reached, else nothing.
eval $(detect-proxy enable)

build::user::create $USER

log::m-info "Installing $APP repo ..."
build::apt::add-key 434975BD900CCBE4F7EE1B1ED208507CA14F4FCA
echo 'deb http://packages.erlang-solutions.com/debian jessie contrib' > \
    /etc/apt/sources.list.d/erlang.list
build::apt::add-key 79CD0F88
echo 'deb http://files.freeswitch.org/repo/deb/freeswitch-1.6/ jessie main' > \
    /etc/apt/sources.list.d/freeswitch.list

apt-get -q update


log::m-info "Installing essentials ..."
apt-get install -qq -y curl ca-certificates git


log::m-info "Installing erlang & $APP ..."
apt_erlang_vsn=$(build::apt::get-version erlang)
apt_freeswitch_vsn=$(build::apt::get-version $APP)

[[ $FREESWITCH_INSTALL_DEBUG = true ]] && ifdbg='-dbg'
log::m-info "apt versions: erlang: $apt_erlang_vsn freeswitch: $apt_freeswitch_vsn"
apt-get install -qq -y \
    freeswitch${ifdbg}=$apt_freeswitch_vsn \
    freeswitch-timezones \
    freeswitch-sounds* \
    $(for mod in ${FREESWITCH_INSTALL_LANGS//,/ }; do
        echo -n "freeswitch-lang-${mod} "
      done) \
    $(for mod in ${FREESWITCH_INSTALL_MODS//,/ }; do
        echo -n "freeswitch-mod-${mod}${ifdbg} "
      done) \
    $(for mod in ${FREESWITCH_INSTALL_CODECS//,/ }; do
        echo -n "freeswitch-mod-${mod}${ifdbg} "
      done) \
    $(for meta in ${FREESWITCH_INSTALL_META//,/ }; do
        echo -n "freeswitch-meta-${meta}${ifdbg} "
      done)


log::m-info "Installing mod_kazoo manually ..."
# install mod_kazoo manually because we only need a very
# minimal erlang env for epmd
mkdir /tmp/kz
pushd $_
    apt-get download freeswitch-mod-kazoo
    dpkg -x freeswitch-mod-kazoo* .
    mv usr/lib/freeswitch/mod/mod_kazoo.so /usr/lib/freeswitch/mod/
    popd && rm -rf $OLDPWD


log::m-info "Installing epmd manually ..."
mkdir /tmp/erl
pushd $_
    apt-get download erlang-base
    dpkg -x erlang-base* .
    mv usr/lib/erlang/erts-*/bin/epmd /usr/bin/
    popd && rm -rf $OLDPWD


log::m-info "Creating directories ..."
mkdir -p \
    /volumes/ram/{log,run,db,cache,http_cache} \
    /volumes/freeswitch/{storage,recordings} \
    /volumes/tls \
    /var/lib/freeswitch/images \
    /usr/share/freeswitch/images \
    /etc/freeswitch/gateways \
    /tmp/freeswitch


log::m-info "Fetching kazoo-configs for $APP ..."
rm -rf /etc/freeswitch
mkdir -p /tmp/configs
pushd $_
    git clone -b $KAZOO_CONFIGS_BRANCH --single-branch --depth 1 \
        https://github.com/2600hz/kazoo-configs .

    mv freeswitch /etc/
    popd && rm -rf $OLDPWD


log::m-info "Config fixes ..."
pushd /etc/freeswitch
    log::m-info "Fixing paths containing kazoo ..."
    for f in $(grep -rl '/etc/kazoo' *); do
        sed -i 's|/etc/kazoo|/etc|g' $f
        grep '/etc/freeswitch' $f || true
    done

    # we're using the tls dir now
    rm -rf certs

    # let's download the file that's referenced in conferences.conf.xml yet
    # doesn't exist.
    curl -sSL -o /usr/share/freeswitch/images/no_video_avatar.png \
        'https://freeswitch.org/stash/projects/FS/repos/freeswitch/browse/images/default-avatar.png?at=9c459f881eb8deb09697aba2f965b77a2de25330&raw'

    log::m-info "Fixing ${APP}.xml ..."
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

    log::m-info "Adding codecs: VP9,SILK,G729 ..."
    sed -i '/codecs=/s/VP8/VP9,VP8/;/codecs=/s/OPUS/OPUS,SILK/;/codecs=/s/G722/G729,G722/' freeswitch.xml
    grep 'hold_music\|recordings_dir\|codecs' $_

    pushd sip_profiles
        log::m-info "fixing sip_profile ..."
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
        log::m-info "Disabling broken or unnecessary modules ..."
        # these loggers are unused in docker and these codecs are now in core
        rm -f {logfile,syslog}.conf.xml
        sed -i '/mod_syslog/d;/mod_logfile/d;/mod_speex/d;/mod_celt/d;' modules.conf.xml

        log::m-info "Fixing path in conference.conf.xml ..."
        sed -i '\|video-no-video-avatar|s|value="/etc/images\(.*\)"|value="$${images_dir}\1"|' conference.conf.xml
        grep video-no-video-avatar $_

        log::m-info "Fixing path in spandsp.conf.xml ..."
        sed -i '\|spool-dir|s|/tmp|$${temp_dir}|' spandsp.conf.xml
        grep spool-dir $_

        log::m-info "Adding modules to modules.conf.xml ..."
        for mod in ${FREESWITCH_LOAD_MODS//,/ }; do
            sed -i "/Codec Interfaces/a \
                \        <load module=\"mod_${mod}\"/>" modules.conf.xml
        done
        cat $_ | grep -v '<!' | awk 'NF'

        log::m-info "Setting up mod_http_cache to work with ssl ..."
        mkdir -p /usr/share/freeswitch/certs
        curl -sSL http://curl.haxx.se/ca/cacert.pem -o $_/cacert.pem
        chown -R $USER:$USER $(dirname $_)

        sed -i '\|<settings>|a \
    <!-- set to true if you want to enable http:// and https:// formats.  Do not use if mod_httapi is also loaded --> \
    <param name="enable-file-formats" value="true"/> \' http_cache.conf.xml
        sed -i '\|location|s|value=".*"|value="/volumes/ram/http_cache"|' $_
        sed -i '\|</settings>|i \
    <!-- absolute path to CA bundle file --> \
    <param name="ssl-cacert" value="/usr/share/freeswitch/certs/cacert.pem"/> \
    <!-- verify certificates --> \
    <param name="ssl-verifypeer" value="true"/> \
    <!-- verify host name matches certificate --> \
    <param name="ssl-verifyhost" value="true"/>' $_
        cat $_
        popd

    pushd scripts
        sed -i 's/whapps/kapps/g;s/wh_/kz_/g;\|your-kazoo-api-fqdn|s|--insecure https://your-kazoo-api-fqdn:8443|http://kazoo:8000|' kazoo-sync.sh


log::m-info "Adding app init to bash profile ..."
tee /etc/entrypoint.d/50-${APP}-init <<'EOF'
# write the erlang cookie
erlang-cookie write
EOF


log::m-info "Cleaning up unneeded packages ..."
apt-get purge -y --auto-remove git


log::m-info "Adding fixattr files ..."
tee /etc/fixattrs.d/20-${APP}-perms <<EOF
/var/lib/freeswitch true freeswitch:freeswitch 0777 0777
/volumes/ram true freeswitch:freeswitch 0777 0777
/volumes/freeswitch/recordings true freeswitch:freeswitch 0777 0777
/volumes/freeswitch/storage true freeswitch:freeswitch 0777 0777
/tmp/freeswitch true freeswitch:freeswitch 0777 0777
EOF


log::m-info "Setting Ownership & Permissions ..."
chown -R $USER:$USER \
    ~ \
    /etc/freeswitch \
    /volumes/{freeswitch,ram,tls} \
    /usr/lib/freeswitch \
    /var/lib/freeswitch \
    /usr/share/freeswitch

chmod -R 0777 \
    /tmp/freeswitch \
    /volumes/freeswitch/{storage,recordings}


log::m-info "Cleaning up ..."
apt-clean --aggressive

# if applicable, clean up after detect-proxy enable
eval $(detect-proxy disable)

rm -r -- "$0"
