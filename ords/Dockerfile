FROM oraclelinux:8-slim

# Install required packages first
RUN set -x && microdnf update -y && \
microdnf install -y unzip openssl python3 oracle-instantclient-release-el8 && \
microdnf install -y oracle-instantclient-basic oracle-instantclient-sqlplus && \
rm -Rf /var/cache/yum && \
rm -Rf /var/cache/dnf && \
echo 'alias ll="ls -la"' >> ~/.bashrc

RUN microdnf install -y java-17-openjdk

# Define build Args
ARG ORDS_FULL_VERSION=${ORDS_FULL_VERSION} \
    ORDS_VERSION=${ORDS_VERSION} \
    ORDS_URL=${ORDS_URL} \
    APEX_VERSION=${APEX_VERSION}

# Define environent Vars
ENV ORDS_FULL_VERSION=${ORDS_FULL_VERSION} \
    ORDS_VERSION=${ORDS_VERSION} \
    ORDS_DIR=/opt/ords-${ORDS_VERSION}/ \
    ORDS_CONF_DIR=/etc/ords/config \
    APEX_VERSION=${APEX_VERSION}

ENV ORDS_CONFIG=${ORDS_CONF_DIR} \
    JAVA_OPTS="-Dconfig.url=${ORDS_CONF_DIR} -Xms1024M -Xmx1024M"

# Download binary
ADD ${ORDS_URL} /opt/ords-${ORDS_VERSION}/

# all installation files
COPY scripts /scripts


RUN set -x && chmod +x /scripts/*.sh

# Ports
EXPOSE 8080
EXPOSE 8443

# ENTRYPOINT
ENTRYPOINT ["/scripts/entry_ords.sh"]
