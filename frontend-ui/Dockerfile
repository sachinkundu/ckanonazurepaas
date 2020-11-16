FROM sachinkundu/ckan:v1

# Patch to make sure Azure Postgres works
RUN sed -i '269s/.*/          "sqlalchemy.url", str(self.metadata.bind.url).replace("%40","@")/' /usr/lib/ckan/venv/src/ckan/ckan/model/__init__.py

ADD ckan-entrypoint.sh /ckan-entrypoint.sh