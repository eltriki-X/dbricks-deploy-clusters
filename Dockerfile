FROM python:3.6

WORKDIR /usr/src/databricks-cli
COPY . .
RUN pip install --upgrade pip && \
    pip install --upgrade databricks-cli
#host = https://northeurope.azuredatabricks.net/?o=7257592137201481
#token = dapif937bba4dee1057491ce267ab70eaecb
ENV dbrick_wkspace website_dbricks
ENV dbrick_tokenpw token_password
ENV user userdbks
#external_metastore - variable
ENV sql_srv servidorsql
ENV sql_dbs bbddsql
ENV sqluser usuario
ENV sqlpass password
#User
RUN useradd -m -d /${user} ${user} 
RUN chown -hR ${user} /${user} 
RUN adduser ${user} sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
ADD databrickscfg /${user}/.databrickscfg
RUN chown -hR ${user} /usr/src/databricks-cli
WORKDIR /${user}

ENTRYPOINT [ "databricks" ]
