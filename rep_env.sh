#!/bin/bash
cd /userdbks
sed -i 's|dbrick_wkspace|'"$dbrick_wkspace"'|g' .databrickscfg
sed -i 's|dbrick_tokenpw|'"$dbrick_tokenpw"'|g' .databrickscfg
#REplace in external-metastore connection
sed -i 's|sql_srv|'"$sql_srv"'|g' external-metastore.sh
sed -i 's|sql_dbs|'"$sql_dbs"'|g' external-metastore.sh
sed -i 's|sqluser|'"$sqluser"'|g' external-metastore.sh
sed -i 's|sqlpass|'"$sqlpass"'|g' external-metastore.sh
exec "$@"