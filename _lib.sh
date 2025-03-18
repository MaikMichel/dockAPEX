#!/bin/bash

LIBSOURCED="TRUE"

# Reset
NC="\033[0m"       # Text Reset

# Regular Colors
RED="\033[0;31m"
REDF="\033[1;31m"
REDB="\033[1;41m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
BCYAN="\033[1;36m"
BORANGE="\e[38;5;208m"

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
    FATAL)
      printf "\e[41;97m%s%s\e[0m\n" "FATAL: " "$2"      
      ;;
    *)
      printf "%s%s\n" "        " "$1"
      ;;
  esac  
}


function echo_fatal() {
  output "FATAL" "$1"
}

function echo_error() {
  output "ERROR" "$1"
}

function echo_success() {
  output "SUCCESS" "$1"
}

function echo_warning() {
  output "WARN" "$1"
}

function echo_info() {
 output "INFO" "$1"
}

function ask_with_yes_no() {
    local question="${1}"
    
    read -r -p "$(printf "%b" "${BORANGE}${question}${NC} (y/n) " ) " -n 1
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0  # Yes
    else
        return 1  # No
    fi
}


function check_params() {
  local do_exit=false

  for var in "$@"; do
    if [[ -z "${!var}" ]]; then
      echo_error "$var is required but not configured"
      local do_exit=true
    fi
  done

  [[ ${do_exit} == false ]] || exit 2
}

function check_secret() {
  local do_exit=false

  for var in "$@"; do
    if [[ -z "${!var}" ]]; then
      echo_error "$var is required but not configured! Please use *.sec file"
      local do_exit=true
    fi
  done

  [[ ${do_exit} == false ]] || exit 2
}

function write_line_if_not_exists () {
  local line=$1
  local file=$2
  local prefix=$3

  if  grep -qxF "$line" "$file" ; then
    : # echo "$line exists in $file"
  else
    echo -e "${prefix}${line}" >> "$file"
  fi
}

function render_template() {
  local template="$1"
  local output="$2"
  
  awk '
  {
    while (match($0, /\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/)) {
      var = substr($0, RSTART+1, RLENGTH-1)
      gsub(/[\{\}]/, "", var)
      val = ENVIRON[var]
      $0 = substr($0, 1, RSTART - 1) val substr($0, RSTART + RLENGTH)
    }
    print
  }
' ${template} > ${output}
}