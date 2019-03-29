#!/bin/bash
cd /userdbks
sed -i 's|dbrick_wkspace|'"$dbrick_wkspace"'|g' .databrickscfg
sed -i 's|dbrick_tokenpw|'"$dbrick_tokenpw"'|g' .databrickscfg
#REplace in external-metastore connection
sed -i 's|sql_srv|'"$sql_srv"'|g' external_metastore.sh
sed -i 's|sql_dbs|'"$sql_dbs"'|g' external_metastore.sh
sed -i 's|sqluser|'"$sqluser"'|g' external_metastore.sh
sed -i 's|sqlpass|'"$sqlpass"'|g' external_metastore.sh
exec "$@"