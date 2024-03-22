FROM --platform=linux/amd64 ubuntu:20.04
MAINTAINER ome-devel@lists.openmicroscopy.org.uk

#############################################
# ApacheDS installation
#############################################

ENV APACHEDS_VERSION 2.0.0.AM27
ENV APACHEDS_SNAPSHOT 2.0.0.AM28-SNAPSHOT
ENV APACHEDS_ARCH amd64

ENV APACHEDS_ARCHIVE apacheds-${APACHEDS_VERSION}-${APACHEDS_ARCH}.deb
ENV APACHEDS_DATA /var/lib/apacheds
ENV APACHEDS_USER apacheds
ENV APACHEDS_GROUP apacheds
ENV APACHEDS_BOOTSTRAP /bootstrap

RUN ln -s ${APACHEDS_DATA}-${APACHEDS_VERSION} ${APACHEDS_DATA}
VOLUME ${APACHEDS_DATA}

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && apt-get update \
    && apt-get install -y \
       apt-utils \
       ca-certificates \
       ldap-utils \
       procps \
       openjdk-8-jre-headless \
       curl \
       jq \
       python-dev \
       libldap2-dev \
       libsasl2-dev \
       libssl-dev \
       python-pip \
    && pip install python-ldap

RUN curl https://dlcdn.apache.org//directory/apacheds/dist/${APACHEDS_VERSION}/apacheds-${APACHEDS_VERSION}-amd64.deb > ${APACHEDS_ARCHIVE} \
    && dpkg -i ${APACHEDS_ARCHIVE} \
    && rm ${APACHEDS_ARCHIVE}

# Ports defined by the default instance configuration:
# 10389: ldap
# 10636: ldaps
# 60088: kerberos
# 60464: changePasswordServer
# 8080: http
# 8443: https
EXPOSE 10389 10636 60088 60464 8080 8443

#############################################
# ApacheDS bootstrap configuration
#############################################

ADD scripts/run.sh /run.sh
RUN chown ${APACHEDS_USER}:${APACHEDS_GROUP} /run.sh \
    && chmod u+rx /run.sh

ADD instance/* ${APACHEDS_BOOTSTRAP}/conf/
RUN sed -i "s/ads-contextentry:: [A-Za-z0-9\+\=\/]*/ads-contextentry:: $(base64 -w 0 $APACHEDS_BOOTSTRAP/conf/ads-contextentry.decoded)/g" /$APACHEDS_BOOTSTRAP/conf/config.ldif
ADD ome.ldif ${APACHEDS_BOOTSTRAP}/
RUN mkdir ${APACHEDS_BOOTSTRAP}/cache \
    && mkdir ${APACHEDS_BOOTSTRAP}/run \
    && mkdir ${APACHEDS_BOOTSTRAP}/log \
    && mkdir ${APACHEDS_BOOTSTRAP}/partitions \
    && chown -R ${APACHEDS_USER}:${APACHEDS_GROUP} ${APACHEDS_BOOTSTRAP}

ADD bin/ldapmanager /usr/local/bin/ldapmanager

#############################################
# ApacheDS wrapper command
#############################################

# Correct for hard-coded INSTANCES_DIRECTORY variable
RUN sed -i "s#/var/lib/apacheds-${APACHEDS_VERSION}#${APACHEDS_DATA}#" /opt/apacheds-${APACHEDS_SNAPSHOT}/bin/apacheds

RUN curl -L -o /usr/local/bin/dumb-init \
    https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64 && \
    chmod +x /usr/local/bin/dumb-init

ENTRYPOINT ["/run.sh"]
