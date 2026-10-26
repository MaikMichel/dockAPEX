#!/usr/bin/env bats

load ../helpers

@test "wallet installation is skipped for an external database" {
  local fn
  fn="$(sed -n '/^function install_wallets/,/^}/p' "${REPO_ROOT}/apex/scripts/entry_apex.sh")"
  output() { echo "$1 $2"; }
  eval "$fn"
  DB=false
  run install_wallets
  assert_success
  assert_output --partial "skipping wallet installation"
}
