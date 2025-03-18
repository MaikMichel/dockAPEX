#!/bin/bash

## VARS
CONFIG_FILE="/opt/oracle/config.env"
ORDS_IMAGE_DIR="/opt/oracle/images"

function output {
  case "$1" in
    SUCCESS)
      printf "\e[32m%s%s\e[0m\n" "INFO : " "$2"
      ;;
    INFO)
      printf "\e[94m%s%s\e[0m\n" "INFO : " "$2"
      ;;
    WARN)
      printf "\e[33m%s%s\e[0m\n" "WARN : " "$2"
      ;;
    WAIT)
      printf "\e[33m%s%s\e[0m\n" "WAIT : " "$2"
      ;;
    ERROR)
      printf "\e[31m%s%s\e[0m\n" "ERROR: " "$2"
      ;;
    *)
      printf "%s%s\n" "        " "$1"
      ;;
  esac  
}


function read_env_conf_file() {
  if [[ -f $CONFIG_FILE ]]; then
    source $CONFIG_FILE
  else
    output "ERROR" "${CONFIG_FILE} not found!"
    exit 1
  fi
}

function check_conn_definition() {
  # read DB password
  DB_PASS=$(<"/run/secrets/oracle_pwd")

  # read ORDS password
  ORDS_PASSWORD=$(<"/run/secrets/ords_pwd")

  if [[ -n "$DB_USER" ]] && [[ -n "$DB_PASS" ]] && [[ -n "$DB_HOST" ]]  && [[ -n "$DB_PORT" ]]  && [[ -n "$DB_NAME" ]] ; then
    output "INFO" "All Connection vars has been found in the container variables file."
    SQLPLUS_ARGS="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME} as sysdba"
    if [[ ${APEX_SECND_PDB,,} == "true" ]]; then
      SQLPLUS_ARGS2="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${APEX_SECND_PDB_NAME} as sysdba"
    fi
  else
    output "ERROR" "NOT all vars found in the container variables file."
    output " DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME"
    exit 1
  fi
}

function try_connect() {
  local display_conn="${DB_USER}/*****@${DB_HOST}:${DB_PORT}/${1}"
  local value_conn="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${1}"

  output "WAIT" "Try connection to DB: ${display_conn}"

  COUNTER=0
  while [  $COUNTER -lt 20 ]; do
    sql -S -L /nolog << EOF
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
      output "INFO" "Database connection established."
      let COUNTER=20
    else
      let COUNTER=COUNTER+1
      output "INFO" "Waiting to connect for 5s ${COUNTER}/20"
      sleep 5s

      if [[ ${COUNTER} -eq 20 ]]; then
        output "ERROR" "Cannot connect to database please validate Connection Vars"
        output " user/password@hostname:port/service_name"
        exit 1
      fi
    fi
  done
}

function check_database() {
  # check if configuration vars are present
  check_conn_definition

  # let's check the connection itself
  try_connect ${DB_NAME}

  # when a second PDB is configured, let's check that too
  if [[ ${APEX_SECND_PDB,,} == "true" ]]; then
    try_connect ${APEX_SECND_PDB_NAME}
  fi
}

function install_ords() {
  output "INFO" "========================================"
  output "INFO" "========================================"
  output "INFO" "========================================"
  output "INFO" ""

  APEX_PROXIED=""
  if [[ "$APEX" == true ]]; then
    output "INFO" "Config APEX_PUBLIC_USER"

    sql /nolog << EOF
      conn ${SQLPLUS_ARGS}

      Prompt setting PWD for APEX_PUBLIC_USER
      alter user APEX_PUBLIC_USER account unlock;

EOF

    APEX_PROXIED="--gateway-mode proxied --gateway-user APEX_PUBLIC_USER"
  fi

  ${ORDS_DIR}bin/ords --config ${ORDS_CONF_DIR} install \
      --log-folder ${ORDS_CONF_DIR}/logs/${DB_NAME} \
      --admin-user SYS \
      --db-hostname ${DB_HOST} \
      --db-port ${DB_PORT} \
      --db-servicename ${DB_NAME} \
      --feature-db-api true \
      --feature-rest-enabled-sql true \
      --feature-sdw true ${APEX_PROXIED} \
      --proxy-user \
      --password-stdin <<EOF
${DB_PASS}
${ORDS_PASSWORD}
EOF


  if [[ ${APEX_SECND_PDB,,} == "true" ]]; then
    if [[ "$APEX" == true ]]; then
      output "INFO" "Config APEX_PUBLIC_USER in second PDB"

      sql /nolog << EOF
      conn ${SQLPLUS_ARGS2}

      Prompt setting PWD for APEX_PUBLIC_USER
      alter user APEX_PUBLIC_USER account unlock;

EOF

    fi

    ${ORDS_DIR}bin/ords --config ${ORDS_CONF_DIR} install \
          --log-folder ${ORDS_CONF_DIR}/logs/${APEX_SECND_PDB_NAME} \
          --db-pool ${APEX_SECND_PDB_POOL_NAME,,} \
          --admin-user SYS \
          --db-hostname ${DB_HOST} \
          --db-port ${DB_PORT} \
          --db-servicename ${APEX_SECND_PDB_NAME} \
          --feature-db-api true \
          --feature-rest-enabled-sql true \
          --feature-sdw true ${APEX_PROXIED} \
          --proxy-user \
          --password-stdin <<EOF
${DB_PASS}
${ORDS_PASSWORD}
EOF

  fi


  if [[ ${TRAEFIK,,} == "true" ]]; then
    # Add forceHTTPs, when TRAEFIK (Reverse Proxy) Mode
    SETTINGS_XML="${ORDS_CONF_DIR}/global/settings.xml"
    FORCS_HTML='<entry key="security.forceHTTPS">true</entry>'
    sed -i "/<\/properties>/i ${FORCS_HTML}" "${SETTINGS_XML}"
  fi
}

