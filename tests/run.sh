#!/bin/bash
# Usage: ./tests/run.sh [unit|config|lint|integration|all]
cd "$(dirname "$0")/.." || exit 1

BATS=tests/bats/bin/bats
if [[ ! -x "$BATS" ]]; then
  echo "bats missing, run: git submodule update --init" >&2
  exit 1
fi

lint() {
  local rc=0 t
  for t in shellcheck hadolint yamllint; do
    if ! command -v "$t" >/dev/null; then
      echo "lint: $t not installed" >&2
      [[ -n "$CI" ]] && rc=1
    fi
  done
  command -v shellcheck >/dev/null && { shellcheck -S warning dpex.sh _lib.sh install.sh */scripts/*.sh || rc=1; }
  command -v hadolint >/dev/null && { hadolint --failure-threshold error */Dockerfile || rc=1; }
  command -v yamllint >/dev/null && { yamllint -c .yamllint */docker_compose*.yml || rc=1; }
  return $rc
}

case "${1:-all}" in
  lint)        lint ;;
  unit)        "$BATS" tests/unit ;;
  config)      "$BATS" tests/config ;;
  integration) DPEX_INTEGRATION=1 "$BATS" tests/integration ;;
  all)         "$BATS" tests/unit tests/config ;;
  *) echo "unknown suite: $1" >&2; exit 1 ;;
esac
