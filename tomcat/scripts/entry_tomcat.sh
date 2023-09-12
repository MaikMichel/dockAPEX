#!/bin/bash


printf "%s%s\n" "INFO : " "Starting the TOMCAT ${TOMCAT_VERSION} service"
TOMCAT_CONF_DIR="${TOMCAT_DIR}/conf"
if [[ ! -f ${TOMCAT_CONF_DIR}/installed.txt ]]; then
  printf "%s%s\n" "INFO : " "Moving xml configuration files"
  mv /scripts/tomcat-server.xml ${TOMCAT_CONF_DIR}/server.xml
  mv /scripts/tomcat-web.xml ${TOMCAT_CONF_DIR}/web.xml

  printf "%s%s\n" "INFO : " "Copying ORDS war file and images"
  cp "/opt/ords-${ORDS_VERSION}/ords.war" "${TOMCAT_DIR}/webapps/"
  cp -rf "/opt/oracle/images" "${TOMCAT_DIR}/webapps/i"

  printf "%s%s\n" "INFO : " "Mark installation of ORDS as done"
  echo "Installed tomcat" > ${TOMCAT_CONF_DIR}/installed.txt


  printf "%s%s\n" "INFO : " "ORDS Successfully deployed"
fi

printf "%s%s\n" "INFO : " "Executing catalina"


${TOMCAT_DIR}/bin/catalina.sh run

tail -f /dev/null