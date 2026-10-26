# dockAPEX

**dockAPEX** is a tool for creating a complete APEX environment using docker-compose. The configuration is stored separately from the actual compose files. The complete stack consists of:
- Oracle Database
- Oracle APEX
- Oracle ORDS
- Apache Tomcat
- APEX Office Print
- Traefic
- Mailpit (development mail sink with web UI)

Each component can also be omitted. This means that for a local development environment, you simply install the DB with APEX and ORDS and you're done. Furthermore, you can import / run a new version of a component only by removing the respective container and replacing it with the new version.

## Preparation

Before you are able to use dockAPEX, you have to make sure that you have the following components installed:
* git
* docker
* docker-compose

## Installation

### Automatic

Just run:

```bash
# creates the instancefolder, makes it a git repo and adds dockAPEX as submodul
$ curl -sS https://raw.githubusercontent.com/MaikMichel/dockAPEX/main/install.sh | bash -s <instance-project-folder>
```

or inside a git folder belonging to your instance / project:
```bash
$ curl -sS https://raw.githubusercontent.com/MaikMichel/dockAPEX/main/install.sh
```

### Manual

```bash
# create a folder belonging to your project
$ mkdir -p demo

# change into it
$ cd demo

# make the folder a git project / repo
$ git init

# clone dockAPEX as submodule"
$ git submodule add https://github.com/MaikMichel/dockAPEX.git .dockAPEX
```



## Configuration

**dockAPEX** uses two files. The actual configurations are stored in these. The *name*.env file stores which containers are to be started and which parameters are to be used. The *name*.sec file contains the passwords for the services. Although this file is created, it can also be omitted / deleted. It is sufficient if the respective variables exist when the containers are started.

### Create a config file

```bash
# create demo.env and demo.sec
$ .dockapex/dpex.sh demo.env genfiles
```

### Update Config

It is sufficient to edit the settings in the *name*.env file. The individual sections of the file provide instructions for use.

### Update Secrets

It is sufficient to edit the settings in the *name*.sec file.

> Please add this file to the .gitignore. Security relevant information is stored here.

The secrets themselves are passed on to the containers via docker secrets.

## Development mail server (Mailpit)

Set `MAILPIT=true` in your env file to catch all mails sent by APEX / the database. The web UI is available on `http://localhost:<port>` (see `ports`, default range 8025-8125), or on `https://<project>.<TRAEFIK_DOMAIN>/mailpit` when Traefik is enabled (protected by the Traefik dashboard login). To send mails to it, configure:

```bash
# demo.env
APEX_SMTP=true
APEX_SMTP_HOST_ADDRESS=mailpit
APEX_SMTP_FROM=apex@localhost
APEX_SMTP_USERNAME=apex

# demo.sec (any value is accepted by Mailpit)
SMTP_PASSWORD=dev
```

## Host ports / parallel stacks

Containers have no fixed names; docker-compose names them `<project>-<service>-1`, so several env files can run side by side. The host ports are set per service (`DB_HOST_PORT`, `ORDS_PORT`, `TOMCAT_PORT`, `AOP_PORT`, `MAILPIT_PORT`) and can be

- a range (default, e.g. `ORDS_PORT="8080-8180"`): docker takes the first free port of the range
- a single port (`ORDS_PORT="8080"`): fixed, a second stack on the same port fails
- empty: falls back to the default range

`DB_PORT` is only the port inside the network (the services connect to `DB_HOST:DB_PORT`) and stays `1521`. A detached `up` prints the assigned ports; show them any time with:

```bash
./dpex.sh demo.env ports
```

Docker assigns the port when the container starts, so it can change after a stop / start.

### Traefik: one proxy, many projects

With Traefik every project is routed by its own subdomain: `https://<project>.<TRAEFIK_DOMAIN>/` (the project is the env file name, `_` becomes `-`). Locally `TRAEFIK_DOMAIN="localhost"` works, browsers resolve `<project>.localhost` without DNS. For real domains every subdomain needs a DNS record (or a wildcard record), Let's Encrypt needs ports 80 / 443.

Only one Traefik can bind 80 / 443 per host. Run it in its own env file and let the other stacks use it:

```bash
# traefik.env:  TRAEFIK=true          (no DB / APEX / ORDS)
# proj1.env:    TRAEFIK_EXTERNAL=true (plus TRAEFIK_DOMAIN and TRAEFIK_DEFAULT_ROUTE, same domain as traefik.env)
./dpex.sh traefik.env up --detach
./dpex.sh proj1.env up --detach       # https://proj1.<TRAEFIK_DOMAIN>/
./dpex.sh proj2.env up --detach       # https://proj2.<TRAEFIK_DOMAIN>/
```

`TRAEFIK=true` together with ORDS / Tomcat in one env file still works (single stack). Both flags are exclusive. The stacks talk through the docker network `dpex_proxy`, which `up` creates when missing. The Traefik dashboard stays on `https://<TRAEFIK_DOMAIN>/traefik`.

**Note:** existing Traefik setups are now reached on `https://<project>.<TRAEFIK_DOMAIN>/` instead of `https://<TRAEFIK_DOMAIN>/`; this needs a DNS record (and certificate) for the subdomain.

## Update / Upgrade APEX

### Stop and Remove Container and Image

```bash
# stop and remove apex service
$ .dockAPEX/dpex.sh demo.env down apex

# remove apex image (apex_(APEX_FULL_VERSION):demo)
$ docker rmi apex_24.2.3:demo
```

### Update Konfiguration

To update APEX without patchset you have to set the Version `APEX_VERSION` to the new one.

```bash
# demo.env
APEX_VERSION=23.2
APEX_FULL_VERSION=23.2.0
APEX_PSET_URL=
```

To update APEX with a patchset you have to set the full version and the url to the patchset itself.

```bash
# demo.env
APEX_VERSION=23.2
APEX_FULL_VERSION=23.2.4
APEX_PSET_URL="https://your-private-object-bucket-or-url/p35895964_2320_Generic.zip"
```

> Upgrading the other containers / components works the same
> - Stop, Remove Containers, Images
> - Modify configurations
> - Rebuild Image, Start Container
>
> **Remember: This is just docker under the hood**


### Rebuild

```bash
$ .dockapex/dpex.sh demo.env up --build --force-recreate --detach
```


## Debug / Orchestrate

### View current processes

```bash
$ .dockapex/dpex.sh demo.env ps -a
```

### View logs

```bash
# follow mode
$ .dockapex/dpex.sh demo.env logs -f

# just the logs
$ .dockapex/dpex.sh demo.env logs

# logs of apex service
$ .dockapex/dpex.sh demo.env logs apex
```

### show configuration
```bash
# list services
$ .dockapex/dpex.sh demo.env config --services

# show config in yml
$ .dockapex/dpex.sh demo.env config

# save config to file
$ .dockapex/dpex.sh demo.env config --output demo.yml
```

# Credits
Dockerfiles are based on and with the influence of:
- https://github.com/araczkowski/docker-oracle-apex-ords

Some inspirations are coming from:
- https://github.com/Dani3lSun/docker-db-apex-dev

## Tests

The tests use [bats-core](https://github.com/bats-core/bats-core), included as git submodules in `tests/`.

```bash
git submodule update --init
./tests/run.sh unit          # dpex.sh with a stubbed docker-compose, _lib.sh, genfiles
./tests/run.sh config        # real `docker-compose config` for the flag combinations (no containers)
./tests/run.sh lint          # shellcheck, hadolint, yamllint (those installed)
./tests/run.sh integration   # starts a real stack, slow
./tests/run.sh               # unit + config
```
