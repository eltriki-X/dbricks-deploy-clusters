# DATABRICKS DEPLOY CLUSTER BY bash script 

# NOTE:::::::::: If you have any issue with the code, please feel free to contact me....
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
#############################################################################################################################
### Deploy Cluster ETL/JOB Databricks
##Run Dockerfile
```bash
docker build -t dbricks_cludeploy -f Dockerfile .
```
##JOB Example
```bash
docker run \
-e cluster_name=ClusterJob01 \
-e job_name=JOB01 \
-e workers=4 \
-e cluster_type=job \
-e quartz_cron="0 * * * * ?" \
-e path=common/european_soccer_events_01_etl \
-e dbrick_wkspace=https://northeurope.azuredatabricks.net \
-e dbrick_tokenpw=dapi75bd392b463400ad183a3fd0 \
-it dbricks_cludeploy ./cluster_deploy.sh
```
##ETL Example
```bash
docker run \
-e cluster_name=ClusterEtl01 \
-e job_name=ETL01 \
-e workers=4 \
-e cluster_type=etl \
-e quartz_cron="0 * * * * ?" \
-e path=common/european_soccer_events_01_etl \
-e dbrick_wkspace=https://northeurope.azuredatabricks.net \
-e dbrick_tokenpw=da392b463400ad183a3fd0 \
-it dbricks_cludeploy ./cluster_deploy.sh
```
