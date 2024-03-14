# dockAPEX


## Update / Upgrade APEX

### Stop and Remove Containers

```bash
dockapex demo.env down
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
dockapex demo.env up --build --force-recreate
```
