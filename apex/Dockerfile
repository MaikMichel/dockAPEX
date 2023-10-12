FROM oraclelinux:8-slim

# Install required packages first
RUN set -x && microdnf update -y && \
microdnf install -y unzip openssl python3 oracle-instantclient-release-el8 && \
microdnf install -y oracle-instantclient-basic oracle-instantclient-sqlplus && \
rm -Rf /var/cache/yum && \
rm -Rf /var/cache/dnf && \
echo 'alias ll="ls -la"' >> ~/.bashrc

# Define build Args
ARG APEX_VERSION=${APEX_VERSION} \
    APEX_FULL_VERSION=${APEX_FULL_VERSION} \
    APEX_URL=${APEX_URL} \
    APEX_PSET_URL=${APEX_PSET_URL} \
    APEX_DIR=/opt/oracle/apex-${APEX_VERSION}/ \
    APEX_IMAGE_PREFIX=${APEX_IMAGE_PREFIX}

# Define environent Vars
ENV APEX_IMAGE_PREFIX=${APEX_IMAGE_PREFIX} \
    APEX_VERSION=${APEX_VERSION} \
    APEX_FULL_VERSION=${APEX_FULL_VERSION} \
    APEX_DIR=/opt/oracle/apex-${APEX_VERSION}/

# Download binary
ADD ${APEX_URL} "${APEX_DIR}/apex_${APEX_VERSION}_en.zip"
ADD ${APEX_PSET_URL} "${APEX_DIR}/apex_patch.zip"

# all installation files
COPY scripts /scripts

RUN set -x && chmod +x /scripts/*.sh

# NO Ports

# ENTRYPOINT
ENTRYPOINT ["/scripts/entry_apex.sh"]