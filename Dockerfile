FROM python:3.6-slim
WORKDIR /usr/src/databricks-cli
ARG VERSION=0.8.6
COPY . .
RUN apt-get update -y && \
    apt-get install curl -y
RUN pip install --upgrade pip && \
    pip install --upgrade databricks-cli
RUN curl -o /usr/local/bin/jq http://stedolan.github.io/jq/download/linux64/jq && \
    chmod +x /usr/local/bin/jq
RUN apt-get clean
#host  = https://northeurope.azuredatabricks.net/
#token = dapi7729c02c9bf7589d77
#Databricks Connection - variables

ENV dbrick_wkspace website_dbricks
ENV dbrick_tokenpw token_password
#external_metastore - variables
ENV sql_srv servidorsql
ENV sql_dbs bbddsql
ENV sqluser usuario
ENV sqlpass password
#Databricks Manage Cluster Jobs - variables
ENV job_name namejob
ENV cluster_name nameclu
ENV workers wksnum
ENV cluster_type typeclu
ENV quartz_cron expcron
ENV path pathjob_etl
#variables for ETL*****************
#email_notification:
ENV email_job_start mailstart
ENV email_job_success mailsucess
ENV email_job_failure mailfailure
#variables for JOB*****************
#libraries:
ENV pypi_name libname
ENV pypi_repo reponame
ENV wheel_path pathwhl
ENV jar_path pathjar
#variables for cluster-init-scripts
ENV azure_tenant_id=az_tenant_id
ENV usr_sp user_serviceprincipal
ENV pwd_sp pwd_serviceprincipal
#User
ENV user userdbks
RUN useradd -m -d /userdbks userdbks 
RUN chown -hR userdbks /userdbks 
RUN adduser userdbks sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
#Scripts
ADD databrickscfg /userdbks/.databrickscfg
ADD rep_env.sh /userdbks/rep_env.sh
ADD external_metastore.sh /userdbks/external_metastore.sh
ADD cluster_deploy.sh /userdbks/cluster_deploy.sh
RUN chown -hR userdbks /usr/src/databricks-cli
RUN chmod +x /userdbks/rep_env.sh
RUN chmod +x /userdbks/external_metastore.sh
RUN chmod +x /userdbks/cluster_deploy.sh
USER userdbks
WORKDIR /userdbks

ENTRYPOINT [ "/userdbks/rep_env.sh" ]
CMD ["databricks"]
