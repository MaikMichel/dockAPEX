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


function echo_fatal() {
  local prompt_text=$1

  echo -e "${REDB}$prompt_text${NC}"
}

function echo_error() {
  local prompt_text=$1

  echo -e "${REDF}Error:${NC} ${RED}$prompt_text${NC}"
}

function echo_success() {
  local prompt_text=$1

  echo -e "${GREEN}$prompt_text${NC}"
}

function echo_warning() {
  local prompt_text=$1

  echo -e "${YELLOW}$prompt_text${NC}"
}

function echo_info() {
  local prompt_text=$1

  echo -e "${CYAN}$prompt_text${NC}"
}

function ask_with_yes_no() {
    local question="${1}"

    read -r -p "$(echo -e "${BORANGE}${question}${NC} (y/n)" ) " -n 1
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