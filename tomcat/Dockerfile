FROM oraclelinux:8-slim

# Install required packages first
RUN set -x && microdnf update -y && \
    microdnf install -y tar java-17-openjdk && \
    rm -Rf /var/cache/yum && \
    rm -Rf /var/cache/dnf && \
    echo 'alias ll="ls -la"' >> ~/.bashrc

# Define build Args
ARG TOMCAT_VERSION=${TOMCAT_VERSION} \
    TOMCAT_URL=${TOMCAT_URL} \
    ORDS_VERSION=${ORDS_VERSION} \
    TOMCAT_DIR=/opt/tomcat-${TOMCAT_VERSION}

# Download binary
ADD ${TOMCAT_URL} /tmp/tomcat.tgz

# Define environent Vars
ENV TOMCAT_DIR=${TOMCAT_DIR} \
    TOMCAT_VERSION=${TOMCAT_VERSION} \
    ORDS_VERSION=${ORDS_VERSION} \
    ORDS_CONF_DIR="/etc/ords/config"

# Make use of ORDS_CONF_DIR

ENV ORDS_CONFIG=${ORDS_CONF_DIR} \
    JAVA_OPTS="-Dconfig.url=${ORDS_CONF_DIR} -Xms1024M -Xmx1024M"


# all installation files
COPY scripts /scripts

# set working dir
WORKDIR ${TOMCAT_DIR}

# TODO: Im EntryPoint entpacken
RUN mkdir /tmp/tcat && tar xzf /tmp/tomcat.tgz -C /tmp/tcat && \
    mv /tmp/tcat/apache-tomcat-${TOMCAT_VERSION}/* ${TOMCAT_DIR} && \
    rm /tmp/tomcat.tgz && \
    rm -rf /tmp/tcat && \
    sync && \
    set -x && chmod +x /scripts/*.sh && \
    rm -rf ${TOMCAT_DIR}/webapps/*

# index and error files
COPY html ${TOMCAT_DIR}/webapps/ROOT

# Ports
EXPOSE 9080
EXPOSE 9443

RUN

# ENTRYPOINT
ENTRYPOINT ["/scripts/entry_tomcat.sh"]
