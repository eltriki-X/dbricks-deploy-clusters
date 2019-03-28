FROM python:3.6

WORKDIR /usr/src/databricks-cli

COPY . .

RUN pip install --upgrade pip && \
    pip install databricks-cli

ENTRYPOINT [ "databricks" ]