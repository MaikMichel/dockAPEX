#!/usr/bin/env bats
# runs the real docker-compose config for the merged files (no containers started)

load ../helpers

setup_file() {
  if ! command -v docker-compose >/dev/null; then
    [[ -n "${CI}" ]] && { echo "docker-compose missing" >&2; return 1; }
    skip "docker-compose missing"
  fi
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

# parallel stacks: no fixed container names, host ports are ranges or empty
@test "no fixed container names in the merged config" {
  make_env TOMCAT=true AOP=true MAILPIT=true TRAEFIK=true
  run_dpex_real test.env config
  assert_success
  refute_output --partial "container_name"
}

@test "default host ports are ranges" {
  make_env MAILPIT=true
  run_dpex_real test.env config
  assert_success
  assert_output --partial "published: 8080-8180"
  assert_output --partial "published: 1521-1599"
  assert_output --partial "published: 8025-8125"
}

@test "empty host port falls back to the range, a single port stays fixed" {
  make_env ORDS_PORT= DB_HOST_PORT=1600
  run_dpex_real test.env config
  assert_success
  assert_output --partial "published: 8080-8180"
  assert_output --partial 'published: "1600"'
}

# traefik routing: one traefik per host, every project is routed by its own subdomain
@test "routers and middlewares are prefixed with the project and use the project subdomain" {
  make_env TRAEFIK_EXTERNAL=true TRAEFIK_DOMAIN=example.org MAILPIT=true
  run_dpex_real test.env config
  assert_success
  assert_output --partial 'traefik.http.routers.test-ords.rule: Host(`test.example.org`)'
  assert_output --partial "traefik.http.middlewares.test-add-context.redirectregex"
  assert_output --partial "traefik.http.routers.test-mailpit.rule"
  assert_output --partial "name: dpex_proxy"
  refute_output --partial "traefik:"
}

@test "the project subdomain is DNS safe" {
  make_env TRAEFIK_EXTERNAL=true TRAEFIK_DOMAIN=example.org
  mv "${TEST_DIR}/test.env" "${TEST_DIR}/my_proj.env"
  mv "${TEST_DIR}/test.sec" "${TEST_DIR}/my_proj.sec"
  run_dpex_real my_proj.env config
  assert_success
  assert_output --partial 'Host(`my-proj.example.org`)'
}

@test "traefik service joins the shared network" {
  make_env TRAEFIK=true
  run_dpex_real test.env config
  assert_success
  assert_output --partial "--providers.docker.network=dpex_proxy"
  assert_output --partial "name: dpex_proxy"
}
