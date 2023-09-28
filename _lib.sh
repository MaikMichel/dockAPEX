#!/bin/bash

LIBSOURCED="TRUE"

# Reset
NC="\033[0m"       # Text Reset

# Regular Colors
RED="\033[0;31m"
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

  echo -e "${RED}$prompt_text${NC}"
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