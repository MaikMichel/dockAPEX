#!/bin/bash

## VARS
CONN_STRING_FILE="/opt/oracle/config.env"
APEX_IMAGE_DIR="/opt/oracle/images"

printf "%s%s\n" "INFO : " "This container will start a service running ORDS $ORDS_VERSION."

### Check connection vars inside file
function check_conn_definition() {
  if [[ -f $CONN_STRING_FILE ]]; then
    source $CONN_STRING_FILE


    ORDS_PASSWORD=$(<"/run/secrets/ords_pwd")
    DB_PASS=$(<"/run/secrets/db_pwd")

    if [[ -n "$DB_USER" ]] && [[ -n "$DB_PASS" ]] && [[ -n "$DB_HOST" ]]  && [[ -n "$DB_PORT" ]]  && [[ -n "$DB_NAME" ]] ; then
      printf "%s%s\n" "INFO : " "All Connection vars has been found in the container variables file."
    else
      printf "\a%s%s\n" "ERROR: " "NOT all vars found in the container variables file."
      printf "%s%s\n"   "       " "   DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME     "
      exit 1
    fi
  else
    printf "\a%s%s\n" "ERROR: " "${CONN_STRING_FILE} has not added, create a file with"
    printf "\a%s%s\n" "       " "  DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME variables"
    printf "\a%s%s\n" "       " "  and added as docker volume:"
    exit 1
  fi
}

function try_connect() {
  local display_conn="${DB_USER}/*****@${DB_HOST}:${DB_PORT}/${1}"
  local value_conn="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${1}"

  printf "%s%s\n" "WAIT : " "Try connection to DB: ${display_conn}"

  COUNTER=0
  while [  $COUNTER -lt 20 ]; do
    sqlplus -S -L /nolog << EOF
  whenever sqlerror exit failure
  whenever oserror exit failure
  set serveroutput off
  set heading off
  set feedback off
  set pages 0
  conn ${value_conn} as sysdba
  select 'DB   : Connection is working' from dual;
  exit
EOF

    RESULT=$?

    if [ ${RESULT} -eq 0 ] ; then
      printf "%s%s\n" "INFO : " "Database connection established."
      let COUNTER=20
    else
      let COUNTER=COUNTER+1
      printf "%s%s\n" "INFO : " "Waiting to connect for 5s ${COUNTER}/20"
      sleep 5s

      if [[ ${COUNTER} -eq 20 ]]; then
        printf "\a%s%s\n" "ERROR: " "Cannot connect to database please validate Connection Vars"
        printf "%s%s\n"   "       " "   user/password@hostname:port/service_name"
        exit 1
      fi
    fi
  done
}

function testDB() {
  check_conn_definition

  try_connect ${DB_NAME}

  if [[ ${APEX_SECND_PDB,,} == "true" ]]; then
    try_connect ${APEX_SECND_PDB_NAME}
  fi
}

function install_ords() {
  printf "%s%s\n" "INFO : " "========================================"
  printf "%s%s\n" "INFO : " "========================================"
  printf "%s%s\n" "INFO : " "========================================"
  printf "%s%s\n" "INFO : " "Preparing ORDS - ${DB_NAME}"

  SQLPLUS_ARGS="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME} as sysdba"

  sqlplus /nolog << EOF
    conn ${SQLPLUS_ARGS}

    Prompt setting PWD for APEX_PUBLIC_USER
    alter user APEX_PUBLIC_USER identified by "$ORDS_PASSWORD" account unlock;

    Prompt calling apex_rest_config_core
    @apex_rest_config_core @ $ORDS_PASSWORD $ORDS_PASSWORD

EOF

  ${ORDS_DIR}bin/ords --config ${ORDS_CONF_DIR} install \
      --log-folder ${ORDS_CONF_DIR}/logs/${DB_NAME} \
      --admin-user SYS \
      --db-hostname ${DB_HOST} \
      --db-port ${DB_PORT} \
      --db-servicename ${DB_NAME} \
      --feature-db-api true \
      --feature-rest-enabled-sql true \
      --feature-sdw true \
      --gateway-mode proxied \
      --gateway-user APEX_PUBLIC_USER \
      --proxy-user \
      --password-stdin <<EOF
${DB_PASS}
${ORDS_PASSWORD}
EOF


  if [[ ${APEX_SECND_PDB,,} == "true" ]]; then
    printf "%s%s\n" "INFO : " "========================================"
    printf "%s%s\n" "INFO : " "========================================"
    printf "%s%s\n" "INFO : " "========================================"
    printf "%s%s\n" "INFO : " "Preparing ORDS - ${APEX_SECND_PDB_NAME}"

    SQLPLUS_ARGS="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${APEX_SECND_PDB_NAME} as sysdba"
    sqlplus /nolog << EOF
    conn ${SQLPLUS_ARGS}

    Prompt setting PWD for APEX_PUBLIC_USER
    alter user APEX_PUBLIC_USER identified by "$ORDS_PASSWORD" account unlock;

    Prompt calling apex_rest_config_core
    @apex_rest_config_core @ $ORDS_PASSWORD $ORDS_PASSWORD

EOF


    ${ORDS_DIR}bin/ords --config ${ORDS_CONF_DIR} install \
          --log-folder ${ORDS_CONF_DIR}/logs/${APEX_SECND_PDB_NAME} \
          --db-pool ${APEX_SECND_PDB_POOL_NAME,,} \
          --admin-user SYS \
          --db-hostname ${DB_HOST} \
          --db-port ${DB_PORT} \
          --db-servicename ${APEX_SECND_PDB_NAME} \
          --feature-db-api true \
          --feature-rest-enabled-sql true \
          --feature-sdw true \
          --gateway-mode proxied \
          --gateway-user APEX_PUBLIC_USER \
          --proxy-user \
          --password-stdin <<EOF
${DB_PASS}
${ORDS_PASSWORD}
EOF

  fi


  if [[ ${TOMCAT,,} == "true" ]]; then
    # Add forceHTTPs, when TOMCAT Mode
    SETTINGS_XML="${ORDS_CONF_DIR}/global/settings.xml"
    FORCS_HTML='<entry key="security.forceHTTPS">true</entry>'
    sed -i "/<\/properties>/i ${FORCS_HTML}" "${SETTINGS_XML}"
  fi
}


