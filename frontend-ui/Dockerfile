FROM sachinkundu/ckan:v1
# Prepare for hosting CKAN in container with uswgi, supervisor, and nginx cache
# based on https://docs.ckan.org/en/2.9/maintaining/installing/deployment.html
USER root

#TODO: Freeze package versions????
RUN apt-get update && \
    apt-get install nginx supervisor libcap2-bin -y

## uwsgi configuration 
RUN chown -R ckan:ckan /etc/ckan
RUN cp /usr/lib/ckan/venv/src/ckan/ckan-uwsgi.ini /etc/supervisor/conf.d/ckan-uwsgi.ini 
#replace python virtualenv location
RUN sed -i 's/etc\/ckan\/default/etc\/ckan/g'  /etc/supervisor/conf.d/ckan-uwsgi.ini 
RUN sed -i 's/usr\/lib\/ckan\/default/usr\/lib\/ckan\/venv/g'  /etc/supervisor/conf.d/ckan-uwsgi.ini 
#remove uid, guid lines as uswgi will run in the executing users name
RUN sed -i '4,5d' /etc/supervisor/conf.d/ckan-uwsgi.ini
# Patch to make sure Azure Postgres works
RUN sed -i '269s/.*/          "sqlalchemy.url", str(self.metadata.bind.url).replace("%40","@")/' /usr/lib/ckan/venv/src/ckan/ckan/model/__init__.py


## NGINX 
# Add site to nginx
ADD ckan-nginx.conf /etc/nginx/sites-available/ckan.conf
RUN ln -s /etc/nginx/sites-available/ckan.conf /etc/nginx/sites-enabled/ckan.conf
# Remove default site to prevent collisions
RUN rm /etc/nginx/sites-enabled/default
# Grant permissions required by nginx to ckan
RUN mkdir /var/cache/nginx
RUN chown -R ckan:ckan /var/cache/nginx && \
    chown -R ckan:ckan /var/log/nginx && \
    chown -R ckan:ckan /etc/nginx && \
    chown -R ckan:ckan /var/lib/nginx  && \
    touch /var/run/nginx.pid && \
    chown -R ckan:ckan /var/run/nginx.pid 
# Remove user from nginx config, as it is ignored when not running as root account
RUN sed -i 's/user www-data;//g'  /etc/nginx/nginx.conf
# Allow nginx to bind to low ports as non-root
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx


## Supervisord
# remove [unix_http_server] section because unix sockets dont work in ACI 
RUN sed -i '18,20d' /etc/supervisor/supervisord.conf
RUN sed -i '3,6d' /etc/supervisor/supervisord.conf
ADD ckan-uwsgi.conf  /etc/supervisor/conf.d/ckan-uwsgi.conf
RUN touch /var/run/supervisord.pid && \
    chown -R ckan:ckan /var/run/supervisord.pid  && \
    chown -R ckan:ckan /etc/supervisor/supervisord.conf 

RUN mkdir /var/run/supervisor
RUN chown -R ckan:ckan /var/log/supervisor && \
    chown -R ckan:ckan /var/run/supervisor 

# Add entry point and startup cmd scripts
ADD ckan-entrypoint.sh /ckan-entrypoint.sh
ADD start-services.sh /start-services.sh
RUN chown -R ckan:ckan /start-services.sh && \
    chmod u+x /start-services.sh	
USER ckan

# TODO: Freeze package versions????
## CKAN Python virtualenv, uwsgi
RUN . /usr/lib/ckan/venv/bin/activate && pip install uwsgi

EXPOSE 80
CMD ["/start-services.sh"]