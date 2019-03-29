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
    echo -e "${ORANGE}"
    echo -e "########   Configure Cluster in Databricks WorkSpace ########."
    echo -e "${NC}"
    echo -e "${ORANGE}"
    echo "Configure your databricks cli to connect to the newly created Databricks workspace:.."
    databricks configure --token
    echo -e "${NC}"

    #####################
    # Append to .env file
    echo "Retrieving configuration information from newly deployed resources."
    # Databricks details
    dbricks_location=$(awk '/host/ && NR==2 {print $0;exit;}' ~/.databrickscfg | cut -b 16-100 | cut -d '.'  -f1)
    dbi_token=$(awk '/token/ && NR==3 {print $0;exit;}' ~/.databrickscfg | cut -d' ' -f3)
    [[ -n $dbi_token ]] || { echo >&2 "Databricks cli not configured correctly. Please run databricks configure --token. Aborting."; exit 1; }

    # Configure New Cluster 
    yes_or_no "Are you sure you want to continue (Y/N)?" || { exit 1; }

    # Create initial cluster, if not yet exists
    cluster_config="/deploy/databricks/01_cluster/cluster.config.json"
    cluster_name=$(cat $cluster_config | jq -r ".cluster_name")
    if cluster_exists $cluster_name; then 
        echo "Cluster ${cluster_name} already exists!"
    else
        echo "Creating cluster ${cluster_name}..."
        databricks clusters create --json-file $cluster_config
    fi
}
_main