### Test execution databricks-cli 
```bash

docker run -e dbrick_wkspace=WEB_DBRICKS -e dbrick_tokenpw=ID_TOKEN_GENERADO_DBRICKS -it dbrickscli databricks fs ls

```

### Upload External Metastore Script
```bash

docker run -e dbrick_wkspace=WEB_DBRICKS -e dbrick_tokenpw=ID_TOKEN_GENERADO_DBRICKS -it dbrickscli databricks fs cp /userdbks/external_metastore.sh dbfs:/databricks/init/external_metastore.sh

```