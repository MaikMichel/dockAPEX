#!/usr/bin/env bats

load ../helpers

setup() {
  source "${REPO_ROOT}/_lib.sh"
  TMP="$(mktemp -d)"
}

teardown() { rm -rf "${TMP}"; }

@test "render_template replaces \$VAR and \${VAR}" {
  printf 'a=$FOO b=${FOO}\n' > "${TMP}/t"
  FOO=bar render_template "${TMP}/t" "${TMP}/o"
  run cat "${TMP}/o"
  assert_output "a=bar b=bar"
}

@test "render_template turns unset variables into empty strings" {
  printf 'a=${NOPE_UNSET}x\n' > "${TMP}/t"
  render_template "${TMP}/t" "${TMP}/o"
  run cat "${TMP}/o"
  assert_output "a=x"
}

@test "write_line_if_not_exists appends only once" {
  : > "${TMP}/f"
  write_line_if_not_exists "hello" "${TMP}/f"
  write_line_if_not_exists "hello" "${TMP}/f"
  run grep -c '^hello$' "${TMP}/f"
  assert_output "1"
}

@test "check_params exits 2 for an empty variable" {
  run bash -c "source '${REPO_ROOT}/_lib.sh'; A=1; B=; check_params A B"
  assert_failure 2
}

@test "check_params passes when all variables are set" {
  run bash -c "source '${REPO_ROOT}/_lib.sh'; A=1; B=2; check_params A B"
  assert_success
}

@test "check_secret exits 2 for an empty secret" {
  run bash -c "source '${REPO_ROOT}/_lib.sh'; S=; check_secret S"
  assert_failure 2
}

@test "ask_with_yes_no accepts y and rejects n" {
  run bash -c "source '${REPO_ROOT}/_lib.sh'; ask_with_yes_no 'q' <<<y"
  assert_success
  run bash -c "source '${REPO_ROOT}/_lib.sh'; ask_with_yes_no 'q' <<<n"
  assert_failure
}
