#!/bin/bash

MY_PORT=${1}
curl --fail -s http://localhost:${MY_PORT}/ords/ || exit 1