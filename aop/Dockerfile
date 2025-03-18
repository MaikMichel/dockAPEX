FROM apexrnd/apexofficeprint

# Let's install curl, just to enable healthcheck
RUN apt-get update && apt-get install -y curl && \
curl -s https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip > sqlcl-latest.zip && \
unzip sqlcl-latest.zip && \
chmod 755 sqlcl/bin/sql && \
rm -Rf /var/cache/yum && \
rm -Rf /var/cache/dnf && \
echo 'alias ll="ls -la"' >> ~/.bashrc

ENV PATH=/sqlcl/bin:$PATH

# Define build Args
ARG APEX_FULL_VERSION=${APEX_FULL_VERSION}

# Define environent Vars
ENV APEX_FULL_VERSION=${APEX_FULL_VERSION}

# all installation files
COPY scripts /scripts
COPY db /db

RUN set -x && chmod +x /scripts/*.sh

# NO Ports

# ENTRYPOINT
ENTRYPOINT ["/scripts/entry_aop.sh"]