function run_ords() {
  # ords_entrypoint_dir
  # config_sdw
  if [ -e $ORDS_CONF_DIR/databases/default/pool.xml ]; then
    DB_HOST=$(grep db.hostname $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
    DB_PORT=$(grep db.port $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
    DB_NAME=$(grep db.servicename $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
    printf "%s%s\n" "INFO : " "Starting the ORDS services with the following database details:"
    printf "%s%s\n" "INFO : " "  ${DB_HOST}:${DB_PORT}/${DB_NAME}."
  else
    printf "%s%s\n" "INFO : " "Starting the ORDS services."
  fi

  if [[ ${TOMCAT,,} != "true" ]]; then
    printf "\a%s%s\n" "INFO : " "ORDS will serve ..."
    echo "Mode for ORDS = 'ORDS'" > "${APEX_IMAGE_DIR}/ords_mode.txt"

    export CERT_FILE="$ORDS_CONF_DIR/ssl/cert.crt"
    export KEY_FILE="$ORDS_CONF_DIR/ssl/key.key"

    # Access to a shared docker volume leads to a docker abort!!!
    # So I copy the images to this dir / volume
    # ORDS_IMAGE_DIR="/opt/oracle/ords_images"
    # [[ -d "${ORDS_IMAGE_DIR}" ]] || mkdir "${ORDS_IMAGE_DIR}"
    # rm -rf ${ORDS_IMAGE_DIR}/*
    # cp -rf ${APEX_IMAGE_DIR} ${ORDS_IMAGE_DIR}

    ORDS_IMAGE_DIR=${APEX_IMAGE_DIR}

    if [ -e ${CERT_FILE} ] && [ -e ${KEY_FILE} ]
    then
      ${ORDS_DIR}bin/ords --config $ORDS_CONF_DIR serve --port 8080 --apex-images ${ORDS_IMAGE_DIR} --secure --certificate ${CERT_FILE} --key  ${KEY_FILE}
    else
      ${ORDS_DIR}bin/ords --config $ORDS_CONF_DIR serve --port 8080 --apex-images ${ORDS_IMAGE_DIR}
    fi
  else
    printf "\a%s%s\n" "INFO : " "Tomcat for the win ..."
    echo "Mode for ORDS = 'TOMCAT'" > "${APEX_IMAGE_DIR}/ords_mode.txt"
  fi
}


function run_script() {
  export _JAVA_OPTIONS="-Xms1126M -Xmx1126M"
  if [ -e $ORDS_CONF_DIR/databases/default/pool.xml ]; then
    # we have a configuration, so lets check if there is something to do
    if [ -e "${CONN_STRING_FILE}" ]; then
      ## check connection
      testDB

      ## install
      printf "\a%s%s\n" "WARN : " "The container will start with the detected configuration..."
      run_ords
      # if [ "${IGNORE_APEX}" == "TRUE" ]; then
      #   printf "\a%s%s\n" "WARN : " "The IGNORE_APEX variable is TRUE, Oracle APEX will not be Installed, Upgraded or Configured on your Database"
      # else
      #   apex
      # fi
      # if [ "${INS_STATUS}" == "INSTALLED" ]; then
      #   run_ords
      # elif [ "${INS_STATUS}" == "UPGRADE" ]; then
      #   install_ords
      #   run_ords
      # elif [ "${INS_STATUS}" == "FRESH" ]; then
      #   install_ords
      #   run_ords
      # fi
    else
      printf "\a%s%s\n" "WARN : " "A conn_string file has not been provided, but a mounted configuration has been detected in /etc/ords/config."
      printf "\a%s%s\n" "WARN : " "The container will start with the detected configuration."
      run_ords
    fi
  else
    # No config file so we try
    if [ -e $CONN_STRING_FILE ]; then
      testDB

      # if [ "${IGNORE_APEX}" == "TRUE" ]; then
      #   printf "\a%s%s\n" "WARN : " "The IGNORE_APEX variable is TRUE, Oracle APEX will not be Installed, Upgraded or Configured on your Database"
      # else
      #   apex
      # fi
      install_ords

      run_ords
    else
      printf "\a%s%s\n" "WARN : " "Nothing configured jet"
    fi
  fi
}
run_script


tail -f /dev/null