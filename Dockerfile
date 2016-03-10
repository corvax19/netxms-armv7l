FROM resnullius/alpine-armv7l
MAINTAINER Romans Krjukovs <romans.krjukovs@gmail.com>

ENV nxver=2.0.1 \
    netxms_prefix=/opt/netxms \
    netxmsd_cfg=${netxms_prefix}/etc/netxmsd.conf

RUN apk update \
 && apk add alpine-sdk \
            openssl-dev \
            libcrypto1.0 \
            postgresql-dev \ 
            perl \
            sudo \
            curl curl-dev

RUN export kernel=$(uname -r|egrep -o '^[0-9]+\.[0-9]+(\.[0-9]+)?') \
 && echo "Downloading kernel v${kernel}..." \
 && cd /tmp \
 && wget https://www.kernel.org/pub/linux/kernel/v4.x/linux-${kernel}.tar.gz \
 && tar zxvf linux-${kernel}.tar.gz \
 && cd /tmp/linux-${kernel} \
 && make mrproper \
 && make INSTALL_HDR_PATH=/tmp headers_install \
 && rm -rf /tmp/linux*

RUN cd /tmp \
 && wget https://www.netxms.org/download/archive/netxms-${nxver}.tar.gz \
 && tar zxvf netxms-${nxver}.tar.gz \
 && cd /tmp/netxms-${nxver} \
 && CPPFLAGS="-I/tmp/include" ./configure \
    --prefix=${netxms_prefix} \
    --with-server \
    --with-agent \
    --with-snmp \
    --with-pgsql \
    --with-openssl \
    --without-sqlite \
    --disable-ipv6 \
    --enable-unicode \
    --enable-static \
    --with-all-static \
 && make -j4 \
 && make install \
 && rm -rf /tmp/netxms*

RUN mkdir /var/lib/pgsql \
 && chown postgres:postgres /var/lib/pgsql/ \
 && sudo -u postgres pg_ctl -D /var/lib/pgsql/data initdb \
 && sudo -u postgres pg_ctl -D /var/lib/pgsql/data start \
 && sleep 5s \
 && sudo -u postgres /usr/bin/createdb -h 127.0.0.1 -p 5432 -E SQL_ASCII -T template0 -e netxms \
 && sudo -u postgres /usr/bin/psql -c "CREATE USER netxms WITH PASSWORD 'netxms';" \
 && sudo -u postgres /usr/bin/psql -c "GRANT ALL PRIVILEGES ON DATABASE \"netxms\" TO netxms;" \
 && sudo -u postgres /usr/bin/psql -f /opt/netxms/share/netxms/sql/dbinit_pgsql.sql netxms netxms \
 && sudo -u postgres pg_ctl -D /var/lib/pgsql/data stop

ADD netxmsd.conf /etc
ADD nxagentd.conf /etc

EXPOSE 4701

#ENTRYPOINT "sudo -u postgres pg_ctl -D /var/lib/pgsql/data start && sleep 5 && /opt/netxms/bin/netxmsd"
#ENTRYPOINT "sudo -u postgres pg_ctl -D /var/lib/pgsql/data start"
#ENTRYPOINT "ash"
