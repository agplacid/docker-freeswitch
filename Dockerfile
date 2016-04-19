FROM debian:jessie

MAINTAINER joe <joe@valuphone.com>

LABEL   os="linux" \
        os.distro="debian" \
        os.version="jessie"

LABEL   app.name="freeswitch" \
        app.version="1.6"

ENV     TERM=xterm \
        HOME=/var/lib/freeswitch \
        PATH=/var/lib/freeswitch/bin:$PATH

COPY    setup.sh /tmp/setup.sh
RUN     /tmp/setup.sh

COPY    entrypoint /usr/bin/entrypoint

ENV     KUBERNETES_HOSTNAME_FIX=true \
        FREESWITCH_USE_LONGNAME=true

VOLUME  ["/var/lib/freeswitch"]

EXPOSE  4369 1719/udp 1720 3478/udp 3479/udp 5002 5003/udp 5060 5060/udp 5070 5070/udp 5080 5080/udp 8021 5066 7443 11000 11001 16384-24576/udp

# USER    freeswitch

WORKDIR /var/lib/freeswitch

CMD     ["/usr/bin/entrypoint"]
