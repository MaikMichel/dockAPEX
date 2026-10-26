# shared helpers for all bats tests

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

load "${REPO_ROOT}/tests/bats-support/load"
load "${REPO_ROOT}/tests/bats-assert/load"

# Creates a temp project dir with a symlink "dock" to the repo. dpex.sh builds
# its paths from dirname $0, so it has to be called with a relative path.
# Usage: make_env [VAR=value ...]  -> <tmp>/test.env and <tmp>/test.sec
make_env() {
  TEST_DIR="$(mktemp -d)"
  ln -s "${REPO_ROOT}" "${TEST_DIR}/dock"
  {
    cat "${REPO_ROOT}/_template/_defaults.env"
    echo
    echo 'DB=true'
    echo 'APEX=true'
    echo 'ORDS=true'
    echo 'APEX_FULL_VERSION=24.2.1'
    local kv
    for kv in "$@"; do
      echo "${kv%%=*}=\"${kv#*=}\""
    done
  } > "${TEST_DIR}/test.env"
  {
    echo 'DB_PASS="dummy-db"'
    echo 'ORDS_PASSWORD="dummy-ords"'
    echo 'SMTP_PASSWORD="dummy-smtp"'
    echo 'ORDS_DDNS_PASSWORD="dummy-ddns"'
    echo 'TRFK_USERPWD="user:dummyhash"'
  } > "${TEST_DIR}/test.sec"
}

# Removes a variable from the generated env/sec files (the later line wins otherwise)
unset_var() {
  local f
  for f in "${TEST_DIR}/test.env" "${TEST_DIR}/test.sec"; do
    grep -v "^$1=" "$f" > "$f.new"; mv "$f.new" "$f"
  done
}

# Runs dpex.sh with the stubbed docker-compose from inside the temp project
run_dpex() {
  cd "${TEST_DIR}" || return 1
  PATH="${REPO_ROOT}/tests/stubs:${PATH}" run bash dock/dpex.sh "$@"
  output="$(printf '%s' "$output" | sed $'s/\x1b\\[[0-9;]*m//g')"
}

# Runs dpex.sh with the real docker-compose
run_dpex_real() {
  cd "${TEST_DIR}" || return 1
  run bash dock/dpex.sh "$@"
  output="$(printf '%s' "$output" | sed $'s/\x1b\\[[0-9;]*m//g')"
}

teardown_env() {
  cd "${REPO_ROOT}" && rm -rf "${TEST_DIR}"
}
