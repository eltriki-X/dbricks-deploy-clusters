#!/bin/bash
# Description: Config Databricks CLI
#
set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace
# Set path
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"
env_file=$HOME"/.databrickscfg"
# Constants
RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'
wait_for_run () {
    # See here: https://docs.azuredatabricks.net/api/latest/jobs.html#jobsrunresultstate
    declare mount_run_id=$1
    while : ; do
        life_cycle_status=$(databricks runs get --run-id $mount_run_id | jq -r ".state.life_cycle_state") 
        result_state=$(databricks runs get --run-id $mount_run_id | jq -r ".state.result_state")
        if [[ $result_state == "SUCCESS" || $result_state == "SKIPPED" ]]; then
            break;
        elif [[ $life_cycle_status == "INTERNAL_ERROR" || $life_cycle_status == "FAILED" ]]; then
            state_message=$(databricks runs get --run-id $mount_run_id | jq -r ".state.state_message")
            echo -e "${RED}Error while running ${mount_run_id}: ${state_message} ${NC}"
            exit 1
        else 
            echo "Waiting for run ${mount_run_id} to finish..."
            sleep 2m
        fi
    done
}
cluster_exists () {
    declare cluster_name="$1"
    declare cluster=$(databricks clusters list | tr -s " " | cut -d" " -f2 | grep ^${cluster_name}$)
    if [[ -n $cluster ]]; then
        return 0; # cluster exists
    else
        return 1; # cluster does not exists
    fi
}
yes_or_no () {
    while true; do
        read -p "$(echo -e ${ORANGE}"$* [y/n]: "${NC})" yn
        case $yn in
            [Yy]*) return 0  ;;  
            [Nn]*) echo -e "${RED}Aborted${NC}" ; return  1 ;;
        esac
    done
}

_main() {
    # Create initial cluster, if not yet exists
    read -p "Nombre Cluster ETL: " CluName
    read -p "Numero de Workers : " num_wkrs
    read -p "Cluster Type (ETL/JOB):" CluType
    cluster_etl='{
        "autoscale": {
            "min_workers": 2,
            "max_workers": ${num_wkrs}
        },
        "cluster_name": "${CluName}",
        "spark_version": "5.3.x-scala2.11",
        "spark_conf": {
            "spark.databricks.cluster.profile": "serverless",
            "spark.databricks.repl.allowedLanguages": "python,sql",
            "spark.databricks.acl.dfAclsEnabled": "true",
            "spark.databricks.passthrough.enabled": "true",
            "spark.databricks.pyspark.enableProcessIsolation": "true"
        },
        "node_type_id": "Standard_DS13_v2",
        "driver_node_type_id": "Standard_DS4_v2",
        "ssh_public_keys": [],
        "custom_tags": {
            "ResourceClass": "Serverless",
             "Entorno": "Run Cluster ETL ${CluName} "
        },
        "cluster_log_conf": {
            "dbfs": {
                "destination": "dbfs:/cluster-logs"
            }
        },
        "spark_env_vars": {
            "PYSPARK_PYTHON": "/databricks/python3/bin/python3"
        },
        "autotermination_minutes": 120,
        "enable_elastic_disk": true,
        "init_scripts": []
    }'
    cluster_job='{
        "name": ${CluName},
            "new_cluster": {
                "spark_version": "5.2.x-scala2.11",
                "node_type_id": "Standard_DS3_v2",
                "num_workers": ${num_wkrs}
            },
        "libraries": [
            {
                "jar": "dbfs:/my-jar.jar"
            },
            {
                "whl": "dbfs:/my/whl"
            },
            {
                "pypi": {
                    "package": "simplejson=0.01",
                    "repo":  "https://nexus.librarias.local"
                    }
            }
        ],
        "timeout_seconds": 1200,
        "max_retries": 1,
        "schedule": {
                "quartz_cron_expression": "0 15 22 ? * *",
                "timezone_id": "Europe/Berlin"
        },
        "notebook_task": {
            "notebook_path": "/etl/config/librerias",
            "revision_timestamp": 0
        }
    }'
    CluType=${CluType^^}
    case $CluType in
        
    cluster_name=$cluster_name #$(cat $cluster_job | jq -r ".name")
    if cluster_exists $cluster_name; then 
        echo "Cluster ${cluster_name} already exists!"
    else
        echo "Creating cluster ${cluster_name}..."
        rjob=$(databricks runs submit --json $cluster_job)
        rjob_id=$(echo $rjob | jq .run_id)   
        until [ "$(echo $rjob | jq -r .state.life_cycle_state)" = "TERMINATED" ]; 
        do
            echo Waiting 
            for run completion...; 
                sleep 5; 
                rjob=$(databricks runs get --run-id $rjob_id); 
                echo $rjob | jq .run_page_url; 
        done
        echo $rjob |jq .
    fi
}
_main