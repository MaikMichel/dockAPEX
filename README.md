# dockAPEX

**dockAPEX** is a tool for creating a complete APEX environment using docker-compose. The configuration is stored separately from the actual compose files. The complete stack consists of:
- Oracle Database
- Oracle APEX
- Oracle ORDS
- Apache Tomcat
- APEX Office Print
- Traefic

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
