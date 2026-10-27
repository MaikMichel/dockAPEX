#!/usr/bin/env bats

load ../helpers

teardown() { teardown_env; }

# flags-> expected -f files (relative to dock/)
check_files() {
  local expected="$1" f
  for f in $expected; do
    assert_output --partial "-f ./dock/${f} "
  done
  # no other compose file may be present
  local count
  count=$(grep -o -- '-f \./dock/[^ ]*' <<<"${lines[0]}" | wc -l | tr -d ' ')
  local want
  want=$(wc -w <<<"$expected" | tr -d ' ')
  [ "$count" -eq "$want" ]
}

@test "DB+APEX+ORDS selects base files and db/ords overlays" {
  make_env
  run_dpex test.env config
  assert_success
  check_files "database/docker_compose.yml apex/docker_compose.yml apex/docker_compose_db.yml apex/docker_compose_ords.yml ords/docker_compose.yml ords/docker_compose_db.yml"
}

@test "command and project name are passed to docker-compose" {
  make_env
  run_dpex test.env up --build --detach
  assert_success
  assert_output --partial "--project-name test"
  assert_output --partial "up --build --detach"
}

@test "TOMCAT adds tomcat base file" {
  make_env TOMCAT=true
  run_dpex test.env config
  assert_success
  assert_output --partial "-f ./dock/tomcat/docker_compose.yml "
}

@test "TRAEFIK with ORDS adds the ords traefik overlay" {
  make_env TRAEFIK=true
  run_dpex test.env config
  assert_success
  assert_output --partial "ords/docker_compose_traefik.yml"
  assert_output --partial "-f ./dock/traefik/docker_compose.yml "
}

@test "TRAEFIK with ORDS and TOMCAT only adds the tomcat traefik overlay" {
  make_env TRAEFIK=true TOMCAT=true
  run_dpex test.env config
  assert_success
  assert_output --partial "tomcat/docker_compose_traefik.yml"
  refute_output --partial "ords/docker_compose_traefik.yml"
}

@test "AOP adds db and ords overlays" {
  make_env AOP=true
  run_dpex test.env config
  assert_success
  assert_output --partial "aop/docker_compose.yml"
  assert_output --partial "aop/docker_compose_db.yml"
  assert_output --partial "aop/docker_compose_ords.yml"
}

@test "MAILPIT with TRAEFIK adds the mailpit traefik overlay" {
  make_env MAILPIT=true TRAEFIK=true
  run_dpex test.env config
  assert_success
  assert_output --partial "mailpit/docker_compose_traefik.yml"
}

@test "flag values other than 'true' are treated as off" {
  make_env ORDS=TRUE
  run_dpex test.env config
  assert_success
  refute_output --partial "ords/"
}

@test "ORDS_DDNS_PASSWORD is exported to compose even when the sec file lacks it" {
  make_env
  unset_var ORDS_DDNS_PASSWORD
  run_dpex test.env config
  assert_success
  assert_output --partial "STUB env ORDS_DDNS_PASSWORD="
  refute_output --partial "<unset>"
}

@test "a given ORDS_DDNS_PASSWORD is not overwritten" {
  make_env
  run_dpex test.env config
  assert_success
  assert_output --partial "ORDS_DDNS_PASSWORD=dummy-ddns"
}

@test "ports lists the host port of every enabled service" {
  make_env MAILPIT=true
  run_dpex test.env ports
  assert_success
  assert_output --partial "database   localhost:49153"
  assert_output --partial "ords       http://localhost:49153"
  assert_output --partial "mailpit    http://localhost:49153"
  refute_output --partial "tomcat"
}

@test "ports reports services that are not running" {
  make_env
  STUB_NO_PORTS=1 run_dpex test.env ports
  assert_success
  assert_output --partial "ords       not running"
}

@test "detached up shows the ports afterwards" {
  make_env
  run_dpex test.env up --build --detach
  assert_success
  assert_output --partial "STUB docker-compose --project-name test"
  assert_output --partial "ords       http://localhost:49153"
}

@test "up without detach does not show ports" {
  make_env
  run_dpex test.env up
  assert_success
  refute_output --partial "Host ports"
}

@test "empty port variables are valid" {
  make_env ORDS_PORT= TOMCAT_PORT= TOMCAT=true AOP=true AOP_PORT= MAILPIT=true MAILPIT_PORT=
  run_dpex test.env config
  assert_success
}

@test "TRAEFIK_EXTERNAL adds the traefik overlays but not the traefik service" {
  make_env TRAEFIK_EXTERNAL=true MAILPIT=true
  run_dpex test.env config
  assert_success
  assert_output --partial "ords/docker_compose_traefik.yml"
  assert_output --partial "mailpit/docker_compose_traefik.yml"
  refute_output --partial "traefik/docker_compose.yml"
}

