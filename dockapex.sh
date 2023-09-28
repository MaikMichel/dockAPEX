#!/bin/bash

LIBSOURCED="false"

# include lib
if [[ ! -f ./_lib.sh ]]; then
  echo -e "\033[1;41mMissing library '_lib.sh'!\033[0m"
  exit 1
else
  source "./_lib.sh"
fi;

function usage() {
  echo "Please call script by using all params in this order!"
	echo "    $0 command"
  echo "-----------------------------------------------------"
  echo
  echo "  command "
  echo "    clear  > removes all container and images, prunes allocated space"
  echo ""
  docker-compose --help
  echo "-----------------------------------------------------"
	echo "Canceled !!!"
  echo
	exit 1
}

# All Params are required
if [[ $# -lt 2 ]]; then
  echo_error "Missing arguments, see...\n"
  usage
fi



export DCKAPX_CONF_FILE=${1:-".env"}
# check param file
if [[ ! -f ${DCKAPX_CONF_FILE} ]]; then
  echo_error "Missing configuration file: ${DCKAPX_CONF_FILE}"
  exit 1
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

# TODO: validate required params
if [[ "$DB" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./database/docker_compose.yml "
fi

if [[ "$APEX" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./apex/docker_compose.yml "
fi

if [[ "$ORDS" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./ords/docker_compose.yml "

  if [[ "$TRAEFIK" == true ]] && [[ "$TOMCAT" != true ]]; then
    DCKAPX_COMP_FILES+="-f ./ords/traefik_compose.yml "
  fi
fi

if [[ "$TOMCAT" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./tomcat/docker_compose.yml "

  if [[ "$TRAEFIK" == true ]]; then
    DCKAPX_COMP_FILES+="-f ./tomcat/traefik_compose.yml "
  fi
fi

if [[ "$AOP" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./aop/docker_compose.yml "

  if [[ "$TRAEFIK" == true ]]; then
    DCKAPX_COMP_FILES+="-f ./aop/traefik_compose.yml "
  fi
fi

if [[ "$TRAEFIK" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./traefik/docker_compose.yml "
fi

# validate command
# TODO: validate command

# arg1 => file, entfernen, den Rest geben wir an compose weiter
shift
DCKAPX_COMMAND="$@"

function clear_containers() {
  local arg=${1}
  if [[ ${arg} == "-f" ]]; then
    docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} down --volumes --rmi local
    docker system prune
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

case ${1} in
  'clear')
    clear_containers ${2}
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