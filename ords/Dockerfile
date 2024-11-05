FROM ghcr.io/graalvm/graalvm-ce:ol8-java17-22.3.3

# Install required packages first
RUN ls /etc/yum.repos.d/ && \
microdnf install unzip ncurses openssl python3 && \
gu install js && \
curl -s https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip > sqlcl-latest.zip && \
unzip sqlcl-latest.zip && \
chmod 755 sqlcl/bin/sql && \
rm -Rf /var/cache/yum && \
rm -Rf /var/cache/dnf && \
echo 'alias ll="ls -la"' >> ~/.bashrc
ENV PATH=/app/sqlcl/bin:$PATH

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
