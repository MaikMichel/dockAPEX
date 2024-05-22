# dockAPEX

**dockAPEX** is a tool for creating a complete APEX environment using docker-compose. The configuration is stored separately from the actual compose files. The complete stack consists of:
- Oracle Database
- Oracle APEX
- Oracle ORDS
- Apache Tomcat
- APEX Office Print (License Excludes)
- Traefic

Each component can also be omitted. This means that for a local development environment, you simply install the DB with APEX and ORDS and you're done.


## Configuration

**dockAPEX** uses two files. The actual configurations are stored in these. The *name*.env file stores which containers are to be started and which parameters are to be used. The *name*.sec file contains the passwords for the services. Although this file is created, it can also be omitted / deleted. It is sufficient if the respective variables exist when the containers are started.

### Create a config file

```bash
# create demo.env and demo.sec
$ .dockapex/dockapex.sh demo.env generate
```

### Update Config

It is sufficient to edit the settings in the *name*.env file. The individual sections of the file provide instructions for use.

### Update Secrets

It is sufficient to edit the settings in the *name*.sec file.

> Please add this file to the .gitignore. Security relevant information is stored here.

The secrets themselves are passed on to the containers via docker secrets.

## Update / Upgrade APEX

### Stop and Remove Containers

```bash
$ ./dockapex.sh demo.env down
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


### Rebuild

```bash
$ ./dockapex.sh demo.env up --build --force-recreate
```


## Debug / Orchestrate

### View logs

```bash
# follow mode
$ ./dockapex.sh demo.env logs -f

# just the logs
$ ./dockapex.sh demo.env logs

# logs of apex service
$ ./dockapex.sh demo.env logs apex
```

### show configuration
```bash
# list services
$ ./dockapex.sh demo.env config --services

# show config in yml
$ ./dockapex.sh demo.env config

# save config to file
$ ./dockapex.sh demo.env config --output demo.yml
```