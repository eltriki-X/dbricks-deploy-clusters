FROM python:3.6

WORKDIR /usr/src/databricks-cli
COPY . .
RUN pip install --upgrade pip && \
    pip install --upgrade databricks-cli
#host = https://northeurope.azuredatabricks.net/?o=7257592137201481
#token = dapi35899fd8d2d6b278ff29c4647f372373
ENV dbrick_wkspace website_dbricks
ENV dbrick_tokenpw token_password
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
RUN chown -hR userdbks /usr/src/databricks-cli
RUN chmod +x /userdbks/rep_env.sh
RUN chmod +x /userdbks/external_metastore.sh
USER userdbks
WORKDIR /userdbks

ENTRYPOINT [ "/userdbks/rep_env.sh" ]
CMD ["databricks"]