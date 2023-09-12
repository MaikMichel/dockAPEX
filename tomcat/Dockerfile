FROM oraclelinux:8-slim

# Define some build Args
ARG TOMCAT_VERSION=${TOMCAT_VERSION} \
    TOMCAT_URL=${TOMCAT_URL} \
    ORDS_VERSION=${ORDS_VERSION}

ENV TOMCAT_DIR=/opt/tomcat-${TOMCAT_VERSION} \
    TOMCAT_VERSION=${TOMCAT_VERSION} \
    ORDS_VERSION=${ORDS_VERSION} \
    ORDS_CONF_DIR="/etc/ords/config"

ENV ORDS_CONFIG=${ORDS_CONF_DIR} \
    JAVA_OPTS="-Dconfig.url=${ORDS_CONF_DIR} -Xms1024M -Xmx1024M"


# Download ORDS binary
ADD ${TOMCAT_URL} /tmp/tomcat.tgz


# Now Install required packages
RUN set -x && microdnf update -y && \
    microdnf install -y tar java-17-openjdk && \
    rm -Rf /var/cache/yum && \
    rm -Rf /var/cache/dnf && \
    echo 'alias ll="ls -la"' >> ~/.bashrc


WORKDIR ${TOMCAT_DIR}

RUN mkdir /tmp/tcat && tar xzf /tmp/tomcat.tgz -C /tmp/tcat && \
    mv /tmp/tcat/apache-tomcat-${TOMCAT_VERSION}/* ${TOMCAT_DIR} && \
    rm /tmp/tomcat.tgz && \
    rm -rf /tmp/tcat && \
    sync && \
    rm -rf ${TOMCAT_DIR}/webapps/*

# all installation files
COPY html ${TOMCAT_DIR}/webapps/ROOT
COPY scripts /scripts


EXPOSE 9080
EXPOSE 9443

RUN set -x && chmod +x /scripts/*.sh

# ENTRYPOINT
ENTRYPOINT ["/scripts/entry_tomcat.sh"]
