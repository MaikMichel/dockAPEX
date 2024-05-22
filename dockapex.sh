#!/bin/bash

LIBSOURCED="false"

current_dir=$(dirname "$0")
path_ref="./"

# include lib
if [[ -f "./_lib.sh" ]]; then
  source "./_lib.sh"
elif [[ -f "./${current_dir}/_lib.sh" ]]; then
  source "./${current_dir}/_lib.sh"
  path_ref="./${current_dir}/"
else
  echo -e "\033[1;31mError:\033[0m \033[0;31m Missing library '_lib.sh' \033[0m"
  exit 1
fi;

function usage() {
  echo "Please call script by using all params in this order!"
	echo "    $0 env-file genfiles|clear|compose-comand"
  echo "-----------------------------------------------------"
  echo
  echo "  commands: "
  echo "    genfile > creates an .env and .sec file based on all known vars"
  echo "    clear   > removes all container and images, prunes allocated space"
  echo ""
  echo "    compose-comand   > redirected to docker-compose"
  echo ""
  echo "-----------------------------------------------------"
  echo ""
  echo "  examples: "
  echo "    ./dockapex.sh demo.env genfiles"
  echo "    ./dockapex.sh demo.env up --build --detach"
  echo "    ./dockapex.sh demo.env ps -a"
  echo "    ./dockapex.sh demo.env down"
  echo "    ./dockapex.sh demo.env clear"
  echo ""
  echo "-----------------------------------------------------"
  echo
	echo "Canceled !!!"
	exit 1
}

