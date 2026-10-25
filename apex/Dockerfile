FROM eclipse-temurin:25-jre-ubi10-minimal

WORKDIR /app

# Install required packages first
RUN ls /etc/yum.repos.d/ && \
microdnf install -y unzip ncurses openssl python3 && \
curl -s https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip > sqlcl-latest.zip && \
unzip sqlcl-latest.zip && \
chmod 755 sqlcl/bin/sql && \
rm -Rf /var/cache/yum && \
rm -Rf /var/cache/dnf && \
echo 'alias ll="ls -la"' >> ~/.bashrc

ENV PATH=/app/sqlcl/bin:$PATH

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
ADD ${APEX_URL} "/tmp/apex_${APEX_VERSION}.zip"
ADD ${APEX_PSET_URL} "/tmp/apex_patch_${APEX_FULL_VERSION}.zip"

# all installation files
COPY scripts /scripts

RUN chmod +x /scripts/*.sh

# NO Ports

# ENTRYPOINT
ENTRYPOINT ["/scripts/entry_apex.sh"]