function check_ords_version() {
  # check if ORDS is installed and what version is present
  sql -S -L /nolog << EOF > /tmp/ords_version 2> /dev/null
  conn ${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME} as sysdba
  SET LINESIZE 20000 TRIM ON TRIMSPOOL ON
  SET PAGESIZE 0
  select substr(version, 1, instr(version, '.', 1, 3)-1) as version
    from ords_metadata.ords_version;
EOF

  # Get RPM installed version
  YEAR=$(echo $ORDS_VERSION | cut -d"." -f1)
  QTR=$(echo $ORDS_VERSION | cut -d"." -f2)
  PATCH=$(echo $ORDS_VERSION| cut -d"." -f3)

  # Get DB installed version
  ORDS_DB_VERSION=$(cat /tmp/ords_version|grep [0-9][0-9].[1-5].[0-9] |sed '/^$/d'|sed 's/ //g')
  DB_YEAR=$(echo $ORDS_DB_VERSION | cut -d"." -f1)
  DB_QTR=$(echo $ORDS_DB_VERSION | cut -d"." -f2)
  DB_PATCH=$(echo $ORDS_DB_VERSION | cut -d"." -f3)

  grep "Error at" /tmp/ords_version > /dev/null
  RESULT=$?

  if [[ ${RESULT} -eq 0 ]]; then
    output "ERROR" "AOP Version could not be determined in ${DB_NAME}"      
    INS_STATUS="FRESH"
  else

    if [[ -n "$ORDS_DB_VERSION" ]]; then
      # Validate if an upgrade needed
      if [[ "$ORDS_DB_VERSION" = "$ORDS_VERSION" ]]; then
        output "INFO" "ORDS $ORDS_VERSION is already installed in your database."
        INS_STATUS="INSTALLED"
      elif [[ $DB_YEAR -gt $YEAR ]]; then
        output "ERROR" "A newer ORDS version ($ORDS_DB_VERSION) is already installed in your database. The ORDS version in this container is ${ORDS_VERSION}. Stopping the container."
        exit 1
      elif [[ $DB_YEAR -eq $YEAR ]] && [[ $DB_QTR -gt $QTR ]]; then
        output "ERROR" "A newer ORDS version ($ORDS_DB_VERSION) is already installed in your database. The ORDS version in this container is ${ORDS_VERSION}. Stopping the container."
        exit 1
      elif [[ $DB_YEAR -eq $YEAR ]] && [[ $DB_QTR -eq $QTR ]] && [[ $DB_PATCH -gt $PATCH ]]; then
        output "ERROR" "A newer ORDS version ($ORDS_DB_VERSION) is already installed in your database. The ORDS version in this container is ${ORDS_VERSION}. Stopping the container."
        exit 1
      else
        output "INFO" "Your have installed ORDS ($ORDS_DB_VERSION) on you database but will be upgraded to ${ORDS_VERSION}."
        INS_STATUS="UPGRADE"
      fi
    else
      output "INFO" "ORDS is not installed on your database."
      INS_STATUS="FRESH"
    fi
  fi
}

