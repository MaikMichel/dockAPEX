#!/bin/bash

## VARS
CONFIG_FILE="/opt/oracle/config.env"

APEX_HOME="${APEX_DIR}apex"
APEX_IMAGES="/opt/oracle/images"
PSET_HOME="${APEX_DIR}patchset"

printf "%s%s\n" "INFO : " "This container will start a service installing APEX $APEX_FULL_VERSION."


function read_env_conf_file() {
  if [[ -f $CONFIG_FILE ]]; then
    source $CONFIG_FILE
  else
    printf "\a%s%s\n" "ERROR: " "${CONFIG_FILE} not found!"
    exit 1
  fi
}

function check_conn_definition() {
  # read DB password
  DB_PASS=$(<"/run/secrets/oracle_pwd")

  # optionally check SMTP password
  if [[ "$APEX_SMTP" == true ]]; then
    APEX_SMTP_PASSWORD=$(<"/run/secrets/smtp_pwd")
  fi

  if [[ -n "$DB_USER" ]] && [[ -n "$DB_PASS" ]] && [[ -n "$DB_HOST" ]]  && [[ -n "$DB_PORT" ]]  && [[ -n "$DB_NAME" ]] ; then
    printf "%s%s\n" "INFO : " "All Connection vars has been found in the container variables file."
    SQLPLUS_ARGS="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME} as sysdba"
  else
    printf "\a%s%s\n" "ERROR: " "NOT all vars found in the container variables file."
    printf "%s%s\n"   "       " "   DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME     "
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

function check_database() {
  # check if configuration vars are present
  check_conn_definition

  # let's check the connection itself
  try_connect ${DB_NAME}
}

function get_true_falsy () {
  local QUERY=$1

  sqlplus -S -L ${SQLPLUS_ARGS} <<EOF
set serveroutput on
set heading off
set feedback off
set pages 0
Declare
  l_dummy varchar2(2000);
Begin
  execute immediate '${QUERY}' into l_dummy;
  dbms_output.put_line('true');
exception
  when others then
    dbms_output.put_line('false');
End;
/
EOF

}

function create_apex_tablespace(){
  if [[ ${APEX_CREATE_TSPACE,,} == "true" ]]; then
    cd ${APEX_HOME}
    printf "%s%s\n" "INFO : " "Check if tablespace ${APEX_SPACE_NAME} exists"

    RESULT=$(get_true_falsy "select tablespace_name from dba_tablespaces where tablespace_name = ''${APEX_SPACE_NAME}''")

    if [[ "${RESULT}" =~ "true" ]]; then
      printf "%s%s\n" "INFO : " "Tablespace ${APEX_SPACE_NAME} allready exists, nothing to do"
    else
      printf "%s%s\n" "INFO : " "Creating tablespace ${APEX_SPACE_NAME} "
      sqlplus -S /nolog << EOF
        conn ${SQLPLUS_ARGS}
        CREATE TABLESPACE ${APEX_SPACE_NAME} DATAFILE '${APEX_CREATE_TSPACE_PATH}' SIZE 400M AUTOEXTEND ON NEXT 10M;
        exit
EOF
    fi
  fi
}

function install_patch() {
  printf "%s%s\n" "INFO : " "========================================"
  printf "%s%s\n" "INFO : " "========================================"
  printf "%s%s\n" "INFO : " "========================================"
  printf "%s%s\n" "INFO : " ""


  if [[ -d ${PSET_HOME} ]]; then
    printf "%s%s\n" "INFO : " "Patchset found"

    cd ${PSET_HOME}/*

    printf "%s%s\n" "INFO : " "Installing PatchSet on your DB this will take a while.."

    sqlplus /nolog << EOF
    conn ${SQLPLUS_ARGS}
    @catpatch
EOF

    RESULT=$?
    if [[ ${RESULT} -eq 0 ]] ; then
      printf "%s%s\n" "INFO : " "PatchSet has been installed."
    else
      printf "\a%s%s\n" "ERROR: " "PatchSet installation failed"
      exit 1
    fi
  else
    printf "%s%s\n" "INFO : " "No Patchset to install found"
  fi
}

function install_patch_images() {
  if [[ -d ${PSET_HOME} ]]; then
    printf "%s%s\n" "INFO : " "Copy PSet static files to ${APEX_IMAGES}"

    cp -rf ${PSET_HOME}/*/images/* ${APEX_IMAGES}
    printf "%s%s\n" "INFO : " "PSet static files have been copied."

  else
    printf "%s%s\n" "INFO : " "No Patchset to install found"
  fi
}

function set_image_prefix () {
  # set image-prexix
  if [[ ! -z ${APEX_IMAGE_PREFIX} ]]; then
    printf "%s%s\n" "INFO : " "Setting image prefix to ${APEX_IMAGE_PREFIX}"
    cd ${APEX_HOME}/utilities

    sqlplus /nolog << EOF
    conn ${SQLPLUS_ARGS}
    @reset_image_prefix_core.sql ${APEX_IMAGE_PREFIX}
EOF

  fi
}

function install_apex() {
  printf "%s%s\n" "INFO : " "==================================================="
  printf "%s%s\n" "INFO : " "==================================================="
  printf "%s%s\n" "INFO : " "==================================================="

  if [[ -f ${APEX_HOME}/apexins.sql ]]; then
    printf "%s%s\n" "INFO : " "Installing APEX on your DB please this will take a while."

    cd ${APEX_HOME}
    sqlplus /nolog<< EOF
    conn ${SQLPLUS_ARGS}
    @apexins ${APEX_SPACE_NAME} ${APEX_SPACE_NAME} TEMP /i/

EOF

    RESULT=$?
    if [ ${RESULT} -eq 0 ] ; then
      printf "%s%s\n" "INFO : " "APEX has been installed."
    else
      printf "\a%s%s\n" "ERROR: " "APEX installation failed"
      exit 1
    fi
  else
    printf "\a%s%s\n" "ERROR: " "APEX installation script missing."
    exit 1
  fi
}

function install_apex_images() {
  if [[ -f ${APEX_HOME}/apexins.sql ]]; then
    printf "%s%s\n" "INFO : " "Copy APEX static files to ${APEX_IMAGES}"

    rm -rf ${APEX_IMAGES}/*
    cp -rf ${APEX_HOME}/images/* ${APEX_IMAGES}

    printf "%s%s\n" "INFO : " "APEX static files has been copied."
  else
    printf "\a%s%s\n" "ERROR: " "APEX installation script missing."
    exit 1
  fi
}


function config_apex() {
  if [[ ${INS_STATUS} == "FRESH" ]] ; then

    if [[ -f ${APEX_HOME}/apexins.sql ]]; then

      cd ${APEX_HOME}
      sqlplus -S ${SQLPLUS_ARGS} <<EOF

        set define '^'
        set concat on
        set concat .
        set verify off

        @@core/scripts/set_appun.sql
        Prompt setting schema to ^APPUN.
        alter session set current_schema = ^APPUN.;

        Prompt setting ACLS
        -- From Joels blog: http://joelkallman.blogspot.ca/2017/05/apex-and-ords-up-and-running-in2-steps.html
        declare
          l_apex_schema varchar2(100);
        begin
          for c1 in (select schema
                      from dba_registry
                      where comp_id = 'APEX')
          loop
            l_apex_schema := c1.schema;
          end loop;

          dbms_network_acl_admin.append_host_ace(host           => '*',
                                                ace            => xs\$ace_type(privilege_list => xs\$name_list('connect'),
                                                                               principal_name => l_apex_schema,
                                                                               principal_type => xs_acl.ptype_db));

          dbms_network_acl_admin.append_host_ace(host           => '*',
                                                ace            => xs\$ace_type(privilege_list => xs\$name_list('http'),
                                                                               principal_name => l_apex_schema,
                                                                               principal_type => xs_acl.ptype_db));

          -- since 23ai we are able to you OS certificates
          apex_util.set_workspace(p_workspace => 'internal')
          apex_instance_admin.set_parameter('WALLET_PATH', 'system:');
          apex_instance_admin.set_parameter('WALLET_PWD', null);

          commit;
        end;
        /

        PROMPT  ========================================================================================
        PROMPT  ==   CLEAR ACLs
        PROMPT  ========================================================================================
        PROMPT
        DECLARE
          v_check number(1);
        BEGIN
          begin
            select 1
              into v_check
              from dba_network_acls
            where acl = '/sys/acls/smtp-permissions-dockAPEX.xml';

            dbms_network_acl_admin.drop_acL(acl => 'smtp-permissions-dockAPEX.xml');
          exception
            when no_data_found then
              null;
          end;

          commit;
        END;
        /

        PROMPT  =============================================================================
        PROMPT  ==   SETUP ACL SMTP
        PROMPT  =============================================================================
        PROMPT

        declare
          l_apex_schema varchar2(100);
        begin
          for c1 in (select schema
                      from sys.dba_registry
                      where comp_id = 'APEX')
          loop
            l_apex_schema := c1.schema;
          end loop;

          dbms_network_acl_admin.create_acl (acl         => 'smtp-permissions-dockAPEX.xml',
                                            description => 'Permissions for smtp',
                                            principal   => l_apex_schema,
                                            is_grant    => true,
                                            privilege   => 'connect');

          dbms_network_acl_admin.assign_acl (acl        => 'smtp-permissions-dockAPEX.xml',
                                            host       => '*',
                                            lower_port => 25,
                                            upper_port => 25);

          commit;
        end;
        /

        PROMPT  =============================================================================
        PROMPT  ==   SETUP INTERNAL
        PROMPT  =============================================================================
        PROMPT
        begin
          apex_util.set_workspace(p_workspace => 'internal');
          apex_util.create_user(p_user_name                    => 'ADMIN',
                                p_email_address                => '${APEX_INTERNAL_MAIL}',
                                p_web_password                 => 'Welcome_01!',
                                p_change_password_on_first_use => 'Y' );
          commit;
        end;
        /

EOF


      if [[ "$APEX_SMTP" == true ]]; then
        sqlplus -S ${SQLPLUS_ARGS} <<EOF

        set define '^'
        set concat on
        set concat .
        set verify off

        PROMPT  =============================================================================
        PROMPT  ==   SETUP SMTP
        PROMPT  =============================================================================
        PROMPT INTERNAL_MAIL:     ${APEX_INTERNAL_MAIL}
        PROMPT SMTP_HOST_ADDRESS: ${APEX_SMTP_HOST_ADDRESS}
        PROMPT SMTP_FROM:         ${APEX_SMTP_FROM}
        PROMPT SMTP_USERNAME:     ${APEX_SMTP_USERNAME}
        PROMPT  =============================================================================
        BEGIN
          apex_util.set_workspace(p_workspace => 'internal');
          apex_instance_admin.set_parameter('SMTP_HOST_ADDRESS', '${APEX_SMTP_HOST_ADDRESS}');
          apex_instance_admin.set_parameter('SMTP_FROM',         '${APEX_SMTP_FROM}');
          apex_instance_admin.set_parameter('SMTP_USERNAME',     '${APEX_SMTP_USERNAME}');
          apex_instance_admin.set_parameter('SMTP_PASSWORD',     '${APEX_SMTP_PASSWORD}');

          commit;
        END;
        /

        PROMPT  =============================================================================
        PROMPT  ==   SEND NOTIFICATION
        PROMPT  =============================================================================
        BEGIN
          apex_mail.send(p_from => '${APEX_SMTP_FROM}'
                        ,p_to   => '${APEX_INTERNAL_MAIL}'
                        ,p_subj => 'Congratulations, dockAPEX successfully installed'
                        ,p_body => 'Oracle APEX has successfully installed to dockAPEX project: ${DCPAPX_PROJECT_NAME}');

          apex_mail.push_queue();
        END;
        /

EOF
      fi

      RESULT=$?
      if [ ${RESULT} -eq 0 ] ; then
        printf "%s%s\n" "INFO : " "APEX has been configured and APEX ADMIN password initally set to 'Welcome_01!'."
        printf "%s%s\n" "INFO : " "Use below login credentials to first time login to APEX service:"
        printf "%s%s\n" "       " "  Workspace: internal"
        printf "%s%s\n" "       " "  User:      admin"
        printf "%s%s\n" "       " "  Password:  Welcome_01!"
      else
        printf "\a%s%s\n" "ERROR : " "APEX config failed."
        exit 1
      fi
    else
      printf "\a%s%s\n" "ERROR: " "APEX installation script missing."
      exit 1
    fi
  else
    printf "\a%s%s\n" "INFO: " "NO Fresh installation, nothing configured."
  fi # fresh
}

function check_second_bdb(){
  if [[ ${APEX_SECND_PDB,,} == "true" ]]; then
    printf "%s%s\n" "INFO : " "Cloning to ${DB_NAME} to ${APEX_SECND_PDB_NAME}"

    sqlplus -S $SQLPLUS_ARGS <<EOF
    alter session set container=cdb\$root;

    create pluggable database ${APEX_SECND_PDB_NAME} from ${DB_NAME}
    file_name_convert=('${APEX_FIRST_PDB_TBL_SPACE}','${APEX_SECND_PDB_TBL_SPACE}');

    alter pluggable database ${APEX_SECND_PDB_NAME} open read write;

    alter pluggable database ${APEX_SECND_PDB_NAME} save state;
EOF

    RESULT=$?
    if [ ${RESULT} -eq 0 ] ; then
      printf "%s%s\n" "INFO : " "${DB_NAME} has been successfully cloned to ${APEX_SECND_PDB_NAME}"
    else
      printf "\a%s%s\n" "ERROR: " "Cloning failed failed"
      exit 1
    fi

  fi

}

# since 23ai we are able to use OS Wallets
# function install_wallets() {
#   /scripts/install_wallet.sh
# }

function apex_install() {
  create_apex_tablespace

  install_apex
  install_patch
  set_image_prefix


  if [[ ${INS_STATUS} == "FRESH" ]]; then
    config_apex
    # install_wallets
    check_second_bdb
  fi

  install_apex_images
  install_patch_images
}

function check_apex_version() {
  # check if APEX is installed and what version is present
  sqlplus -s -l /nolog << EOF > /tmp/apex_version 2> /dev/null
  conn ${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME} as sysdba
  SET LINESIZE 20000 TRIM ON TRIMSPOOL ON
  SET PAGESIZE 0
  SELECT VERSION FROM DBA_REGISTRY WHERE COMP_ID='APEX';
EOF

  # Get RPM installed version
  YEAR=$(echo $APEX_FULL_VERSION | cut -d"." -f1)
  QTR=$(echo $APEX_FULL_VERSION | cut -d"." -f2)
  PATCH=$(echo $APEX_FULL_VERSION| cut -d"." -f3)

  # Get DB installed version
  APEX_DB_VERSION=$(cat /tmp/apex_version|grep [0-9][0-9].[1-5].[0-9] |sed '/^$/d'|sed 's/ //g')
  DB_YEAR=$(echo $APEX_DB_VERSION | cut -d"." -f1)
  DB_QTR=$(echo $APEX_DB_VERSION | cut -d"." -f2)
  DB_PATCH=$(echo $APEX_DB_VERSION | cut -d"." -f3)

  grep "SQL Error" /tmp/apex_version > /dev/null
  RESULT=$?

  if [[ ${RESULT} -eq 0 ]]; then
    printf "\a%s%s\n" "ERROR: " "Please validate the database status."
    grep "SQL Error" /tmp/apex_version
    exit 1
  fi

  if [[ -n "$APEX_DB_VERSION" ]]; then
    # Validate if an upgrade needed
    if [[ "$APEX_DB_VERSION" = "$APEX_FULL_VERSION" ]]; then
      printf "%s%s\n" "INFO : " "APEX $APEX_FULL_VERSION is already installed in your database."
      INS_STATUS="INSTALLED"
    elif [[ $DB_YEAR -gt $YEAR ]]; then
      printf "\a%s%s\n" "ERROR: " "A newer APEX version ($APEX_DB_VERSION) is already installed in your database. The APEX version in this container is ${APEX_FULL_VERSION}. Stopping the container."
      exit 1
    elif [[ $DB_YEAR -eq $YEAR ]] && [[ $DB_QTR -gt $QTR ]]; then
      printf "\a%s%s\n" "ERROR: " "A newer APEX version ($APEX_DB_VERSION) is already installed in your database. The APEX version in this container is ${APEX_FULL_VERSION}. Stopping the container."
      exit 1
    elif [[ $DB_YEAR -eq $YEAR ]] && [[ $DB_QTR -eq $QTR ]] && [[ $DB_PATCH -gt $PATCH ]]; then
      printf "\a%s%s\n" "ERROR: " "A newer APEX version ($APEX_DB_VERSION) is already installed in your database. The APEX version in this container is ${APEX_FULL_VERSION}. Stopping the container."
      exit 1
    else
      printf "%s%s\n" "INFO : " "Your have installed APEX ($APEX_DB_VERSION) on you database but will be upgraded to ${APEX_FULL_VERSION}."
      INS_STATUS="UPGRADE"
    fi
  else
    printf "%s%s\n" "INFO : " "APEX is not installed on your database."
    INS_STATUS="FRESH"
  fi
}

function check_unpack_apex() {
    # check if APEX_DIR exists
  [[ -d ${APEX_DIR} ]] || mkdir -p ${APEX_DIR}

  # if [[ ! -d "${APEX_DIR}apex" ]]; then
    # printf "%s%s\n" "INFO : " "APEX Directory (${APEX_DIR}apex) not found"

    cd ${APEX_DIR}

    # check if FILE exists
    if [[ -f "/tmp/apex_${APEX_VERSION}.zip" ]]; then
      printf "%s%s\n" "INFO : " "unzipping apex_${APEX_VERSION}.zip"
      unzip -oq "/tmp/apex_${APEX_VERSION}.zip"
      # rm "apex_${APEX_VERSION}_en.zip"
    fi

    if [[ -f "/tmp/apex_patch_${APEX_FULL_VERSION}.zip" ]]; then
      printf "%s%s\n" "INFO : " "unzipping apex_patch_${APEX_FULL_VERSION}.zip"
      unzip -oq "/tmp/apex_patch_${APEX_FULL_VERSION}.zip" -d "patchset"
      # rm "apex_patch_${APEX_FULL_VERSION}.zip"
    fi

  # else
    # printf "%s%s\n" "INFO : " "APEX Directory (${APEX_DIR}apex) exists"
  # fi
}

function run_script() {
  # check if we have tu unzip
  check_unpack_apex;

  # check if configuration file is present
  if [[ -f ${CONFIG_FILE} ]]; then
    # check connection
    check_database

    # check APEX Installation
    check_apex_version

    # install or upgrade when needed
    if [[ ${INS_STATUS} == "FRESH" ]] || [[ ${INS_STATUS} == "UPGRADE" ]]; then
      apex_install
      printf "%s%s\n" "INFO : " "APEX was successfully installed"
    fi
  else
    printf "\a%s%s\n" "WARN : " "Configuration ${CONFIG_FILE} NOT found"
  fi
}

# read all conf params from mounted file
read_env_conf_file

# execute everything we need
run_script

# just do nothing, otherwise container will stop
tail -f /dev/null

