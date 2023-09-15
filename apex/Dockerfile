FROM oraclelinux:8-slim

# Define some build Args
ARG APEX_VERSION=${APEX_VERSION} \
    APEX_FULL_VERSION=${APEX_FULL_VERSION} \
    APEX_URL=${APEX_URL} \
    APEX_PSET_URL=${APEX_PSET_URL} \
    APEX_IMAGE_PREFIX=${APEX_IMAGE_PREFIX}

ENV APEX_IMAGE_PREFIX=${APEX_IMAGE_PREFIX} \
    APEX_VERSION=${APEX_VERSION} \
    APEX_FULL_VERSION=${APEX_FULL_VERSION} \
    APEX_DIR=/opt/apex-${APEX_VERSION}/ \
    JAVA_OPTS="-Dconfig.url=${ORDS_CONF} -Xms1024M -Xmx1024M"

# Download APEX and APEX PatchSet
ADD ${APEX_URL} "${APEX_DIR}/apex_${APEX_VERSION}_en.zip"
ADD ${APEX_PSET_URL} "${APEX_DIR}/apex_patch.zip"

# all installation files
COPY scripts /scripts

# TODO: Das hier nach ganz oben und allen ein gleiches BaseImage verpacken

# Now Install required packages
RUN set -x && microdnf update -y && \
microdnf install -y unzip openssl python3 oracle-instantclient-release-el8 && \
microdnf install -y oracle-instantclient-basic oracle-instantclient-sqlplus && \
rm -Rf /var/cache/yum && \
rm -Rf /var/cache/dnf && \
echo 'alias ll="ls -la"' >> ~/.bashrc


WORKDIR ${APEX_DIR}

# TODO: Im EntryPoint entpacken
RUN unzip -q apex_${APEX_VERSION}_en.zip && \
    rm apex_${APEX_VERSION}_en.zip && \
    unzip -q apex_patch.zip -d patchset && \
    rm apex_patch.zip && \
    set -x && chmod +x /scripts/*.sh && \
    sync



# ENTRYPOINT
ENTRYPOINT ["/scripts/entry_apex.sh"]