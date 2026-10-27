#!/usr/bin/env bats

load ../helpers

setup() {
  local fn
  fn="$(sed -n '/^function config_force_https/,/^}/p' "${REPO_ROOT}/ords/scripts/entry_ords.sh")"
  output() { echo "$1 $2"; }
  eval "$fn"
  ORDS_CONF_DIR="$(mktemp -d)"
  mkdir "${ORDS_CONF_DIR}/global"
  SETTINGS="${ORDS_CONF_DIR}/global/settings.xml"
  cat > "${SETTINGS}" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<properties>
<entry key="database.api.enabled">true</entry>
</properties>
XML
  TRAEFIK=false
  TRAEFIK_EXTERNAL=false
}

teardown() { rm -rf "${ORDS_CONF_DIR}"; }

forced() { grep -c 'security.forceHTTPS' "${SETTINGS}"; }

@test "forceHTTPS is set behind TRAEFIK and the other settings stay" {
  TRAEFIK=true
  run config_force_https
  assert_success
  [ "$(forced)" -eq 1 ]
  grep -q 'database.api.enabled' "${SETTINGS}"
  [ "$(tail -n 1 "${SETTINGS}")" = "</properties>" ]
}

@test "forceHTTPS is set behind TRAEFIK_EXTERNAL" {
  TRAEFIK_EXTERNAL=true
  run config_force_https
  assert_success
  [ "$(forced)" -eq 1 ]
}

@test "forceHTTPS is not repeated on every start" {
  TRAEFIK=true
  config_force_https >/dev/null
  config_force_https >/dev/null
  [ "$(forced)" -eq 1 ]
}

@test "forceHTTPS is removed when the stack is not routed anymore" {
  TRAEFIK=true
  config_force_https >/dev/null
  TRAEFIK=false
  run config_force_https
  assert_success
  [ "$(forced)" -eq 0 ]
  grep -q 'database.api.enabled' "${SETTINGS}"
  [ "$(tail -n 1 "${SETTINGS}")" = "</properties>" ]
}

@test "a missing settings.xml is no error" {
  rm "${SETTINGS}"
  TRAEFIK=true
  run config_force_https
  assert_success
}
