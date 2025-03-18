#!/usr/bin/env bash
#

CONN_STRING_FILE="/opt/oracle/config.env"

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

if [[ -f $CONN_STRING_FILE ]]; then
  source ${CONN_STRING_FILE}
  DB_PASS=$(<"/run/secrets/oracle_pwd")

  SQLPLUS_ARGS="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME} as sysdba"
  if [[ -n "$DB_USER" ]] && [[ -n "$DB_PASS" ]] && [[ -n "$DB_HOST" ]]  && [[ -n "$DB_PORT" ]]  && [[ -n "$DB_NAME" ]] ; then
    output "INFO" "All Connection vars has been found in the container variables file."
    SQLPLUS_ARGS="${DB_USER}/${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME} as sysdba"
  else
    output "ERROR" "NOT all vars found in the container variables file."
    output "   DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME     "
    exit 1
  fi
else
  output "ERROR" "${CONN_STRING_FILE} has not added, create a file with following vars"
  output "  DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME variables"
  output "  and added as docker volume:"
  exit 1
fi


# Info
# https://raw.githubusercontent.com/bnoordhuis/mozilla-central/master/toolkit/crashreporter/client/certdata2pem.py
# https://raw.githubusercontent.com/alpinelinux/ca-certificates/master/certdata2pem.py
# https://www.mozilla.org/en-US/about/governance/policies/security-group/certs/
# https://hg.mozilla.org/mozilla-central/raw-file/tip/security/nss/lib/ckfw/builtins/certdata.txt

# Usage:
# . create_ca_wallet.sh

# Set env vars
set_env() {
    export WORKING_DIR=/tmp/wallet
    export OUTPUT_TMP_DIR=$WORKING_DIR/output
    export WALLET_DIR=$WORKING_DIR/wallet
}

# Create needed folders
create_folders() {
    mkdir -p $OUTPUT_TMP_DIR
    if [ ! -d $WALLET_DIR ]; then
        mkdir $WALLET_DIR
    fi
}

# Get mozilla resources & scripts
fetch_scripts() {
    echo ""
    output "INFO" "**** Fetching script & certificates data from mozilla ****"
    curl -O https://raw.githubusercontent.com/alpinelinux/ca-certificates/3184fe80e403b9dc6d5fe3b7ebcd9d375363e2e4/certdata2pem.py
    curl -O https://hg.mozilla.org/mozilla-central/raw-file/tip/security/nss/lib/ckfw/builtins/certdata.txt
    curl -O https://git.launchpad.net/ubuntu/+source/ca-certificates/plain/mozilla/blacklist.txt
    chmod +x certdata2pem.py
}

# extract pem from data
# python3.8 certdata2pem.py
convert_certdata_pem() {
    echo ""
    output "INFO" "**** Extracting data from certdata.txt and creating certificates ****"
    python3 certdata2pem.py
}

# Create password file
create_password_file() {
    if [ ! -f $WALLET_DIR/_pwd.txt ]; then
        echo ""
        output "INFO" "**** Creating Password File ****"
        output "INFO" "Location: ${WALLET_DIR}/_pwd.txt"
        openssl rand -base64 64 | tr -dc 'a-zA-Z0-9' | fold -w 40 | head -n 1 >$WALLET_DIR/_pwd.txt
    else
        echo ""
        output "INFO" "**** Password File already present ****"
        output "INFO" "Location: ${WALLET_DIR}/_pwd.txt"
    fi
}

# Create Oracle wallet
create_oracle_wallet() {
  # sudo apt install python2.7 python-pip
    echo ""
    # echo "**** Creating Oracle Wallet containing all CA certificates ****"
    # if type "orapki" >/dev/null; then
    #     echo ""
    #     echo "> Creating Wallet with orapki"
    #     orapki wallet create -wallet $WALLET_DIR -pwd <(cat $WALLET_DIR/_pwd.txt) -auto_login
    #     echo ""
    #     echo "> Add each single CA certificate to Wallet"
    #     for file in $OUTPUT_TMP_DIR/*.crt; do
    #         orapki wallet add -wallet $WALLET_DIR -trusted_cert -cert $file -pwd <(cat $WALLET_DIR/_pwd.txt)
    #     done
    # else
        echo ""
        output "INFO" "Build single certificate file containing all CAs"
        for file in $OUTPUT_TMP_DIR/*.crt; do
            cat $file >>$WALLET_DIR/ca-certificates.crt
        done
        echo ""
        output "INFO" "Creating Wallet with openssl"
        openssl pkcs12 -export -in $WALLET_DIR/ca-certificates.crt -out $WALLET_DIR/ewallet.p12 -nokeys -passout file:$WALLET_DIR/_pwd.txt
    # fi
}

# Cleanup
cleanup() {
    rm -fr $OUTPUT_TMP_DIR
    rm -f $WALLET_DIR/ca-certificates.crt
}

# End output
end_output() {
    echo ""
    output "SUCCESS" "**** Done ****"
    output "SUCCESS" "Location: ${WALLET_DIR}"
}


move_wallet() {
  mv wallet /opt/oracle/oradata
  chmod 755 -R /opt/oracle/oradata/wallet
  # chown -R oracle:oinstall /opt/oracle/oradata/wallet
}

set_apex_wallet_and_pwd() {

  output "INFO" "Set APEX Instance SSL Wallet"
  WALLET_PWD=$(cat /opt/oracle/oradata/wallet/_pwd.txt)

  echo "prompt set wallet instance parameters">set_apex_wallet.sql
  echo "begin" >>set_apex_wallet.sql
  echo "  apex_instance_admin.set_parameter('WALLET_PATH','file:/opt/oracle/oradata/wallet');" >>set_apex_wallet.sql
  echo "  apex_instance_admin.set_parameter('WALLET_PWD','${WALLET_PWD}');" >>set_apex_wallet.sql
  echo "  commit;" >>set_apex_wallet.sql
  echo "end;" >>set_apex_wallet.sql
  echo "/" >>set_apex_wallet.sql

  echo "run sql"
  echo "exit" | sql -L ${SQLPLUS_ARGS} @set_apex_wallet
}



# Execute functions
set_env
create_folders
output "INFO" "OUTPUT_TMP_DIR: $OUTPUT_TMP_DIR"

cd $OUTPUT_TMP_DIR
fetch_scripts
convert_certdata_pem
output "INFO" "WORKING_DIR: $WORKING_DIR"

cd $WORKING_DIR
create_password_file
create_oracle_wallet

cleanup
move_wallet
set_apex_wallet_and_pwd
end_output

###############
