FROM callforamerica/debian

MAINTAINER joe <joe@valuphone.com>

LABEL   lang.name="erlang" \
        lang.version="19.1"

LABEL   app.name="freeswitch" \
        app.version="1.6"

ENV     ERLANG_VERSION=19.0 \
        FREESWITCH_VERSION=1.6

ENV     HOME=/opt/freeswitch

COPY    build.sh /tmp/build.sh
RUN     /tmp/build.sh

COPY    entrypoint /entrypoint

ENV     FREESWITCH_LOG_LEVEL=info

VOLUME  ["/var/lib/freeswitch", "/usr/share/freeswitch/http_cache"]

EXPOSE  4369 8021 8031 11000 16384-24576/udp

# USER    freeswitch

WORKDIR /opt/freeswitch

ENTRYPOINT  ["/dumb-init", "--"]
CMD         ["/entrypoint"]
