FROM python:3.6

WORKDIR /usr/src/databricks-cli
COPY . .
RUN pip install --upgrade pip && \
    pip install --upgrade databricks-cli && \
    pip install --upgrade jq
#host  = https://northeurope.azuredatabricks.net/?o=8325656638655829
#token = dapi7729c02c9bf7589d772d9f797cbe7219
#Databricks Connection - variables
ENV dbrick_wkspace website_dbricks
ENV dbrick_tokenpw token_password
#external_metastore - variables
ENV sql_srv servidorsql
ENV sql_dbs bbddsql
ENV sqluser usuario
ENV sqlpass password
#Databricks Manage Cluster Jobs - variables
ENV nameetl etlname
ENV cluName nameclu
ENV num_wks wksnum
ENV clutype typeclu
ENV qzcrone expcron
#variables for ETL*****************
#email_notification:
ENV mlstart mailstart
ENV mlsuces mailsucess
ENV mlfailu mailfailure
#notebook_task:
ENV path_etl etlpath
#variables for JOB*****************
ENV namejob jobname
#libraries:
ENV pypi_name libname
ENV pypi_repo reponame
ENV whl_path pathwhl
ENV jar_path pathjar
#notebook_task:
ENV path_job jobpath 
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