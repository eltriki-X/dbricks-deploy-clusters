### Test execution databricks-cli 
```bash

docker run \
  -e dbrick_wkspace=WEB_DBRICKS \
  -e dbrick_tokenpw=ID_TOKEN_GENERADO_DBRICKS \
  -it dbrickscli databricks fs ls

```

### Upload External Metastore Script
```bash

docker run \
  -e sql_srv=MI_SERVIDOR_SQL \
  -e sql_dbs=MI_BBDD_SQL \
  -e sqluser=MI_USUARIO_SQL \
  -e sqlpass=MI_PASSWORD \
  -e dbrick_wkspace=WEB_DBRICKS \
  -e dbrick_tokenpw=ID_TOKEN_GENERADO_DBRICKS \
  -it dbrickscli databricks fs cp /userdbks/external_metastore.sh dbfs:/databricks/init/external_metastore.sh --overwrite
```