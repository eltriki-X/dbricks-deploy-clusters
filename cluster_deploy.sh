#!/bin/bash
# Description: Deploy Databricks Cluster ETL/JOB
#
set -o errexit
set -o pipefail
set -o nounset
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
job_exists () {
    declare jname="$1"
    declare job=$(databricks jobs list | tr -s " "| cut -d" " -f2|grep ^${name})
    if [[ -n $job ]]; then
        return 0; # Jobs exists
    else    
        return 1; # Jobs does not exists
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
add_libraries () {

    # add jar libraries
    IFS=', ' read -r -a array <<< "$jar_path"
    for element in "${array[@]}"
    do
        #echo $element
        cluster_job=$(jq '.libraries += [{"jar": "'$element'"}]' <<< "$cluster_job")
    done

    # add wheel libraries
    IFS=', ' read -r -a array <<< "$wheel_path"
    for element in "${array[@]}"
    do
        #echo $element
        cluster_job=$(jq '.libraries += [{"whl": "'$element'"}]' <<< "$cluster_job")
    done

    # add pypi libraries
    IFS=', ' read -r -a array <<< "$pypi_name"
    for element in "${array[@]}"
    do
        #echo $element
        cluster_job=$(jq '.libraries += [{"pypi": { "package": "'$element'"}}]' <<< "$cluster_job")
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

    # copy cluster-scoped script 
    databricks fs cp /tools/resources/databricks/adls_credentials.sh dbfs:/databricks/scripts/$cluster_name/adls_credentials.sh --overwrite
    databricks workspace import /tools/resources/databricks/notebook/arq/adlconnection.py /arq/adlconnection -o -l PYTHON
#JOB - Databricks

   cluster_job=$(jq -n \
                    --arg cn "$cluster_name" \
                    --arg wk "$workers" \
                    --arg jp "$jar_path" \
                    --arg wp "$wheel_path" \
                    --arg pn "$pypi_name" \
                    --arg pr "$pypi_repo" \
                    --arg qc "$quartz_cron" \
                    --arg pt /job/"$project_name"/"$path" \
                    '{
                        name: $cn,
                        new_cluster: {             
                            spark_version: "5.2.x-scala2.11",
                            node_type_id: "Standard_DS3_v2",
                            num_workers: $wk,
                            init_scripts: [ {
                                "dbfs": {
                                    "destination": "dbfs:/databricks/scripts/$cluster_name/adls_credentials.sh"
                                }
                            } ]
                        },
                        libraries: [ ],
                        timeout_seconds: 1200,
                        max_retries: 1,
                        schedule: {
                            quartz_cron_expression: $qc,
                            timezone_id: "Europe/Berlin" },
                        notebook_task: {
                            notebook_path: $pt, 
                            revision_timestamp: 0 }
                    }')
    # temporal: testing values !!!!
    #export jar_path=dbfs:/mnt/databricks/library.jar,dbfs:/mnt/databricks/library2.jar,dbfs:/mnt/databricks/library3.jar
    #export wheel_path=dbfs:/mnt/libraries/mlflow-0.0.1.dev0-py2-none-any.whl,dbfs:/mnt/libraries/wheel-libraries.wheelhouse.zip
    #export pypi_name=simplejson==3.8.0,numpy,pandas

    # add all jar libraries

add_libraries
#ETL - Databricks 
    cluster_etl=$(jq -n \
                    --arg cn "$cluster_name" \
                    --arg wk $workers \
                    '{
                        cluster_name: $cn,
                        autoscale: {
                            min_workers: 2,
                            max_workers: $wk },
                        spark_version: "5.3.x-scala2.11",
                        spark_conf: {
                            "spark.databricks.cluster.profile": "serverless",
                            "spark.databricks.repl.allowedLanguages": "python,sql",
                            "spark.databricks.acl.dfAclsEnabled": "true",
                            "spark.databricks.passthrough.enabled": "true",
                            "spark.databricks.pyspark.enableProcessIsolation": "true" },
                        node_type_id: "Standard_DS13_v2",
                        driver_node_type_id: "Standard_DS4_v2",
                        ssh_public_keys: [],
                        cluster_log_conf: {
                            dbfs: { destination: "dbfs:/cluster-logs" } },
                         init_scripts: [ {
                            "dbfs": {
                                "destination": "dbfs:/databricks/scripts/$cluster_name/adls_credentials.sh"
                            }
                        } ],
                        spark_env_vars: {
                            PYSPARK_PYTHON: "/databricks/python3/bin/python3" },
                        autotermination_minutes: 120,
                        enable_elastic_disk: true,
                        init_scripts: []
                    }')  
    cluster_type=${cluster_type^^}
    if job_exists $job_name; then
        echo "Job Name ${job_name} already exists in Databricks!"
        exit 1
    fi
    case $cluster_type in
    JOB)
        cluname=${cluster_name} #$(cat $cluster_job | jq -r ".name")
        if cluster_exists $cluname; then 
            echo "Cluster ${cluster_name} already exists!"
        else
            echo "Creating cluster ${cluster_name}..."
            rjobcp=$(databricks workspace import_dir job/$project_name /job/$project_name -o -e)
            echo "${rjobcp}"
            echo "Creating JOB:  ${job_name}.."
            rjob=$(databricks runs submit --json "${cluster_job}")
            echo "Id JOB run:  ${rjob}"
            rjob_id=$(echo ${rjob} | jq .run_id)   
            until [ "$(echo ${rjob} | jq -r .state.life_cycle_state)" = "TERMINATED" ]; 
            do
                echo "Waiting 5 minute for run completion..."; 
                sleep 5m; 
                rjob=$(databricks runs get --run-id ${rjob_id}); 
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
            retl_id=$(databricks clusters create --json "${cluster_etl}" | jq -r ".cluster_id")
            echo "${retl_id}"
            retlcp=$(databricks workspace import_dir etl/$project_name /etl/$project_name -o -e)
            echo "${retlcp}"
            #Ahora comprobamos que el cluster se ha levantado y lanzamos los notebooks sobre el cluster creado en el paso anterior..
            ctejob=$(jq -n \
                       --arg jn "$job_name" \
                       --arg ri "$retl_id" \
                       --arg js "$email_job_start" \
                       --arg jc "$email_job_success" \
                       --arg jf "$email_job_failure" \
                       --arg qc "$quartz_cron" \
                       --arg pt /etl/"$project_name"/"$path" \
                       '{
                            name: $jn,                                                                          
                            existing_cluster_id: $ri,                                                 
                            email_notifications: {
                                on_start: [ $js ],
                                on_success: [ $jc ],
                                on_failure: [ $jf ] },                                                                     
                            timeout_seconds: 0,                                                                          
                            schedule: {
                                quartz_cron_expression: $qc,                                                     
                                timezone_id: "Europe/Berlin" },                                                                                             
                            notebook_task: {                                                                             
                                notebook_path: $pt,   
                                revision_timestamp: 0 } 
                        }')
            echo "${ctejob}"
            run_etl=$(databricks jobs create --json "${ctejob}")
            echo $run_etl
	    fi
	    ;;
    default)
        echo "Please, Select : ETL/JOB "
        ;;
    esac
}
_main
