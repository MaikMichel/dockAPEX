FROM oraclelinux:8-slim

# Define some build Args
ARG ORDS_FULL_VERSION=${ORDS_FULL_VERSION} \
    ORDS_VERSION=${ORDS_VERSION}

ENV ORDS_FULL_VERSION=${ORDS_FULL_VERSION} \
    ORDS_VERSION=${ORDS_VERSION} \
    ORDS_DIR=/opt/ords-${ORDS_VERSION}/ \
    ORDS_CONF_DIR="/etc/ords/config"

ENV JAVA_OPTS="-Dconfig.url=${ORDS_CONF_DIR} -Xms1024M -Xmx1024M" \
    ORDS_CONFIG=${ORDS_CONF_DIR}

# Download ORDS binary
ADD https://download.oracle.com/otn_software/java/ords/ords-${ORDS_FULL_VERSION}.zip ${ORDS_DIR}

# all installation files
COPY scripts /scripts

# Now Install required packages
RUN set -x && microdnf update -y && \
    microdnf install -y unzip oracle-instantclient-release-el8 && \
    microdnf install -y oracle-instantclient-basic oracle-instantclient-sqlplus java-17-openjdk && \
    rm -Rf /var/cache/yum && \
    rm -Rf /var/cache/dnf && \
    echo 'alias ll="ls -la"' >> ~/.bashrc


WORKDIR ${ORDS_DIR}

RUN unzip -q ords-${ORDS_FULL_VERSION}.zip && \
    rm ords-${ORDS_FULL_VERSION}.zip && \
    chmod +x bin/ords && \
    set -x && chmod +x /scripts/*.sh && \
    sync

EXPOSE 8080
EXPOSE 8443

# ENTRYPOINT
ENTRYPOINT ["/scripts/entry_ords.sh"]
