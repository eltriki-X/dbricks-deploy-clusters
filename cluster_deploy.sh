#!/bin/bash
# Description: Deploy Databricks Cluster ETL/JOB
# 
# v1. First version script to automatic deploy of databricks cluster  
# v2. include autmation deploy cluster with "passthrough" feature.(Exploration option)
#
#####################################################################
#
#  SET shell Variables 
#

set +x
set -o errexit
set -o pipefail
set -o nounset
RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'
#
# Checking number of parameters that it needed the script, 7 at least.
#
if [ $# -eq 7 ]; then
        echo "Your command line contains $# arguments"
        cluster_name=${1//\"/}
        job_name=${2//\"/}
        spark_version=${3//\"/}
        node_type_id=${4//\"/}
        workers=${5//\"/}
        path_notebook=${6//\"/}
        nbook_params=${7//\"/}
else
        echo "Your command line not contains arguments"
        exit 1
fi
#
#
# Functions that we use in the  script.
##################################
# cluster_exists(): return 0/1 checking if the cluster name exists in the Databriks Workspace.
# cluster_state(): return 0/1 checking if cluster name is RUNNING 
# job_exists(): return 0/1 checking if the job name exists in the Databriks Workspace.
################################################################################################
cluster_exists () {
    declare cluname="$1"
    declare cluster=$(databricks clusters list | tr -s " " | cut -d" " -f2 | grep ^${cluname})
    if [[ -n $cluster ]]; then
        return 0; # cluster exists
    else
        return 1; # cluster does not exists
    fi
}
cluster_state () {
    declare cluid="$1"
    declare clu_state=$(databricks clusters list | tr -s " " | cut -d" " -f 1,3| grep RUNNING | grep ^${cluid})
    if [[ -z $clu_state ]]; then
        return 0; # cluster status Not RUNNING
    else
        return 1; # cluster status Is RUNNING 
    fi
}
job_exists () {
    declare jname="$1"
    declare job=$(databricks jobs list | tr -s " " | cut -d" " -f2 | grep ^${jname})
    #declare job=$(databricks jobs list | tr -s " " | cut -d" " -f2 | grep ^${jname})
    if [[ -n $job ]]; then
        return 0; # Jobs exists
    else    
        return 1; # Jobs does not exists
    fi
}
#
# Core of script.
#
_main() {
# Working with variables that we have in the environment.
# - delete double quotes in the data.
# - replace valor "null" for empty data.
######################################
    cluster_type=${cluster_type//\"/}
    project_name=${project_name//\"/}
    email_job_start=${email_job_start//\"/}
    if [ $email_job_start == "null" ]; then
        email_job_start=""
    fi
    email_job_success=${email_job_success//\"/}
    if [ $email_job_success == "null" ]; then
        email_job_success=""
    fi
    email_job_failure=${email_job_failure//\"/}
    if [ $email_job_failure == "null" ]; then
        email_job_failure=""
    fi
    rpypi_name=${rpypi_name//\"/}
    if [ $rpypi_name == "null" ]; then
        rpypi_name=""
    fi
    pypi_name=${pypi_name//\"/}
    pypi_repo=${pypi_repo//\"/}
    wheel_path=${wheel_path//\"/}
    jar_path=${jar_path//\"/}
#
# list of init-scripts that use into cluster deploy process.
######################################  
    adlcre="dbfs:/databricks/scripts/"$cluster_name"/adls_credentials.sh"
    remotelib="dbfs:/databricks/scripts/"$cluster_name"/xxxxxx_libraries.sh"
    jarsmetastore="dbfs:/databricks/scripts/"$cluster_name"/jars_metastore.sh"
#
# Checking type of cluster this data are load from "cluster_type" variable.
######################################
    cluster_type=${cluster_type^^}
    case $cluster_type in
        # EXPLORATION - Deploy Cluster into Exploration Databricks Workspace
        # * This option in the script generate a Cluster in Databricks Workspace wit "Passthrough" - Enabled
        #
        EXPLORATION)
            cluster_type=${cluster_type,,}
            cluster_exp=$(jq -n \
                        --arg cn "$cluster_name" \
                        --arg wk "$workers" \
                        --arg sv "$spark_version" \
                        --arg nt "$node_type_id" \
                        --arg ix2 "$remotelib" \
                        --arg ix3 "$jarsmetastore" \
                        '{
                                autoscale: {
                                    min_workers: 2,
                                    max_workers: $wk
                                },
                                cluster_name: $cn,
                                spark_version: $sv,
                                spark_conf: {
                                        "spark.databricks.repl.allowedLanguages": "python,sql",
                                        "spark.databricks.pyspark.enableProcessIsolation": "true",
                                        "spark.databricks.delta.preview.enabled": "true",
                                        "spark.databricks.acl.dfAclsEnabled": "true",
                                        "spark.databricks.passthrough.enabled": "true",
                                        "spark.databricks.cluster.profile": "serverless"
                                },
                                libraries: [],
                                node_type_id: $nt,
                                driver_node_type_id: $nt,
                                ssh_public_keys: [],
                                cluster_log_conf: {
                                    dbfs: { destination: "dbfs:/cluster-logs"  }
                                },
                                init_scripts: [
                                        { dbfs: {
                                                destination: $ix2 }
                                                },
                                        { dbfs: {
                                                destination: $ix3 }
                                                }
                                ],
                                spark_env_vars: {
                                    PYSPARK_PYTHON: "/databricks/python3/bin/python3"
                                },
                                enable_elastic_disk: true
                            }')
            rclu_exp=$(databricks clusters create --json "${cluster_exp}" | jq -r ".cluster_id")
            echo "OUTPUT SCRIPT: $rclu_exp "
            ;;
        # RUNS_SUBMIT - Deploy Job with "Runs Submit" feature, submit a one-timea run
        # * This option in the script just only generate a script in JSON for deploy with command databricks-cli
        #
        RUNS_SUBMIT)
            cluster_type=${cluster_type,,}
            cluster_rsub=$(jq -n \
                            --arg wk "$workers" \
                            --arg sv "$spark_version" \
                            --arg nt "$node_type_id" \
                            --arg pt "/"$cluster_type"/"$project_name"/"$path_notebook"" \
                            --arg ix1 "$adlcre" \
                            --arg ix2 "$remotelib" \
                            --arg ix3 "$jarsmetastore" \
                            '{
                                new_cluster: {             
                                    spark_version: $sv,
                                    node_type_id: $nt,
                                    num_workers: $wk,
                                    init_scripts: [
                                            { dbfs: {
                                                        destination: $ix1 }
                                            },
                                            { dbfs: {
                                                        destination: $ix2 }
                                            },
                                            { dbfs: {
                                                        destination: $ix3 }
                                            }
                                    ]   
                                },
                                libraries: [ ],
                                timeout_seconds: 1200,
                                max_retries: 1,
                                notebook_task: {
                                    notebook_path: $pt, 
                                    revision_timestamp: 0 },
                                notebook_params: { }
                            }')
            cluster_rsub
            #
            # Concatenate libraries that need install in cluster for type jar, wheel and pypi.
            add_libraries_rsb () {
                # add jar libraries
                IFS=', ' read -r -a array <<< "$jar_path"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do  #echo $element
                        cluster_rsub=$(jq '.libraries += [{"jar": "'$element'"}]' <<< "$cluster_rsub")
                    done
                fi
                # add wheel libraries
                IFS=', ' read -r -a array <<< "$wheel_path"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do #echo $element
                        cluster_rsub=$(jq '.libraries += [{"whl": "'$element'"}]' <<< "$cluster_rsub")
                    done
                fi
                # add pypi repository
                IFS=', ' read -r -a array <<< "$pypi_name"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do
                        cluster_rsub=$(jq '.libraries += [{"pypi": { "package": "'$element'", "repo": "'$pypi_repo'" }}]' <<< "$cluster_rsub")
                    done
                fi
                IFS=', ' read -r -a array <<< "$rpypi_name"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do
                        cluster_rsub=$(jq '.libraries += [{"pypi": { "package": "'$element'"}}]' <<< "$cluster_rsub")
                    done
                fi
            }
            if [ -z "${nbook_params}" ] || echo "null"; then
                    echo "Not parameters in job"
            else
                IFS=', ' read -r -a array <<< "$nbook_params"
                for element in "${array[@]}"
                do
                    cluster_rsub=$(jq '.notebook_params += {{"'$element'"}}' <<< "$cluster_rsub")
                done
            fi
            cluname=${cluster_name} #$(cat $cluster_job | jq -r ".name")
            if cluster_exists $cluname; then 
                echo "Cluster ${cluster_name} already exists!"
            else
                echo "Creating JOB Cluster (Runs-Submit)  ${cluster_name}..."
                rsjobcp=$(databricks workspace import_dir runs_submit /runs_submit/$project_name -o -e)
                echo "OUTPUT SCRIPT: ${rsjobcp}"
            fi
            ;;
        # JOB - Deploy Job Clusters in Databricks Workspace 
        # * This option in the script generate "job_id" after deploy in Databricks Workspace.
        #
        JOB)
            cluster_type=${cluster_type,,}
            rjobcp=$(databricks workspace import_dir job /job/$project_name -o -e)
            if job_exists $job_name; then
                echo "Job Name ${job_name} already exists in Databricks!"
                exit 1
            fi
            ctejob=$(jq -n \
                    --arg jn "$job_name" \
                    --arg cn "$cluster_name" \
                    --arg wk "$workers" \
                    --arg sv "$spark_version" \
                    --arg nt "$node_type_id" \
                    --arg pt "/"$cluster_type"/"$project_name"/"$path_notebook"" \
                    --arg ix1 "$adlcre" \
                    --arg ix2 "$remotelib" \
                    --arg ix3 "$jarsmetastore" \
                    --arg js "$email_job_start" \
                    --arg jc "$email_job_success" \
                    --arg jf "$email_job_failure" \
                '{
                        name: $jn,
                        new_cluster: {
                            autoscale: {
                                        min_workers: 2,
                                        max_workers: $wk
                            },
                            spark_version: $sv,
                            spark_conf: {
                                "spark.databricks.cluster.profile": "serverless",
                                "spark.databricks.delta.preview.enabled": "true",
                                "spark.databricks.repl.allowedLanguages": "python,sql",
                                "spark.databricks.acl.dfAclsEnabled": "true",
                                "spark.sql.sources.partitionOverwriteMode": "DYNAMIC"
                            },
                            libraries: [],
                            node_type_id: $nt,
                            driver_node_type_id: $nt,
                            ssh_public_keys: [],
                            cluster_log_conf: {
                                    dbfs: { destination: "dbfs:/cluster-logs"  }
                            },
                            init_scripts: [
                                            { dbfs: {
                                                        destination: $ix1 }
                                            },
                                            { dbfs: {
                                                        destination: $ix2 }
                                            },
                                            { dbfs: {
                                                        destination: $ix3 }
                                            }
                            ],
                            spark_env_vars: {
                            PYSPARK_PYTHON: "/databricks/python3/bin/python3"
                            },
                            enable_elastic_disk: true
                        },
                        email_notifications: {
                                on_start: [ $js ],
                                on_success: [ $jc ],
                                on_failure: [ $jf ] }, 
                        timeout_seconds: 0,
                        notebook_task: {
                            notebook_path:  $pt,
                            revision_timestamp: 0
                        },
                        notebook_params: {}
                    }')
            
            add_libraries_job () {
                # add jar libraries
                IFS=', ' read -r -a array <<< "$jar_path"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do  #echo $element
                        ctejob=$(jq '.libraries += [{"jar": "'$element'"}]' <<< "$ctejob")
                    done
                fi
                # add wheel libraries
                IFS=', ' read -r -a array <<< "$wheel_path"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do #echo $element
                        ctejob=$(jq '.libraries += [{"whl": "'$element'"}]' <<< "$ctejob")
                    done
                fi
                IFS=', ' read -r -a array <<< "$rpypi_name"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do
                        ctejob=$(jq '.libraries += [{"pypi": { "package": "'$element'"}}]' <<< "$ctejob")
                    done
                fi
            }
            add_libraries_job
            echo "Creating JOB:  ${job_name}.."
            if [ -z "${nbook_params}" ] || echo "null"; then
                echo "Not parameters in job"
            else
                IFS=', ' read -r -a array <<< "$nbook_params"
                for element in "${array[@]}"
                do
                    ctejob=$(jq '.notebook_params += {{"'$element'"}}' <<< "$ctejob")
                done
            fi
            run_job=$(databricks jobs create --json "${ctejob}")
            echo "OUTPUT SCRIPT: $run_job "
            ;;
        # ETL - Deploy Jobs and Clusters in Databricks Workspace
        # * This option in the script generate "job_id" and/or "cluster_id" - depend of option that used.
        # Generate cluster_id: When not include "job_name" variable in the cluster_type "ETL"
        # Generate cluster_id and job_id: when include both variables in the script run
        #
        ETL)
            cluster_type=${cluster_type,,}
            cluname=${cluster_name} #$(cat $cluster_job | jq -r ".name")
            add_libraries_etl () {
                # add jar libraries
                IFS=', ' read -r -a array <<< "$jar_path"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do  #echo $element
                        ctejob=$(jq '.libraries += [{"jar": "'$element'"}]' <<< "$ctejob")
                    done
                fi
                # add wheel libraries
                IFS=', ' read -r -a array <<< "$wheel_path"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do #echo $element
                        ctejob=$(jq '.libraries += [{"whl": "'$element'"}]' <<< "$ctejob")
                    done
                fi
                # add pypi repository
                IFS=', ' read -r -a array <<< "$rpypi_name"
                if [[ ${#array[@]} && ${array[0]} != "null" ]]; then 
                    for element in "${array[@]}"
                    do
                        ctejob=$(jq '.libraries += [{"pypi": { "package": "'$element'"}}]' <<< "$ctejob")
                    done
                fi
            }
            if cluster_exists $cluname; then
                rjob_id=$(databricks clusters list | tr -s " " | cut -d" " -f 1,2,3 | grep RUNNING | grep ${cluster_name} | cut -d" " -f1)
                echo $rjob_id
            else
                echo "Cluster ${cluster_name} NOT exists!"
                echo "Creating Cluster ${cluster_name}"
                clu_etl=$(jq -n \
                    --arg jn "$job_name" \
                    --arg cn "$cluster_name" \
                    --arg wk "$workers" \
                    --arg sv "$spark_version" \
                    --arg nt "$node_type_id" \
                    --arg ix1 "$adlcre" \
                    --arg ix2 "$remotelib" \
                    --arg ix3 "$jarsmetastore" \
                    --arg js "$email_job_start" \
                    --arg jc "$email_job_success" \
                    --arg jf "$email_job_failure" \
                '{
                        cluster_name: $cn,
                        autoscale: {
                                min_workers: 2,
                                max_workers: $wk
                        },
                        spark_version: $sv,
                        spark_conf: {
                                "spark.databricks.cluster.profile": "serverless",
                                "spark.databricks.delta.preview.enabled": "true",
                                "spark.databricks.repl.allowedLanguages": "python,sql",
                                "spark.databricks.acl.dfAclsEnabled": "true",
                                "spark.sql.sources.partitionOverwriteMode": "DYNAMIC"
                        },
                        node_type_id: $nt,
                        driver_node_type_id: $nt,
                        ssh_public_keys: [],
                        cluster_log_conf: {
                            dbfs: { destination: "dbfs:/cluster-logs"  }
                        },
                        init_scripts: [
                            { dbfs: {
                                    destination: $ix1 }
                                    },
                            { dbfs: {
                                    destination: $ix2 }
                                    },
                            { dbfs: {
                                    destination: $ix3 }
                                    }
                        ],
                        spark_env_vars: {
                            PYSPARK_PYTHON: "/databricks/python3/bin/python3"
                        },
                        autotermination_minutes: 0,
                        enable_elastic_disk: true                    
                    }')
                rclu_id=$(databricks clusters create --json "${clu_etl}" | jq -r ".cluster_id")
                echo $clu_id                
            fi
            if [ -z "${job_name}" ] || echo "null"; then
                echo "Just Deploy Cluster Databricks ETL "
            else
                ctejob=$(jq -n \
                        --arg jn "$job_name" \
                        --arg ri "$clu_id" \
                        --arg js "$email_job_start" \
                        --arg jc "$email_job_success" \
                        --arg jf "$email_job_failure" \
                        --arg pt /"$cluster_type"/"$project_name"/"$path_notebook" \
                    '{
                        name: $jn,                                                                          
                        existing_cluster_id: $ri,                                                 
                        email_notifications: {
                            on_start: [ $js ],
                            on_success: [ $jc ],
                            on_failure: [ $jf ] },                                                                     
                        timeout_seconds: 0,                                                                          
                        notebook_task: {                                                                             
                            notebook_path: $pt,   
                            revision_timestamp: 0 },
                        notebook_params: { }
                    }')
                add_libraries_etl
                if [ -z "${nbook_params}" ] || echo "null"; then
                    echo "Not parameters in etl"
                else
                    IFS=', ' read -r -a array <<< "$nbook_params"
                    for element in "${array[@]}"
                    do
                        ctejob=$(jq '.notebook_params += {{"'$element'"}}' <<< "$ctejob")
                    done
                fi
                retlcp=$(databricks workspace import_dir etl /etl/$project_name -o -e)
                run_etl=$(databricks jobs create --json "${ctejob}")
                echo "OUTPUT SCRIPT: $run_etl " 
            fi
            ;;
        default)
            echo "Please, Select : ETL/JOB/Runs_Submit/Exploration  :::::::::"
            ;;
    esac
}
_main
