FROM    callforamerica/debian

MAINTAINER joe <joe@valuphone.com>

ARG     ERLANG_VERSION
ARG     FREESWITCH_VERSION
ARG     KAZOO_CONFIGS_BRANCH
        # if choosing a module for mod a codec, use FREESWITCH_INSTALL_CODECS instead
        # options: abstraction,amqp,amr,amrwb,av,avmd,b64,basic,bert,blacklist,bv,callcenter,cdr-csv,cdr-mongodb,cdr-sqlite,cidlookup,cluechoo,codec2,commands,conference,console,curl,cv,dahdi-codec,db,dialplan-asterisk,dialplan-directory,dialplan-xml,dingaling,directory,distributor,dptools,easyroute,enum,erlang-event,esf,esl,event-multicast,event-socket,expr,fifo,flite,format-cdr,fsk,fsv,g723-1,g729,graylog2,h26x,hash,hiredis,httapi,http-cache,ilbc,imagick,isac,java,json-cdr,kazoo,lcr,ldap,local-stream,logfile,loopback,lua,managed,memcache,mod-say,mongo,mp4,mp4v,native-file,nibblebill,odbc-cdr,opus,oreka,perl,png,pocketsphinx,portaudio,portaudio-stream,posix-timer,prefix,python,rayo,redis,rss,rtc,rtmp,sangoma-codec,say-de,say-en,say-es,say-es-ar,say-fa,say-fr,say-he,say-hr,say-hu,say-it,say-ja,say-nl,say-pl,say-pt,say-ru,say-sv,say-th,say-zh,shell-stream,shout,silk,siren,skinny,skypopen,sms,snapshot,sndfile,snmp,snom,sofia,sonar,soundtouch,spandsp,spy,ssml,stress,syslog,theora,timerfd,tone-stream,translate,tts-commandline,unimrcp,v8,valet-parking,verto,vlc,vmd,voicemail,voicemail-ivr,vpx,xml-cdr,xml-curl,xml-ldap,xml-rpc,xml-scgi,yaml
ARG     FREESWITCH_INSTALL_MODS
ARG     FREESWITCH_INSTALL_CODECS
        # options: de,en,es,fr,he,lang,pt,ru,sv
ARG     FREESWITCH_INSTALL_LANGS
        # options: all,bare,codecs,conf,default,lang,mod-say,sorbet,vanilla
ARG     FREESWITCH_INSTALL_META
ARG     FREESWITCH_INSTALL_DEBUG
ARG     FREESWITCH_LOAD_MODS

ENV     ERLANG_VERSION=${ERLANG_VERSION:-19.0} \
        FREESWITCH_VERSION=${FREESWITCH_VERSION:-1.6} \
        KAZOO_CONFIGS_BRANCH=${KAZOO_CONFIGS_BRANCH:-master} \
        FREESWITCH_INSTALL_MODS=${FREESWITCH_INSTALL_MODS:-commands,conference,console,dptools,dialplan-xml,enum,event-socket,flite,http-cache,local-stream,loopback,say-en,sndfile,sofia,tone-stream} \
        FREESWITCH_INSTALL_CODECS=${FREESWITCH_INSTALL_CODECS:-amr,amrwb,g723-1,g729,h26x,ilbc,opus,shout,silk,siren,spandsp} \
        FREESWITCH_INSTALL_LANGS=${FREESWITCH_INSTALL_LANGS:-en,es,ru} \
        FREESWITCH_INSTALL_META=${FREESWITCH_INSTALL_META:-} \
        FREESWITCH_INSTALL_DEBUG=${FREESWITCH_INSTALL_DEBUG:-false} \
        FREESWITCH_LOAD_MODS=${FREESWITCH_LOAD_MODULES:-g729,silk} 


LABEL   lang.erlang.version=$ERLANG_VERSION
LABEL   app.freeswitch.version=$FREESWITCH_VERSION

ENV     HOME=/opt/freeswitch

COPY    build.sh /tmp/build.sh
RUN     /tmp/build.sh

# bug with docker hub automated builds when interating with root directory
# ref: https://forums.docker.com/t/automated-docker-build-fails/22831/27
# COPY    entrypoint /entrypoint
COPY    entrypoint /tmp/
RUN     mv /tmp/entrypoint /

ENV     FREESWITCH_LOG_LEVEL=info

VOLUME  ["/volumes/ram/", \
         "/volumes/freeswitch/storage", \
         "/volumes/freeswitch/recordings"]

EXPOSE  4369 8021 8031 11000 16384-24576/udp

# USER    freeswitch

WORKDIR /opt/freeswitch

ENTRYPOINT  ["/dumb-init", "--"]
CMD         ["/entrypoint"]
