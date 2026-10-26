#!/usr/bin/env bats

load ../helpers

teardown() { teardown_env; }

@test "fewer than two arguments exit 1" {
  make_env
  run_dpex test.env
  assert_failure 1
  assert_output --partial "Missing arguments"
}

@test "missing config file exits 1" {
  make_env
  run_dpex nope.env config
  assert_failure 1
  assert_output --partial "Missing configuration file"
}

@test "valid default configuration passes" {
  make_env
  run_dpex test.env config
  assert_success
}

@test "missing DB_PASS exits 2" {
  make_env
  unset_var DB_PASS
  run_dpex test.env config
  assert_failure 2
}

@test "missing DB_HOST exits 2" {
  make_env DB_HOST=
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "DB_HOST"
}

@test "missing APEX_URL exits 2" {
  make_env APEX_URL=
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "APEX_URL"
}

@test "APEX_SMTP without SMTP_PASSWORD exits 2" {
  make_env APEX_SMTP=true APEX_SMTP_HOST_ADDRESS=mailpit APEX_SMTP_FROM=a@b.c APEX_SMTP_USERNAME=u
  unset_var SMTP_PASSWORD
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "SMTP_PASSWORD"
}

@test "APEX_SECND_PDB requires pdb parameters" {
  make_env APEX_SECND_PDB=true APEX_SECND_PDB_NAME=
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "APEX_SECND_PDB_NAME"
}

@test "missing ORDS_PASSWORD exits 2" {
  make_env
  unset_var ORDS_PASSWORD
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "ORDS_PASSWORD"
}

@test "ORDS_DDNS requires user, url and password" {
  make_env ORDS_DDNS=true ORDS_DDNS_USER= ORDS_DDNS_URL=
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "ORDS_DDNS_USER"
}

@test "APEX_CREATE_TSPACE requires APEX_CREATE_TSPACE_PATH" {
  make_env APEX_CREATE_TSPACE=true APEX_CREATE_TSPACE_PATH=
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "APEX_CREATE_TSPACE_PATH"
}

@test "TRAEFIK without TRFK_USERPWD exits 2" {
  make_env TRAEFIK=true
  unset_var TRFK_USERPWD
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "TRFK_USERPWD"
}

@test "TRAEFIK without TRAEFIK_DOMAIN exits 2" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "TRAEFIK_DOMAIN"
}
