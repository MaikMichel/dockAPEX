#!/usr/bin/env bats
# runs the real docker-compose config for the merged files (no containers started)

load ../helpers

setup_file() {
  command -v docker-compose >/dev/null || skip "docker-compose missing"
}

teardown() { teardown_env; }

@test "DB only" {
  make_env APEX=false ORDS=false
  run_dpex_real test.env config --quiet
  assert_success
}

@test "DB+APEX" {
  make_env ORDS=false
  run_dpex_real test.env config --quiet
  assert_success
}

@test "DB+APEX+ORDS" {
  make_env
  run_dpex_real test.env config --services
  assert_success
  assert_output --partial "database"
  assert_output --partial "apex"
  assert_output --partial "ords"
}

@test "DB+APEX+ORDS+TOMCAT" {
  make_env TOMCAT=true
  run_dpex_real test.env config --services
  assert_success
  assert_output --partial "tomcat"
}

@test "DB+APEX+ORDS+TRAEFIK" {
  make_env TRAEFIK=true
  run_dpex_real test.env config --services
  assert_success
  assert_output --partial "traefik"
}

@test "DB+APEX+ORDS+TOMCAT+TRAEFIK" {
  make_env TOMCAT=true TRAEFIK=true
  run_dpex_real test.env config --quiet
  assert_success
}

@test "DB+APEX+ORDS+MAILPIT" {
  make_env MAILPIT=true
  run_dpex_real test.env config --services
  assert_success
  assert_output --partial "mailpit"
}

@test "DB+APEX+ORDS+AOP" {
  make_env AOP=true
  run_dpex_real test.env config --services
  assert_success
  assert_output --partial "aop"
}

@test "all components" {
  make_env TOMCAT=true AOP=true MAILPIT=true TRAEFIK=true
  run_dpex_real test.env config --quiet
  assert_success
}

# external database: no local database service, no dependency on it
@test "APEX without DB (external database)" {
  make_env DB=false ORDS=false
  run_dpex_real test.env config
  assert_success
  refute_output --partial "db_store"
  refute_output --partial "database:"
}

@test "ORDS without DB (external database)" {
  make_env DB=false APEX=false
  run_dpex_real test.env config
  assert_success
  refute_output --partial "depends_on"
}

@test "APEX+ORDS+AOP+TOMCAT with external database" {
  make_env DB=false AOP=true TOMCAT=true
  run_dpex_real test.env config --services
  assert_success
  refute_output --partial "database"
}
