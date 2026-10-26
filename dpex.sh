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
  echo "    ports   > shows the host ports of the running services"
  echo ""
  echo "    compose-comand   > redirected to docker-compose"
  echo ""
  echo "-----------------------------------------------------"
  echo ""
  echo "  examples: "
  echo "    $0 demo.env genfiles"
  echo "    $0 demo.env up --build --detach"
  echo "    $0 demo.env ps -a"
  echo "    $0 demo.env down"
  echo "    $0 demo.env clear"
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
    check_params "APEX_CREATE_TSPACE_PATH"
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
  check_params "ORDS_FULL_VERSION" "ORDS_VERSION" "ORDS_URL"
  check_secret "ORDS_PASSWORD"

  ## DynDNS
  if [[ "$ORDS_DDNS" == true ]]; then
    check_params "ORDS_DDNS_USER" "ORDS_DDNS_URL"
    check_secret "ORDS_DDNS_PASSWORD"
  fi
}


function validate_tcat_params() {
  check_params "TOMCAT_VERSION" "TOMCAT_URL"
}

function validate_mailpit_params() {
  check_params "MAILPIT_VERSION"
}

function validate_trfk_params() {
  check_params "TRAEFIK_DEFAULT_ROUTE" "TRAEFIK_DOMAIN" "TRAEFIK_DASHBOARD" "TRAEFIK_LETSENCRYPT_EMAIL"
  check_secret "TRFK_USERPWD"
}

