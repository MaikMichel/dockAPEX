#!/bin/bash

## VARS
CONFIG_FILE="/opt/oracle/config.env"

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



aop_schema="AOP"
aop_pass=$(base64 < /dev/urandom | tr -d 'O0Il1+/' | head -c 20; printf '\n')

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

  if [[ -n "$DB_USER" ]] && [[ -n "$DB_PASS" ]] && [[ -n "$DB_HOST" ]]  && [[ -n "$DB_PORT" ]]  && [[ -n "$DB_NAME" ]] ; then    
    output "INFO" "All Connection vars has been found in the container variables file."
    SQLPLUS_ARGS="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME} as sysdba"
    if [[ ${APEX_SECND_PDB,,} == "true" ]]; then
      SQLPLUS_ARGS2="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${APEX_SECND_PDB_NAME} as sysdba"
    fi
  else
    output "ERROR" "NOT all vars found in the container variables file."
    output "DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME"
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
        output "user/password@hostname:port/service_name"
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

function is_aop_installed () {
    sql -S -L /nolog << EOF
    set heading off
    set feedback off
    set pages 0
    conn ${1}
    with checksql as (select count(1) cnt
  from all_users
 where username = upper('${aop_schema}'))
 select case when cnt = 1 then 'true' else 'false' end ding
   from checksql;
EOF
}


function aop_install() {  
  local conn="${1}"
  local tns="${2}"
  if [[ -f /db/install.sql ]]; then
    output "INFO" "install.sql found in /db."

    cd /db

    if [[ ${INS_STATUS} == "UPGRADE" ]] || [[ ${INS_STATUS} == "UPDATE" ]]; then
      output "INFO" "Droping AOP schema in ${tns}"
      sql -S -L /nolog <<EOF
      
      conn ${conn}
      Prompt drop user: ${aop_schema}
      drop user ${aop_schema} cascade
      /        
EOF
    fi

    # create schema aop ih ins_status is FRESH
    if [[ ${INS_STATUS} == "FRESH" ]] || [[ ${INS_STATUS} == "UPGRADE" ]] || [[ ${INS_STATUS} == "UPDATE" ]]; then
      
      output "INFO" "Creating AOP schema ${tns}"
      sql -S -L /nolog <<EOF
      
      conn ${conn}
      Prompt create user: ${aop_schema}
      create user ${aop_schema} identified by "${aop_pass}"
      /    
      grant connect, create view, create procedure, create synonym to ${aop_schema}
      /
      conn ${aop_schema}/${aop_pass}@${DB_HOST}:${DB_PORT}/$tns

      Prompt install ${aop_schema} Packages
      @install.sql

      Promp locking user: ${aop_schema}
      conn ${SQLPLUS_ARGS}
      alter user ${aop_schema} account lock;
EOF
    fi
  else
    output "INFO" "No install.sql present ind /db >> so not installing AOP."    
  fi
   
}

