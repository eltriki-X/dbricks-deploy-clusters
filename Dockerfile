FROM python:3.6

WORKDIR /usr/src/databricks-cli
COPY . .
RUN pip install --upgrade pip && \
    pip install --upgrade databricks-cli
#host  = https://northeurope.azuredatabricks.net/?o=8325656638655829
#token = dapi7729c02c9bf7589d772d9f797cbe7219
ENV dbrick_wkspace website_dbricks
ENV dbrick_tokenpw token_password
ENV dbrick_etl_name cluster_etl_name
ENV user userdbks
#external_metastore - variable
ENV sql_srv servidorsql
ENV sql_dbs bbddsql
ENV sqluser usuario
ENV sqlpass password
#User
RUN useradd -m -d /userdbks userdbks 
RUN chown -hR userdbks /userdbks 
RUN adduser userdbks sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
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