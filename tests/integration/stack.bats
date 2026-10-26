#!/usr/bin/env bats
# Starts a real stack (DB, APEX, ORDS). Heavy: downloads images and APEX/ORDS.
# Run with: ./tests/run.sh integration   (sets DPEX_INTEGRATION=1)
# Timeout per service in seconds: DPEX_TIMEOUT (default 3600)

load ../helpers

PROJECT=dpextest

setup_file() {
  [[ "${DPEX_INTEGRATION}" == 1 ]] || skip "set DPEX_INTEGRATION=1"
  # the compose files use fixed container names and host ports; never touch a running stack
  local c busy=""
  for c in database apex ords tomcat aop mailpit traefik; do
    docker ps -a --format '{{.Names}}' | grep -qx "$c" && busy+=" $c"
  done
  [[ -z "$busy" ]] || { echo "container(s) already exist:$busy - stop that stack first" >&2; return 1; }
  cd "${REPO_ROOT}"
  # bind mounts need a path the docker VM can see (e.g. colima only shares $HOME)
  export TEST_DIR="$(mktemp -d "${REPO_ROOT}/tests/.tmp.XXXXXX")"
  ln -s "${REPO_ROOT}" "${TEST_DIR}/dock"
  {
    cat "${REPO_ROOT}/_template/_defaults.env"
    echo
    echo 'APEX_VERSION=26.2'
    echo 'APEX_FULL_VERSION=26.2.0'
    # derived values in _defaults.env were expanded with the default version already
    echo 'APEX_URL="https://download.oracle.com/otn_software/apex/apex_26.2_en.zip"'
    echo 'DB=true'
    echo 'APEX=true'
    echo 'ORDS=true'
    echo 'TOMCAT=false'
    echo 'MAILPIT=true'
    echo 'APEX_SMTP=true'
    echo 'APEX_SMTP_HOST_ADDRESS="mailpit"'
    echo 'APEX_SMTP_FROM="test@example.com"'
    echo 'APEX_SMTP_USERNAME="test"'
  } > "${TEST_DIR}/${PROJECT}.env"
  {
    echo 'DB_PASS="Test_Passw0rd_1"'
    echo 'ORDS_PASSWORD="Test_Passw0rd_1"'
    echo 'SMTP_PASSWORD="test"'
    echo 'ORDS_DDNS_PASSWORD="unused"'
  } > "${TEST_DIR}/${PROJECT}.sec"
  cd "${TEST_DIR}"
  if ! bash dock/dpex.sh "${PROJECT}.env" up --build --detach; then
    bash dock/dpex.sh "${PROJECT}.env" logs --tail 60 2>&1 | grep -v Downloading
    return 1
  fi
}

teardown_file() {
  [[ "${DPEX_INTEGRATION}" == 1 ]] || return 0
  cd "${TEST_DIR}" && bash dock/dpex.sh "${PROJECT}.env" down --volumes --rmi local
  # images built for this project carry the project name as tag
  docker images --filter "reference=*:${PROJECT}" -q | xargs docker rmi 2>/dev/null
  cd "${REPO_ROOT}" && rm -rf "${TEST_DIR}"
}

dpex() { (cd "${TEST_DIR}" && bash dock/dpex.sh "${PROJECT}.env" "$@"); }

# prints the container id of a compose service (last line, the first one is the echoed command)
cid() { dpex ps -q "$1" | tail -n 1; }

wait_healthy() {
  local svc="$1" end=$((SECONDS + ${DPEX_TIMEOUT:-3600})) id status
  while (( SECONDS < end )); do
    id="$(cid "$svc")"
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$id" 2>/dev/null)"
    [[ "$status" == healthy || "$status" == running ]] && return 0
    if [[ "$status" == exited ]]; then
      # the apex container may end by itself after a successful install
      [[ "$svc" == apex && "$(docker inspect --format '{{.State.ExitCode}}' "$id")" == 0 ]] && return 0
      echo "$svc exited"; dpex logs "$svc" | tail -n 30; return 1
    fi
    sleep 10
  done
  echo "$svc not healthy in time"
  return 1
}

@test "database becomes healthy" { wait_healthy database; }
@test "apex installs and becomes healthy" { wait_healthy apex; }
@test "ords becomes healthy" { wait_healthy ords; }
@test "mailpit becomes healthy" { wait_healthy mailpit; }

@test "ords answers over HTTP" {
  run curl -s -o /dev/null -w '%{http_code}' --retry 10 --retry-delay 5 --retry-connrefused "http://localhost:${ORDS_PORT:-8080}/ords/"
  assert_output --regexp '^(200|301|302)$'
}

@test "apex static images are served by ords" {
  run curl -s -o /dev/null -w '%{http_code}' "http://localhost:${ORDS_PORT:-8080}/i/apex_version.js"
  assert_output "200"
}

@test "ords container reaches the database" {
  run docker exec "$(cid ords)" bash -c 'exec 3<>/dev/tcp/database/1521'
  assert_success
}

@test "apex container reaches mailpit smtp" {
  run docker exec "$(cid apex)" bash -c 'exec 3<>/dev/tcp/mailpit/25'
  assert_success
}

@test "mailpit web ui answers" {
  run curl -s -o /dev/null -w '%{http_code}' "http://localhost:${MAILPIT_PORT:-8025}/"
  assert_output "200"
}
