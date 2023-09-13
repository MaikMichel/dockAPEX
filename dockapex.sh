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
  echo "    build  > builds only images"
  echo "    start  > start images / containers "
  echo "    run    > builds and start images / containers "
  echo "    logs   > shows logs by executing logs -f "
  echo "    list   > list services"
  echo "    config > view compose files"
  echo "    print  > print compose call"
  echo "    stop   > stops services"
  echo "    clear  > removes all container and images, prunes allocated space"
  echo
  echo "-----------------------------------------------------"
	echo "Canceled !!!"
  echo
	exit 1
}

# All Params are required
if [[ $# -lt 1 ]]; then
  echo_error "Missing arguments, see...\n"
  usage
fi



export DCKAPX_CONF_FILE=${1:-".env"}
# check param file
if [[ ! -f ${DCKAPX_CONF_FILE} ]]; then
  echo_error "Missing configuration file: ${DCKAPX_CONF_FILE}"
  exit 1
else
  ##  export declaration
  set -a
  source ${DCKAPX_CONF_FILE}
  DCPAPX_PROJECT_NAME=$(basename "${DCKAPX_CONF_FILE%.*}")
  DCKAPX_CONF_FILE=$(pwd)/${DCKAPX_CONF_FILE}

  ## stop export declaration
  set +a
fi

DCKAPX_COMP_FILES=""

# TODO: validate required params
if [[ "$DB" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./database/part_compose.yml "
fi

if [[ "$APEX" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./apex/part_compose.yml "
fi

if [[ "$ORDS" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./ords/part_compose.yml "
fi

if [[ "$TOMCAT" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./tomcat/part_compose.yml "
fi

if [[ "$AOP" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./aop/part_compose.yml "
fi

if [[ "$TRAEFIK" == true ]]; then
  DCKAPX_COMP_FILES+="-f ./traefik/part_compose.yml "
fi

# validate command
# TODO: validate command

# arg1 => file, entfernen, den Rest geben wir an compose weiter
shift
DCKAPX_COMMAND="$@"

case ${1} in
  'clear')
    docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} down
    docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} down --volumes

    while true; do
      read -p "Remove images as well? y/n? " yn
      case $yn in
          [Yy]* )
            docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} down --rmi all
            break;
          ;;
          [Nn]* ) exit 1;;
          * ) echo "Please answer yes or no.";;
      esac
    done
    ;;
  *)
    echo "docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} ${DCKAPX_COMMAND}"
    docker-compose --project-name ${DCPAPX_PROJECT_NAME} ${DCKAPX_COMP_FILES} ${DCKAPX_COMMAND}
    ;;
esac

#