function run_ords() {
  # ords_entrypoint_dir
  # config_sdw
  if [ -e $ORDS_CONF_DIR/databases/default/pool.xml ]; then
    DB_HOST=$(grep db.hostname $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
    DB_PORT=$(grep db.port $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
    DB_NAME=$(grep db.servicename $ORDS_CONF_DIR/databases/default/pool.xml|cut -d">" -f2|cut -d"<" -f1)
    output "INFO" "Starting the ORDS services with the following database details:"
    output "INFO" "  ${DB_HOST}:${DB_PORT}/${DB_NAME}."
  else
    output "INFO" "Starting the ORDS services."
  fi

  # ping DYNDNS to set IP
  if [[ "$ORDS_DDNS" == true ]] && [[ -n ${ORDS_DDNS_USER} ]] && [[ -n ${ORDS_DDNS_URL} ]] ; then
    if [[ -f "/run/secrets/ddns_pwd" ]]; then
      ORDS_DDNS_PASSWORD=$(<"/run/secrets/ddns_pwd")
      output "INFO" "DynDNS Configuration found, curling to: ${ORDS_DDNS_URL}"
      curl https://${ORDS_DDNS_USER}:${ORDS_DDNS_PASSWORD}@${ORDS_DDNS_URL}
    fi
  fi
  
  # Start serving or let TOMCAT to that
  if [[ ${TOMCAT,,} != "true" ]]; then
    output "INFO" "ORDS will serve ..."

    [[ -d ${ORDS_IMAGE_DIR} ]] || mkdir -p ${ORDS_IMAGE_DIR}
    echo "Mode for ORDS = 'ORDS'" > "${ORDS_IMAGE_DIR}/ords_mode.txt"

    export CERT_FILE="$ORDS_CONF_DIR/ssl/cert.crt"
    export KEY_FILE="$ORDS_CONF_DIR/ssl/key.key"

    ORDS_IMAGE_ARG="--apex-images ${ORDS_IMAGE_DIR}"

    if [ -e ${CERT_FILE} ] && [ -e ${KEY_FILE} ]
    then
      ${ORDS_DIR}bin/ords --config $ORDS_CONF_DIR serve --port 8080 ${ORDS_IMAGE_ARG} --secure --certificate ${CERT_FILE} --key  ${KEY_FILE}
    else
      ${ORDS_DIR}bin/ords --config $ORDS_CONF_DIR serve --port 8080 ${ORDS_IMAGE_ARG}
    fi
  else
    output "INFO" "Tomcat for the win ..."
    echo "Mode for ORDS = 'TOMCAT'" > "${ORDS_IMAGE_DIR}/ords_mode.txt"
  fi
}

function unpack_ords() {
  # check if ORDS_DIR exists
  [[ -d ${ORDS_DIR} ]] || mkdir -p ${ORDS_DIR}

  cd ${ORDS_DIR}

  # check if FILE exists
  if [[ -f "ords-${ORDS_FULL_VERSION}.zip" ]]; then
    output "INFO" "ords-${ORDS_FULL_VERSION}.zip"
    unzip -oq ords-${ORDS_FULL_VERSION}.zip
    rm ords-${ORDS_FULL_VERSION}.zip
    chmod +x bin/ords
  fi

  if [[ -f "apex_patch.zip" ]]; then
    output "INFO" "unzipping apex_patch.zip"
    unzip -oq "apex_patch.zip" -d "patchset"
    rm "apex_patch.zip"
  fi
}

function run_script() {
  # check if we have tu unzip
  if [[ ! -d "${ORDS_DIR}bin" ]]; then
    output "INFO" "ORDS Directory not found"
    unpack_ords;
  else
    output "INFO" "ORDS Directory exists"
  fi

  # Did we already configure ORDS?
  if [ -e $ORDS_CONF_DIR/databases/default/pool.xml ]; then
    output "INFO" "Running ORDS with configuration found in $ORDS_CONF_DIR/databases/default/pool.xml"
    run_ords
  else
    # Not configured yet, so we have to
    if [ -e $CONFIG_FILE ]; then
      # check connection
      check_database

      # check ORDS Installation
      check_ords_version

      # install or upgrade when needed
      if [[ ${INS_STATUS} == "FRESH" ]] || [[ ${INS_STATUS} == "UPGRADE" ]]; then
        install_ords
      fi

      run_ords
    else
      output "WARN" "Nothing configured jet"
    fi
  fi

}

# read all conf params from mounted file
read_env_conf_file

output "INFO" "This container will start a service running ORDS ${ORDS_VERSION}."

# execute everything we need
run_script

# just do nothing, otherwise container will stop
tail -f /dev/null