# All Params are required
if [[ $# -lt 2 ]]; then
  echo_error "Missing arguments, see...\n"
  usage
fi

function validate_apex_params() {
  # check required
  check_params "APEX_VERSION" "APEX_FULL_VERSION" "APEX_URL" "APEX_SPACE_NAME" "APEX_INTERNAL_MAIL"

  ## TableSpace
  if [[ "$APEX_CREATE_TSPACE" == true ]]; then
    check_params "APEX_CREATE_TSPACE"
  fi

  ## Second PDB
  if [[ "$APEX_SECND_PDB" == true ]]; then
    check_params "APEX_FIRST_PDB_TBL_SPACE" "APEX_SECND_PDB_TBL_SPACE" "APEX_SECND_PDB_POOL_NAME" "APEX_SECND_PDB_NAME"
  fi

  ## SMTP Password required when APEX_SMTP is true
  if [[ "$APEX_SMTP" == true ]]; then
    check_params "APEX_SMTP_HOST_ADDRESS" "APEX_SMTP_FROM" "APEX_SMTP_USERNAME"
    check_secret "SMTP_PASSWORD"
  fi
}

function validate_ords_params() {
  check_params "ORDS_FULL_VERSION" "ORDS_VERSION" "ORDS_URL" "ORDS_PORT"
  check_secret "ORDS_PASSWORD"

  ## DynDNS
  if [[ "$ORDS_DDNS" == true ]]; then
    check_params "ORDS_DDNS_USER" "ORDS_DDNS_URL"
    check_secret "ORDS_DDNS_PASSWORD"
  fi
}


function validate_tcat_params() {
  check_params "TOMCAT_VERSION" "TOMCAT_URL" "TOMCAT_PORT"
}

function validate_aop_params() {
  check_params "AOP_PORT"
}

function validate_trfk_params() {
  check_params "TRAEFIK_DEFAULT_ROUTE" "TRAEFIK_DOMAIN" "TRAEFIK_DASHBOARD" "TRAEFIK_LETSENCRYPT_EMAIL"
  check_secret "TRFK_USERPWD"
}


export DCKAPX_CONF_FILE=${1:-".env"}
# check param file
if [[ ! -f ${DCKAPX_CONF_FILE} ]]; then
  if [[ ${2} != "genfiles" ]]; then
  echo ${2}
    echo_error "Missing configuration file: ${DCKAPX_CONF_FILE}"
    exit 1
  fi
else
  ##  export configuration
  set -a

  source ${DCKAPX_CONF_FILE}
  DCPAPX_PROJECT_NAME=$(basename "${DCKAPX_CONF_FILE%.*}")
  DCKAPX_CONF_FILE=$(pwd)/${DCKAPX_CONF_FILE}

  # is there a secret file
  DCKAPX_SECRET_FILE="${DCKAPX_CONF_FILE%.*}.sec"
  if [[ -f ${DCKAPX_SECRET_FILE} ]]; then
    source ${DCKAPX_SECRET_FILE}
  fi

  ## stop export configuration
  set +a
fi

DCKAPX_COMP_FILES=""

# validate global required params

## DB Params are required, when any of DB, APEX, ORDS are set
if [[ "$DB" == true ]] || [[ "$APEX" == true ]] || [[ "$ORDS" == true ]]; then
  check_params "DB_USER" "DB_HOST" "DB_PORT" "DB_NAME"
  check_secret "DB_PASS"
fi


if [[ "$DB" == true ]]; then
  DCKAPX_COMP_FILES+="-f ${path_ref}database/docker_compose.yml "
fi

if [[ "$APEX" == true ]]; then
  DCKAPX_COMP_FILES+="-f ${path_ref}apex/docker_compose.yml "

  validate_apex_params

  if [[ "$ORDS" == true ]]; then
    DCKAPX_COMP_FILES+="-f ${path_ref}apex/ords_compose.yml "
  fi
fi

if [[ "$ORDS" == true ]]; then
  DCKAPX_COMP_FILES+="-f ${path_ref}ords/docker_compose.yml "

  validate_ords_params

  if [[ "$TRAEFIK" == true ]] && [[ "$TOMCAT" != true ]]; then
    DCKAPX_COMP_FILES+="-f ${path_ref}ords/traefik_compose.yml "
  fi
fi

if [[ "$TOMCAT" == true ]]; then
  DCKAPX_COMP_FILES+="-f ${path_ref}tomcat/docker_compose.yml "

  validate_tcat_params

  if [[ "$TRAEFIK" == true ]]; then
    DCKAPX_COMP_FILES+="-f ${path_ref}tomcat/traefik_compose.yml "
  fi
fi

if [[ "$AOP" == true ]]; then
  DCKAPX_COMP_FILES+="-f ${path_ref}aop/docker_compose.yml "

  validate_aop_params
fi

if [[ "$TRAEFIK" == true ]]; then
  DCKAPX_COMP_FILES+="-f ${path_ref}traefik/docker_compose.yml "
fi



# arg1 => file, entfernen, den Rest geben wir an compose weiter
shift
DCKAPX_COMMAND="$@"

function clear_containers() {
  local arg=${1}
  if [[ ${arg} == "-f" ]] || [[ ${arg} == "--force" ]]; then
    docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} down --volumes --rmi local
    yes | docker system prune
  else

    ask_with_yes_no "Shutdown all containers?"
    if [[ $? -eq 0 ]]; then
      docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} down

      ask_with_yes_no "Remove volumes?"
      if [[ $? -eq 0 ]]; then
        docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} down --volumes
      fi

      ask_with_yes_no "Remove images?"
      if [[ $? -eq 0 ]]; then
        docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} down --rmi local
      fi

      ask_with_yes_no "Addionally prune system?"
      if [[ $? -eq 0 ]]; then
        docker system prune
      fi
    fi
  fi
}

function genfiles() {
  local target_file="${1/.env/}"


  # export all vars when defined
  set -a
    source "${path_ref}_template/_defaults.env"
    [[ -f "${target_file}.env" ]] && source "${target_file}.env"
    [[ -f "${target_file}.sec" ]] && source "${target_file}.sec"
  set +a

  # create backup
  [[ -f "${target_file}.env" ]] && mv "${target_file}.env" "${target_file}.env.old"
  [[ -f "${target_file}.sec" ]] && mv "${target_file}.sec" "${target_file}.sec.old"

  # write vars to target files
  envsubst < "${path_ref}_template/_template_env" > "${target_file}.env"
  envsubst < "${path_ref}_template/_template_sec" > "${target_file}.sec"

  sed -i '1,2d' "${target_file}.env"
  sed -i '1,2d' "${target_file}.sec"

  echo_info "${target_file}.env and ${target_file}.sec created"
  echo_info "Please define config properties in the files created"
}
case ${1} in
  'clear')
    clear_containers ${2}
    ;;
  'genfiles')
    genfiles ${DCKAPX_CONF_FILE}
    ;;
  '-h'|'--help')
    usage
    ;;
  *)
    echo "docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} ${DCKAPX_COMMAND}"
    docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} ${DCKAPX_COMMAND}
    ;;
esac

#