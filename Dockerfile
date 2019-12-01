ARG FROM_IMAGE_NAME=alpine:latest
    
### ================================== ###
###   STAGE 1 CREATE PARENT IMAGE      ###
### ================================== ###

FROM $FROM_IMAGE_NAME as mybase

# DO NOT REMOVE THE FOLLOWING LINE
# VITAL FOR BUILDING ARM IMAGES
# COPY qemu-arm-static /usr/bin/

ENV NAGIOS_HOME=/opt/nagios \
    NAGIOS_USER=nagios \
    NAGIOS_GROUP=nagios \
    NAGIOS_CMDUSER=nagios \
    NAGIOS_CMDGROUP=nagios \
    NAGIOS_TIMEZONE=UTC \
    NAGIOS_FQDN=nagios.example.com \
    NAGIOSADMIN_USER=nagiosadmin \
    NAGIOSADMIN_PASS=nagios \
    NAGIOS_BRANCH=nagios-4.4.5 \
    NAGIOS_PLUGINS_BRANCH=release-2.2.1 \
    NRPE_BRANCH=nrpe-3.2.1 \
    APACHE_LOCK_DIR=/var/run \
    APACHE_LOG_DIR=/var/log/apache2


RUN addgroup -S ${NAGIOS_GROUP} && \
    adduser  -S ${NAGIOS_USER} -G ${NAGIOS_CMDGROUP} && \
    apk update && \
    apk add --no-cache git curl unzip apache2 apache2-utils rsyslog \
                        php7 php7-gd php7-cli runit parallel ssmtp \
                        libltdl libintl openssl-dev php7-apache2 procps && \
    wget https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64 && \
    mv gosu-amd64 /bin/gosu && \
    chmod 755 /bin/gosu && \
    chmod +s /bin/gosu && \
    addgroup -S apache ${NAGIOS_CMDGROUP}
   
    
### ================================== ###
###   STAGE 2 COMPILE NAGIOS SOURCES   ###
### ================================== ###

FROM mybase as sourcebuilder

MAINTAINER Christos Manios <maniopaido@gmail.com>

LABEL name="Nagios" \
      nagiosVersion="4.4.5" \
      nagiosPluginsVersion="2.2.1" \
      nrpeVersion="3.2.1" \
      homepage="https://www.nagios.com/" \
      maintainer="Christos Manios <maniopaido@gmail.com>" \
      build="1"

# Add dependencies required to build Nagios
RUN apk update && \
    apk add --no-cache build-base automake libtool autoconf py-docutils gnutls  \
                        gnutls-dev g++ make alpine-sdk build-base gcc autoconf \
                        gettext-dev linux-headers openssl-dev

# Download Nagios core, plugins and nrpe sources                        
RUN    cd /tmp && \
       echo -n "Downloading Nagios ${NAGIOS_BRANCH} source code: " && \
       wget -q -O nagios-core.tar.gz "https://github.com/NagiosEnterprises/nagioscore/archive/${NAGIOS_BRANCH}.tar.gz" && \
       echo -n -e "OK\nDownloading Nagios plugins ${NAGIOS_PLUGINS_BRANCH} source code: " && \
       wget -q -O nagios-plugins.tar.gz "https://github.com/nagios-plugins/nagios-plugins/archive/${NAGIOS_PLUGINS_BRANCH}.tar.gz" && \
       echo -n -e "OK\nDownloading NRPE ${NRPE_BRANCH} source code: " && \
       wget -q -O nrpe.tar.gz "https://github.com/NagiosEnterprises/nrpe/archive/${NRPE_BRANCH}.tar.gz" && \
       echo "OK"

# Compile Nagios Core
RUN    cd /tmp && \
       tar zxf nagios-core.tar.gz && \
       tar zxf nagios-plugins.tar.gz && \
       tar zxf nrpe.tar.gz && \
       cd  "/tmp/nagioscore-${NAGIOS_BRANCH}" && \
       echo -e "\n ===========================\n  Configure Nagios Core\n ===========================\n" && \
       ./configure \
            --prefix=${NAGIOS_HOME}                  \
            --exec-prefix=${NAGIOS_HOME}             \
            --enable-event-broker                    \
            --with-command-user=${NAGIOS_CMDUSER}    \
            --with-command-group=${NAGIOS_CMDGROUP}  \
            --with-nagios-user=${NAGIOS_USER}        \
            --with-nagios-group=${NAGIOS_GROUP}      && \
       echo -n "Replacing \"<sys\/poll.h>\" with \"<poll.h>\": " && \
       sed -i 's/<sys\/poll.h>/<poll.h>/g' ./include/config.h && \
       echo -e "\n\n ===========================\n Compile Nagios Core\n ===========================\n" && \
       make all && \
       echo -e "\n\n ===========================\n  Install Nagios Core\n ===========================\n" && \
       make install && \
       make install-commandmode && \
       make install-config && \
       make install-webconf && \
       echo -n "Nagios installed size: " && \
       du -h -s ${NAGIOS_HOME}

