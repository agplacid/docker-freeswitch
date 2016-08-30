FROM debian:jessie

MAINTAINER joe <joe@valuphone.com>

LABEL   os="linux" \
        os.distro="debian" \
        os.version="jessie"

LABEL   lang.name="erlang" \
        lang.version="19.0.4"

LABEL   app.name="freeswitch" \
        app.version="1.6"

ENV     ERLANG_VERSION=19.0.4 \
        FREESWITCH_VERSION=1.6

ENV     HOME=/opt/freeswitch
ENV     PATH=$HOME/bin:$PATH

COPY    setup.sh /tmp/setup.sh
RUN     /tmp/setup.sh

COPY    entrypoint /usr/bin/entrypoint

ENV     FREESWITCH_LOG_LEVEL=info

VOLUME  ["/var/lib/freeswitch", "/var/cache/freeswitch", "/usr/share/freeswitch"]

EXPOSE  4369 8021 8031 11000 16384-24576/udp

# USER    freeswitch

WORKDIR /opt/freeswitch

CMD     ["/usr/bin/entrypoint"]