function check_aop_version() {
  local conn="${1}"
  local tns="${2}"

  # check if AOP is installed and what version is present
  AOP_INSTALLED=$(is_aop_installed "${conn}" "${tns}")
  AOP_INSTALLED=$(echo "${AOP_INSTALLED}" | tr -d '[:space:]')
  
  if [[ "${AOP_INSTALLED}" == "true" ]]; then  
    output "INFO" "Determining AOP Version in ${tns}"

    sql -S -L /nolog << EOF > /tmp/aop_version 2> /dev/null
    conn ${conn}
    SET LINESIZE 20000 TRIM ON TRIMSPOOL ON
    SET PAGESIZE 0
    SET SERVEROUTPUT ON
    Declare
      l_aop_version varchar2(100) := aop.aop_api_pkg.c_aop_version;
    Begin
      dbms_output.put_line(l_aop_version);
    End;
    /
EOF

    # Get RPM installed version
    MAJOR=$(echo $AOP_FULL_VERSION | cut -d"." -f1)
    MINOR=$(echo $AOP_FULL_VERSION | cut -d"." -f2)
    PATCH=$(echo $AOP_FULL_VERSION | cut -d"." -f3)

    # Get DB installed version
    AOP_DB_VERSION=$(cat /tmp/aop_version|grep [0-9][0-9].[1-5].[0-9] |sed '/^$/d'|sed 's/ //g')
    DB_MAJOR=$(echo $AOP_DB_VERSION | cut -d"." -f1)
    DB_MINOR=$(echo $AOP_DB_VERSION | cut -d"." -f2)
    DB_PATCH=$(echo $AOP_DB_VERSION | cut -d"." -f3)

    grep "ERROR at" /tmp/aop_version > /dev/null
    RESULT=$?

    if [[ ${RESULT} -eq 0 ]]; then
      output "ERROR" "AOP Version could not be determined in ${tns}"      
      INS_STATUS="UPGRADE"
    else

      if [[ -n "$AOP_DB_VERSION" ]]; then
        # Validate if an upgrade needed
        if [[ "$AOP_DB_VERSION" = "$AOP_FULL_VERSION" ]]; then
          output "INFO" "AOP $AOP_FULL_VERSION is already installed in your database."
          INS_STATUS="INSTALLED"
        elif [[ $DB_MAJOR -gt $MAJOR ]]; then
          output "ERROR" "A newer AOP version ($AOP_DB_VERSION) is already installed in your database. The AOP version in this container is ${AOP_FULL_VERSION}. Stopping the container."
          exit 1
        elif [[ $DB_MAJOR -eq $MAJOR ]] && [[ $DB_MINOR -gt $MINOR ]]; then
          output "ERROR" "A newer AOP version ($AOP_DB_VERSION) is already installed in your database. The AOP version in this container is ${AOP_FULL_VERSION}. Stopping the container."
          exit 1
        elif [[ $DB_MAJOR -eq $MAJOR ]] && [[ $DB_MINOR -eq $MINOR ]] && [[ $DB_PATCH -gt $PATCH ]]; then
          output "ERROR" "A newer AOP version ($AOP_DB_VERSION) is already installed in your database. The AOP version in this container is ${AOP_FULL_VERSION}. Stopping the container."
          exit 1
        elif [[ $DB_MAJOR -eq $MAJOR ]] && [[ $DB_MINOR -eq $MINOR ]] && [[ $PATCH -gt $DB_PATCH ]]; then
          output "INFO" "You have installed AOP ($AOP_DB_VERSION) on you database but will be patched to ${AOP_FULL_VERSION}."
          INS_STATUS="UPDATE"
        else
          output "INFO" "You have installed AOP ($AOP_DB_VERSION) on you database but will be upgraded to ${AOP_FULL_VERSION}."
          INS_STATUS="UPDATE"
        fi
      else
        output "INFO" "AOP is not configured on your database in ${tns}."
        INS_STATUS="FRESH"
      fi
    fi
  else
    INS_STATUS="FRESH"
    output "INFO" "AOP is not installed on your database in ${tns}."  
  fi
}


function run_script() {
  
  # check if configuration file is present
  if [[ -f ${CONFIG_FILE} ]]; then
    # check connection
    check_database

    # check AOP Installation
    check_aop_version "${SQLPLUS_ARGS}" "${DB_NAME}"

    # install or upgrade when needed
    if [[ ${INS_STATUS} == "FRESH" ]] || [[ ${INS_STATUS} == "UPGRADE" ]] || [[ ${INS_STATUS} == "UPDATE" ]]; then
      aop_install "${SQLPLUS_ARGS}" "${DB_NAME}"
      output "SUCCESS" "AOP was successfully installed"
    fi


    if [[ ${APEX_SECND_PDB,,} == "true" ]]; then
      check_aop_version "${SQLPLUS_ARGS2}" "${APEX_SECND_PDB_NAME}"

      # install or upgrade when needed
      if [[ ${INS_STATUS} == "FRESH" ]] || [[ ${INS_STATUS} == "UPGRADE" ]] || [[ ${INS_STATUS} == "UPDATE" ]]; then
        aop_install "${SQLPLUS_ARGS2}" "${APEX_SECND_PDB_NAME}"
        output "SUCCESS" "AOP was successfully installed in the second PDB"
      fi
    fi


  else
    output "WARN" "Configuration ${CONFIG_FILE} NOT found"
  fi
}

# read all conf params from mounted file
read_env_conf_file

output "INFO" "This container will start AOP as service and installs into database with Version ${AOP_FULL_VERSION} if present."

# this makes only sense when /db/install.sql is present
if [[ -f /db/install.sql ]]; then
  # execute everything we need
  run_script
fi

# just do the thon the AOP Container would normally do
/APEXOfficePrint/APEXOfficePrintLinux64 -s /apexofficeprintstartup

