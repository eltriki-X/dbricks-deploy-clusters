#!/bin/bash
# Description: Config Databricks CLI
#
set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace
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
    declare cluname="$1"
    declare cluster=$(databricks clusters list | tr -s " " | cut -d" " -f2 | grep ^${cluname}$)
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
#Job execute manual
    #read -p "Nombre Cluster ETL: " cluster_name
    #read -p "Numero de Workers : " workers
    #read -p "Cluster Type (ETL/JOB):" cluster_type
    #read -p "NameJob: " job_name
    #read -p "HoraDespliegue: " quartz_cron
    #read -p "Path Job: " path
#JOB - Databricks
   cluster_job=$( jq -n \
                     --arg cn "$cluster_name" \
                     --arg wk "$workers" \
                     --arg jp "$jar_path" \
                     --arg wp "$wheel_path" \
                     --arg pn "$pypi_name" \
                     --arg pr "$pypi_repo" \
                     --arg qc "$quartz_cron" \
                     --arg pt /job/"$path" \
                    '{
                    name: $cn,
                    new_cluster: {             
                        spark_version: "5.2.x-scala2.11",
                        node_type_id: "Standard_DS3_v2",
                        num_workers: $wk
                    },
                    libraries: [
                    { jar: $jp },
                    { whl: $wp },
                    { pypi: {
                            package: $pn,
                            repo: $pr } } ],
                    timeout_seconds: 1200,
                    max_retries: 1,
                    schedule: {
                        quartz_cron_expression: $qc,
                        timezone_id: "Europe/Berlin"
                    },
                    notebook_task: {
                        notebook_path: $pt, 
                        revision_timestamp: 0 }
                    }')
#ETL - Databricks 
     cluster_etl=$( jq -n \
                     --arg cn "$cluster_name" \
                     --arg wk "$workers" \
                    '{
                    autoscale: {
                        min_workers: 2,
                        max_workers": $wk },
                    cluster_name: $cn,
                    spark_version: "5.3.x-scala2.11",
                    spark_conf: {
                        spark.databricks.cluster.profile: "serverless",
                        spark.databricks.repl.allowedLanguages: "python,sql",
                        spark.databricks.acl.dfAclsEnabled: "true",
                        spark.databricks.passthrough.enabled: "true",
                        spark.databricks.pyspark.enableProcessIsolation: "true" },
                    node_type_id: "Standard_DS13_v2",
                    driver_node_type_id: "Standard_DS4_v2",
                    ssh_public_keys: [],
                    cluster_log_conf: {
                        dbfs: { destination: "dbfs:/cluster-logs" } },
                    spark_env_vars: {
                        PYSPARK_PYTHON: "/databricks/python3/bin/python3" },
                    autotermination_minutes: 120,
                    enable_elastic_disk: true,
                    init_scripts: []
                    }')  
    cluster_type=${cluster_type^^}
    case $cluster_type in
    JOB)
        cluname=${cluster_name} #$(cat $cluster_job | jq -r ".name")
        if cluster_exists $cluname; then 
            echo "Cluster $cluster_name already exists!"
        else
            echo "Creating cluster ${cluster_name}..."
            rjobcp=$(databricks fs cp ./job dbfs:/job --overwrite --recursive)
            rjob=$(databricks runs submit --json $cluster_job)
            rjob_id=$(echo $rjob | jq .run_id)   
            until [ "$(echo $rjob | jq -r .state.life_cycle_state)" = "TERMINATED" ]; 
            do
                echo "Waiting for run completion..."; 
                sleep 5; 
                rjob=$(databricks runs get --run-id $rjob_id); 
                echo $rjob | jq .run_page_url; 
            done
            echo $rjob |jq .
        fi
        ;;
    ETL)
        cluname=${cluster_name} #$(cat $cluster_job | jq -r ".name")
        if cluster_exists $cluname; then 
            echo "Cluster ${cluster_name} already exists!"
        else
            echo "Creating cluster ${cluster_name}..."
            retl=$(databricks clusters create --json $cluster_etl | jq -r ".cluster_id")
            retl_id=$(databricks fs cp ./etl dbfs:/etl --overwrite)
            #Ahora comprobamos que el cluster se ha levantado y lanzamos los notebooks sobre el cluster creado en el paso anterior..
            ctejob='{"name": "${job_name}",                                                                          
                     "existing_cluster_id": "${retl_id}",                                                 
                     "email_notifications": {
                                "on_start": [${email_job_start}],
                                "on_success": [${email_job_success}],
                                "on_failure": [${email_job_failure}]
                    },                                                                     
                     "timeout_seconds": 0,                                                                          
                     "schedule": {                                                                                  
                     "quartz_cron_expression": ${quartz_cron},                                                     
                     "timezone_id": "Europe/Berlin"                                                               
                     },                                                                                             
                     "notebook_task": {                                                                             
                            "notebook_path": "/etl/${path}",   
                            "revision_timestamp": 0}
                    }'
            run_etl=$(databricks jobs create --json ${ctejob})
	fi
	;;
    default)
        echo "Please, Select : ETL/JOB "
        ;;
    esac
}
_main