# Compile Nagios Plugins
RUN    echo -e "\n\n ===========================\n  Configure Nagios Plugins\n ===========================\n" && \
       cd  /tmp/nagios-plugins-${NAGIOS_PLUGINS_BRANCH} && \
       ./autogen.sh && \
       ./configure  --with-nagios-user=${NAGIOS_USER} \
                    --with-nagios-group=${NAGIOS_USER} \
                    --with-openssl \
                    --prefix=${NAGIOS_HOME}                                 \
                    --with-ping-command="/bin/gosu root /bin/ping -n -w %d -c %d %s"  \
                    --with-ipv6                                             \
                    --with-ping6-command="/bin/gosu root /bin/ping6 -n -w %d -c %d %s"  && \
       echo "Nagios plugins configured: OK" && \
       echo -n "Replacing \"<sys\/poll.h>\" with \"<poll.h>\": " && \
       egrep -rl "\<sys\/poll.h\>" . | xargs sed -i 's/<sys\/poll.h>/<poll.h>/g' && \
       egrep -rl "\"sys\/poll.h\"" . | xargs sed -i 's/"sys\/poll.h"/"poll.h"/g' && \
       echo "OK" && \
       echo -e "\n\n ===========================\n Compile Nagios Plugins\n ===========================\n" && \
       make && \
       echo "Nagios plugins compile successfully: OK" && \
       echo -e "\n\n ===========================\nInstall Nagios Plugins\n ===========================\n" && \
       make install && \
       echo "Nagios plugins installed successfully: OK"

# Compile NRPE
RUN    echo -e "\n\n =====================\n  Configure NRPE\n =====================\n" && \
       cd  /tmp/nrpe-${NRPE_BRANCH} && \
       ./configure --enable-command-args \
                    --with-nagios-user=${NAGIOS_USER} \
                    --with-nagios-group=${NAGIOS_USER} \
                    --with-ssl=/usr/bin/openssl \
                    --with-ssl-lib=/usr/lib && \
       echo "NRPE client configured: OK" && \
       echo -e "\n\n ===========================\n  Compile NRPE\n ===========================\n" && \
       # make all && \
       make check_nrpe                                                          && \
       echo "NRPE compiled successfully: OK" && \
       echo -e "\n\n ===========================\n  Install NRPE\n ===========================\n" && \
       # make install && \
       cp src/check_nrpe ${NAGIOS_HOME}/libexec/                                && \
       echo "NRPE installed successfully: OK" && \
       echo -n "Final Nagios installed size: " && \
       du -h -s ${NAGIOS_HOME} 

# Compile Nagios files
# Create SSMTP configuration


# RUN sed -i.bak 's/.*\=www\-data//g' /etc/apache2/envvars
RUN export DOC_ROOT="DocumentRoot $(echo $NAGIOS_HOME/share)"                                        && \
    sed -i "s,DocumentRoot.*,$DOC_ROOT," /etc/apache2/httpd.conf                                     && \
    sed -i "s|^ *ScriptAlias.*$|ScriptAlias /cgi-bin $NAGIOS_HOME/sbin|g" /etc/apache2/httpd.conf    && \
    sed -i 's/^\(.*\)#\(LoadModule cgi_module\)\(.*\)/\1\2\3/' /etc/apache2/httpd.conf               && \
    echo "ServerName ${NAGIOS_FQDN}" >> /etc/apache2/httpd.conf

RUN sed -i 's,/bin/mail,/usr/bin/mail,' ${NAGIOS_HOME}/etc/objects/commands.cfg  && \
    sed -i 's,/usr/usr,/usr,'           ${NAGIOS_HOME}/etc/objects/commands.cfg  && \
                                                                                    \  
    : '# Modify Nagios mail commands in order to work with SSMTP'         && \
    sed -i 's/^.*command_line.*Host Alert.*$//g' /opt/nagios/etc/objects/commands.cfg && \
    sed -i 's/^.*command_line.*Service Alert.*$//g' /opt/nagios/etc/objects/commands.cfg && \
    sed -i '/notify-host-by-email/a command_line /usr/bin/printf "%b" "Subject: $NOTIFICATIONTYPE$ Host Alert: $HOSTNAME$ is $HOSTSTATE$\\n\\n***** Nagios *****\\n\\nNotification Type: $NOTIFICATIONTYPE$\\nHost: $HOSTNAME$\\nState: $HOSTSTATE$\\nAddress: $HOSTADDRESS$\\nInfo: $HOSTOUTPUT$\\n\\nDate/Time: $LONGDATETIME$\\n" | /usr/sbin/sendmail -v $CONTACTEMAIL$' ${NAGIOS_HOME}/etc/objects/commands.cfg  && \
    sed -i '/notify-service-by-email/a command_line /usr/bin/printf "%b" "Subject: $NOTIFICATIONTYPE$ Service Alert: $HOSTALIAS$/$SERVICEDESC$ is $SERVICESTATE$\\n\\n***** Nagios *****\\n\\nNotification Type: $NOTIFICATIONTYPE$\\n\\nService: $SERVICEDESC$\\nHost: $HOSTALIAS$\\nAddress: $HOSTADDRESS$\\nState: $SERVICESTATE$\\n\\nDate/Time: $LONGDATETIME$\\n\\nAdditional Info:\\n\\n$SERVICEOUTPUT$\\n" | /usr/sbin/sendmail -v $CONTACTEMAIL$' ${NAGIOS_HOME}/etc/objects/commands.cfg

RUN echo "use_timezone=${NAGIOS_TIMEZONE}" >> ${NAGIOS_HOME}/etc/nagios.cfg && \
    sed -i 's/date_format=us/date_format=iso8601/g' ${NAGIOS_HOME}/etc/nagios.cfg

# Copy original configuration to /orig directory
RUN mkdir -p /orig/apache2                     && \
    cp -r /etc/apache2/*  /orig/apache2        && \
    cp -r ${NAGIOS_HOME}/etc  /orig/etc        && \
    cp -r ${NAGIOS_HOME}/var  /orig/var         