# routed by a traefik of another stack, only the routing needs to be known
function validate_trfk_external_params() {
  check_params "TRAEFIK_DEFAULT_ROUTE" "TRAEFIK_DOMAIN"
  if [[ "$TRAEFIK" == true ]]; then
    echo_error "TRAEFIK and TRAEFIK_EXTERNAL are exclusive"
    exit 2
  fi
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
  # subdomain of the project when routed by traefik (DNS labels allow no underscores)
  DCPAPX_HOST=$(tr '[:upper:]_.' '[:lower:]--' <<<"${DCPAPX_PROJECT_NAME}")
  DCKAPX_CONF_FILE=$(pwd)/${DCKAPX_CONF_FILE}

  # is there a secret file
  DCKAPX_SECRET_FILE="${DCKAPX_CONF_FILE%.*}.sec"
  if [[ -f ${DCKAPX_SECRET_FILE} ]]; then
    source ${DCKAPX_SECRET_FILE}
  fi

  # compose mounts this secret into ords in any case, so it must exist (empty without DynDNS)
  : "${ORDS_DDNS_PASSWORD:=}"

  ## stop export configuration
  set +a
fi

DCKAPX_COMP_FILES=""

# apps are routed when this stack runs traefik or uses the one of another stack
DCKAPX_ROUTED=false
if [[ "$TRAEFIK" == true ]] || [[ "$TRAEFIK_EXTERNAL" == true ]]; then
  DCKAPX_ROUTED=true
fi

# check only when argument 2 is not genfiles
if [[ ${2} != "genfiles" ]]; then  
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

    if [[ "$DB" == true ]]; then
      DCKAPX_COMP_FILES+="-f ${path_ref}apex/docker_compose_db.yml "
    fi

    if [[ "$ORDS" == true ]]; then
      DCKAPX_COMP_FILES+="-f ${path_ref}apex/docker_compose_ords.yml "
    fi
  fi

  if [[ "$ORDS" == true ]]; then
    DCKAPX_COMP_FILES+="-f ${path_ref}ords/docker_compose.yml "

    validate_ords_params

    if [[ "$DB" == true ]]; then
      DCKAPX_COMP_FILES+="-f ${path_ref}ords/docker_compose_db.yml "
    fi
   
    if [[ "$DCKAPX_ROUTED" == true ]] && [[ "$TOMCAT" != true ]]; then
      DCKAPX_COMP_FILES+="-f ${path_ref}ords/docker_compose_traefik.yml "
    fi
  fi

  if [[ "$TOMCAT" == true ]]; then
    DCKAPX_COMP_FILES+="-f ${path_ref}tomcat/docker_compose.yml "

    validate_tcat_params

    if [[ "$DCKAPX_ROUTED" == true ]]; then
      DCKAPX_COMP_FILES+="-f ${path_ref}tomcat/docker_compose_traefik.yml "
    fi
  fi

  if [[ "$AOP" == true ]]; then
    DCKAPX_COMP_FILES+="-f ${path_ref}aop/docker_compose.yml "

    if [[ "$DB" == true ]]; then
      DCKAPX_COMP_FILES+="-f ${path_ref}aop/docker_compose_db.yml "
    fi

    if [[ "$ORDS" == true ]]; then
      DCKAPX_COMP_FILES+="-f ${path_ref}aop/docker_compose_ords.yml "
    fi

  fi

  if [[ "$MAILPIT" == true ]]; then
    DCKAPX_COMP_FILES+="-f ${path_ref}mailpit/docker_compose.yml "

    validate_mailpit_params

    if [[ "$DCKAPX_ROUTED" == true ]]; then
      DCKAPX_COMP_FILES+="-f ${path_ref}mailpit/docker_compose_traefik.yml "
    fi
  fi

  if [[ "$TRAEFIK" == true ]]; then
    DCKAPX_COMP_FILES+="-f ${path_ref}traefik/docker_compose.yml "

    validate_trfk_params
  fi

  if [[ "$TRAEFIK_EXTERNAL" == true ]]; then
    validate_trfk_external_params
  fi
fi

# arg1 => file, entfernen, den Rest geben wir an compose weiter
shift
DCKAPX_COMMAND="$*"

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

# prints the host address of every enabled service (ports are assigned by docker at start)
function show_ports() {
  local entries=() e svc cport label addr
  [[ "$DB" == true ]] && entries+=("database:1521:")
  [[ "$ORDS" == true ]] && entries+=("ords:8080:http://")
  [[ "$TOMCAT" == true ]] && entries+=("tomcat:9080:http://")
  [[ "$AOP" == true ]] && entries+=("aop:8010:http://")
  [[ "$MAILPIT" == true ]] && entries+=("mailpit:8025:http://")

  echo_info "Host ports of ${DCPAPX_PROJECT_NAME}:"
  if [[ "$DCKAPX_ROUTED" == true ]] && [[ "$ORDS" == true || "$TOMCAT" == true || "$MAILPIT" == true ]]; then
    printf '  %-10s https://%s.%s/\n' "traefik" "${DCPAPX_HOST}" "${TRAEFIK_DOMAIN}"
  fi
  if [[ "$TRAEFIK" == true && "$TRAEFIK_DASHBOARD" == true ]]; then
    printf '  %-10s https://%s/traefik/\n' "dashboard" "${TRAEFIK_DOMAIN}"
  fi
  for e in "${entries[@]}"; do
    IFS=: read -r svc cport label <<<"${e}"
    addr=$(docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} port ${svc} ${cport} 2>/dev/null | tail -n 1)
    if [[ -n "${addr}" ]]; then
      printf '  %-10s %slocalhost:%s\n' "${svc}" "${label}" "${addr##*:}"
    else
      printf '  %-10s not running\n' "${svc}"
    fi
  done
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
  if [[ -z "$ZSH_VERSION" ]]; then
    render_template "${path_ref}_template/_template_env" "${target_file}.env"
    render_template "${path_ref}_template/_template_sec" "${target_file}.sec"
  else  
    envsubst < "${path_ref}_template/_template_env" > "${target_file}.env"
    envsubst < "${path_ref}_template/_template_sec" > "${target_file}.sec"
  fi

  # drop the two header lines and turn § back into $ (portable, no sed -i)
  local f
  for f in "${target_file}.env" "${target_file}.sec"; do
    sed '1,2d; s/§/$/g' "${f}" > "${f}.tmp" && mv "${f}.tmp" "${f}"
  done

  chmod 600 "${target_file}.sec"

  echo_info "${target_file}.env and ${target_file}.sec created"
  echo_info "Please define your configuration properties here"

  write_line_if_not_exists "# do not commit your secrets" ".gitignore" "\n"
  write_line_if_not_exists "${target_file}.sec" ".gitignore"

  ls -la ${target_file}.*
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
  'ports')
    show_ports
    ;;
  *)
    # the network shared with traefik is external, so it has to exist before up
    if [[ ${1} == "up" && "$DCKAPX_ROUTED" == true ]]; then
      docker network inspect dpex_proxy >/dev/null 2>&1 || docker network create dpex_proxy
    fi
    echo "docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} ${DCKAPX_COMMAND}"
    docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} ${DCKAPX_COMMAND}
    rc=$?
    # a detached up returns, so the assigned ports are known now
    if [[ ${rc} -eq 0 && ${1} == "up" && ( " $* " == *" -d "* || " $* " == *" --detach "* ) ]]; then
      show_ports
    fi
    exit ${rc}
    ;;
esac

#