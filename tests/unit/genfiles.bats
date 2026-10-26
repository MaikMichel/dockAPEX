#!/usr/bin/env bats

load ../helpers

setup() {
  TEST_DIR="$(mktemp -d)"
  ln -s "${REPO_ROOT}" "${TEST_DIR}/dock"
  cd "${TEST_DIR}"
}

teardown() { teardown_env; }

gen() { run bash dock/dpex.sh demo.env genfiles; }

@test "genfiles creates env and sec" {
  gen
  assert_success
  [ -f demo.env ]
  [ -f demo.sec ]
}

@test "sec file is only accessible by the owner" {
  gen
  run stat -f '%Lp' demo.sec 2>/dev/null || run stat -c '%a' demo.sec
  assert_output "600"
}

@test "sec file is added to .gitignore once" {
  gen
  bash dock/dpex.sh demo.env genfiles >/dev/null
  run grep -c '^demo.sec$' .gitignore
  assert_output "1"
}

@test "existing files are backed up" {
  gen
  echo 'MARKER=1' >> demo.env
  bash dock/dpex.sh demo.env genfiles >/dev/null
  run grep -c 'MARKER=1' demo.env.old
  assert_output "1"
}

@test "generated env has no template header and no section sign" {
  gen
  run grep -c '§' demo.env
  assert_output "0"
}

@test "generated env can be used by dpex.sh" {
  gen
  echo 'DB_PASS="x"' >> demo.sec
  echo 'ORDS_PASSWORD="x"' >> demo.sec
  PATH="${REPO_ROOT}/tests/stubs:${PATH}" run bash dock/dpex.sh demo.env config
  assert_success
}

@test "generated env keeps existing values" {
  gen
  sed -i.bak 's/^APEX_SPACE_NAME=.*/APEX_SPACE_NAME="KEEPME"/' demo.env
  bash dock/dpex.sh demo.env genfiles >/dev/null
  run grep '^APEX_SPACE_NAME=' demo.env
  assert_output 'APEX_SPACE_NAME="KEEPME"'
}

@test "every variable of the defaults is part of the template" {
  local v missing=""
  for v in $(grep -oE '^[A-Z_0-9]+=' "${REPO_ROOT}/_template/_defaults.env" | tr -d '='); do
    grep -qE "^${v}=" "${REPO_ROOT}/_template/_template_env" || missing+=" $v"
  done
  [ -z "$missing" ] || { echo "missing in _template_env:$missing"; return 1; }
}