@test "TRAEFIK and TRAEFIK_EXTERNAL exclude each other" {
  make_env TRAEFIK=true TRAEFIK_EXTERNAL=true
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "TRAEFIK_EXTERNAL"
}

@test "TRAEFIK_EXTERNAL requires TRAEFIK_DOMAIN" {
  make_env TRAEFIK_EXTERNAL=true TRAEFIK_DOMAIN=
  run_dpex test.env config
  assert_failure 2
  assert_output --partial "TRAEFIK_DOMAIN"
}

@test "up creates the shared proxy network when routed" {
  make_env TRAEFIK_EXTERNAL=true
  run_dpex test.env up --detach
  assert_success
  assert_output --partial "STUB docker network create dpex_proxy"
}

@test "up without routing does not touch docker networks" {
  make_env
  run_dpex test.env up --detach
  assert_success
  refute_output --partial "STUB docker network"
}

@test "ports shows the project subdomain when routed" {
  make_env TRAEFIK_EXTERNAL=true TRAEFIK_DOMAIN=example.org
  run_dpex test.env ports
  assert_success
  assert_output --partial "https://test.example.org/"
}

@test "ports of the traefik stack show the dashboard, not a project subdomain" {
  make_env DB=false APEX=false ORDS=false TRAEFIK=true TRAEFIK_DASHBOARD=true TRAEFIK_DOMAIN=example.org
  run_dpex test.env ports
  assert_success
  assert_output --partial "dashboard  https://example.org/traefik/"
  refute_output --partial "test.example.org"
}

# localhost domain: certificates from mkcert instead of Let's Encrypt
@test "TRAEFIK with a localhost domain adds the local certificate overlay" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=localhost
  run_dpex test.env config
  assert_success
  assert_output --partial "-f ./dock/traefik/docker_compose_localcert.yml "
}

@test "TRAEFIK with an external domain does not add the local certificate overlay" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=example.org
  run_dpex test.env config
  assert_success
  refute_output --partial "docker_compose_localcert.yml"
}

@test "a subdomain of localhost is a local domain, too" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=Dev.LOCALHOST
  run_dpex test.env config
  assert_success
  assert_output --partial "docker_compose_localcert.yml"
}

@test "a domain only ending like localhost is no local domain" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=notlocalhost.org
  run_dpex test.env config
  assert_success
  refute_output --partial "docker_compose_localcert.yml"
}

@test "up creates the certificates for traefik and the project subdomain" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=localhost
  run_dpex test.env up --detach
  assert_success
  assert_output --partial "STUB mkcert -install"
  assert_output --partial "local-key.pem localhost test.localhost"
  [ -f test.certs/local.pem ]
  [ -f test.certs/local-key.pem ]
  run grep -x "test.certs/" .gitignore
  assert_success
}

@test "up keeps existing certificates of the same names" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=localhost
  run_dpex test.env certs
  assert_success
  run_dpex test.env up --detach
  assert_success
  refute_output --partial "STUB mkcert"
}

@test "changed names create new certificates" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=localhost
  run_dpex test.env certs
  assert_success
  sed -i.bak 's/^TRAEFIK_DOMAIN=.*/TRAEFIK_DOMAIN="dev.localhost"/' test.env
  run_dpex test.env certs
  assert_success
  assert_output --partial "dev.localhost test.dev.localhost"
}

@test "an external domain needs no certificates on up" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=example.org
  run_dpex test.env up --detach
  assert_success
  refute_output --partial "STUB mkcert"
  [ ! -d test.certs ]
}

@test "missing mkcert exits 2 with install hints" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=localhost
  cd "${TEST_DIR}"
  # only the tools dpex.sh needs, so no mkcert of the host is found
  mkdir bin
  for t in bash dirname tr cat mkdir grep sed basename touch; do ln -s "$(command -v $t)" "bin/$t"; done
  PATH="${TEST_DIR}/bin" run bash dock/dpex.sh test.env certs
  assert_failure 2
  assert_output --partial "mkcert is required"
  assert_output --partial "brew install mkcert"
}

@test "certs without a localhost domain exits 2" {
  make_env TRAEFIK=true TRAEFIK_DOMAIN=example.org
  run_dpex test.env certs
  assert_failure 2
  assert_output --partial "localhost"
}

@test "ports of a routed mailpit show the /mailpit/ path" {
  make_env MAILPIT=true TRAEFIK_EXTERNAL=true TRAEFIK_DOMAIN=example.org
  run_dpex test.env ports
  assert_success
  assert_output --partial "https://test.example.org/mailpit/"
  assert_output --partial "http://localhost:49153/mailpit/"
}

@test "ports of a mailpit without traefik show the plain port" {
  make_env MAILPIT=true
  run_dpex test.env ports
  assert_success
  assert_output --partial "mailpit    http://localhost:49153"
  refute_output --partial "/mailpit/"
}
