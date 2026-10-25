# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

dockAPEX builds an Oracle APEX stack (DB, APEX, ORDS, Tomcat, APEX Office Print, Traefik) from docker-compose fragments. It is meant to be added as a git submodule (`.dockAPEX`) to a user's instance project; config lives in the instance project, not here. There is no build system, linter or test suite — the repo is bash scripts, Dockerfiles and compose YAML. (`demo.env`/`demo.sec` in the root are local sample configs; `*.sec` is gitignored.)

## Commands

All through `dpex.sh <name>.env <command>`; anything not `genfiles`/`clear` is passed straight to `docker-compose --project-name <name>` with the assembled `-f` list (the full command is echoed first).

```bash
./dpex.sh demo.env genfiles                      # create/refresh demo.env + demo.sec (existing ones are backed up to *.old)
./dpex.sh demo.env up --build --detach
./dpex.sh demo.env config --services             # inspect the merged compose result
./dpex.sh demo.env logs -f apex
./dpex.sh demo.env down apex
./dpex.sh demo.env clear [-f]                    # interactive teardown (volumes/images/prune); -f forces everything
```

## Architecture

**Compose composition (`dpex.sh`)**: the env file is sourced with `set -a`, then the `<name>.sec` file next to it. Boolean flags (`DB`, `APEX`, `ORDS`, `TOMCAT`, `AOP`, `TRAEFIK` = `true`) decide which compose files get layered. Each component dir has a base `docker_compose.yml` plus optional overlays named for the *other* component they couple to (`docker_compose_db.yml`, `_ords.yml`, `_traefik.yml`), which are added only when both flags are on. Note ORDS+Traefik overlay is skipped when Tomcat is also enabled (Tomcat then fronts ORDS and gets its own traefik overlay). When adding a component or coupling, update the `DCKAPX_COMP_FILES` logic and a `validate_*_params` function in `dpex.sh`. Compose files reference `${DCPAPX_PROJECT_NAME}` (derived from env file basename — note the `DCPAPX` spelling) and `${DCKAPX_CONF_FILE}`.

**Config/secrets flow**: `_template/_defaults.env` holds defaults; `_template/_template_env` and `_template_sec` are rendered by `genfiles` (via `render_template` in `_lib.sh`, or `envsubst` under zsh). In templates `§` stands for `$` so that `${VAR}` literals survive substitution (e.g. `§{APEX_VERSION}`). New settings must be added to both defaults and the template. Secrets (`DB_PASS`, `SMTP_PASSWORD`, `ORDS_PASSWORD`, `TRFK_USERPWD`, …) are exported from the `.sec` file and handed to containers as docker secrets (`environment:` source, mounted at `/run/secrets/*`), never as env vars.

**Containers read the same env file**: the env file is bind-mounted into containers as `/opt/oracle/config.env`; `scripts/entry_*.sh` sources it and reads passwords from `/run/secrets/*`. So entrypoints are where install/upgrade logic lives (APEX install against the DB via sqlplus, optional second PDB, SMTP config, ORDS setup, etc.). `entry_*.sh` duplicate the `output` logging helper from `_lib.sh` since they run in-container.

**Images**: tagged `<component>_<full_version>:<project>` and built from each component's `Dockerfile` with versions/URLs as build args from the env file. Upgrades = stop/remove container, `docker rmi` the image, change versions in env, `up --build` (see README). Healthchecks (e.g. APEX checks `apex_version.js` in the shared `apx_imgs` volume) gate dependent services; `apx_imgs` volume shares APEX static images between apex, ORDS and Tomcat.

`install.sh` bootstraps an instance project (git init + submodule add). `_documentation/Containers.png` shows the container topology.


## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

