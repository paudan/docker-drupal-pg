FROM debian:jessie
MAINTAINER Paulius Danenas <danpaulius@gmail.com>
ENV DEBIAN_FRONTEND noninteractive
ENV DRUPAL_VERSION 8.3.2
ENV PG_VERSION 9.4

# Install packages.
RUN apt-get update
RUN apt-get install -y \
	nano \
	git \
	apache2 \
	php5-cli \
	php5-pgsql \
	php5-gd \
	php5-curl \
	php5-xdebug \
	php5-sqlite \
	libapache2-mod-php5 \
	curl \
	postgresql-$PG_VERSION \
	postgresql-client-$PG_VERSION \
	postgresql-contrib-$PG_VERSION \
	openssh-server \
	phppgadmin \
	wget \
	unzip \
	cron \
	supervisor
RUN apt-get clean

# Setup PHP.
RUN sed -i 's/display_errors = Off/display_errors = On/' /etc/php5/apache2/php.ini
RUN sed -i 's/display_errors = Off/display_errors = On/' /etc/php5/cli/php.ini

# Setup Blackfire.
# Get the sources and install the Debian packages.
# We create our own start script. If the environment variables are set, we
# simply start Blackfire in the foreground. If not, we create a dummy daemon
# script that simply loops indefinitely. This is to trick Supervisor into
# thinking the program is running and avoid unnecessary error messages.
RUN wget -O - https://packagecloud.io/gpg.key | apt-key add -
RUN echo "deb http://packages.blackfire.io/debian any main" > /etc/apt/sources.list.d/blackfire.list
RUN apt-get update
RUN apt-get install -y blackfire-agent blackfire-php
RUN echo '#!/bin/bash\n\
if [[ -z "$BLACKFIREIO_SERVER_ID" || -z "$BLACKFIREIO_SERVER_TOKEN" ]]; then\n\
    while true; do\n\
        sleep 1000\n\
    done\n\
else\n\
    /usr/bin/blackfire-agent -server-id="$BLACKFIREIO_SERVER_ID" -server-token="$BLACKFIREIO_SERVER_TOKEN"\n\
fi\n\
' > /usr/local/bin/launch-blackfire
RUN chmod +x /usr/local/bin/launch-blackfire
RUN mkdir -p /var/run/blackfire

# Setup Apache.
# In order to run our Simpletest tests, we need to make Apache
# listen on the same port as the one we forwarded. Because we use
# 8080 by default, we set it up for that port.
RUN sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
RUN sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www/' /etc/apache2/sites-available/000-default.conf
RUN sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www/' /etc/apache2/sites-available/default-ssl.conf
RUN echo "Listen 8080" >> /etc/apache2/ports.conf
RUN echo "Listen 8081" >> /etc/apache2/ports.conf
RUN echo "Listen 8443" >> /etc/apache2/ports.conf
RUN sed -i 's/VirtualHost \*:80/VirtualHost \*:\*/' /etc/apache2/sites-available/000-default.conf
RUN sed -i 's/VirtualHost __default__:443/VirtualHost _default_:443 _default_:8443/' /etc/apache2/sites-available/default-ssl.conf
RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2ensite default-ssl.conf

# Setup and patch phpPgAdmin
RUN a2enconf phppgadmin
ADD ./phppgadmin.conf /etc/apache2/conf-available/
ADD ./config.inc.php /usr/share/phppgadmin/conf/config.inc.php
ADD ./PluginManager.php /usr/share/phppgadmin/classes
RUN echo "listen_addresses = '*'" >> /etc/postgresql/$PG_VERSION/main/postgresql.conf
RUN sed -i 's/variables_order = "GPCS"/variables_order = "EGPCS"/g' /etc/php5/apache2/php.ini

# Start PostgreSQL
ENV PGUSER postgres
ENV PGDATA /usr/local/pgsql/data
RUN mkdir /usr/local/pgsql && \
    mkdir $PGDATA && \
    chmod a+w $PGDATA -R && \
    chown postgres $PGDATA && \
    su postgres -c "/usr/lib/postgresql/$PG_VERSION/bin/initdb -D /usr/local/pgsql/data" && \
    /etc/init.d/postgresql start && \
    su postgres -c "psql -U postgres -d postgres -c \"alter user postgres with password 'postgres';\"" && \
    su postgres -c "createuser -U postgres -d -e -E -l -P -r -s root"

# Setup SSH.
RUN echo 'root:root' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN mkdir /var/run/sshd && chmod 0755 /var/run/sshd
RUN mkdir -p /root/.ssh/ && touch /root/.ssh/authorized_keys
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Setup Supervisor.
RUN echo '[program:apache2]\ncommand=/bin/bash -c "source /etc/apache2/envvars && exec /usr/sbin/apache2 -DFOREGROUND"\nautorestart=true\n\n' >> /etc/supervisor/supervisord.conf
RUN echo '[program:postgresql]\ncommand=su postgres -c "/usr/lib/postgresql/9.4/bin/pg_ctl start -w"\n\n' >> /etc/supervisor/supervisord.conf
RUN echo '[program:sshd]\ncommand=/usr/sbin/sshd -D\n\n' >> /etc/supervisor/supervisord.conf
RUN echo '[program:blackfire]\ncommand=/usr/local/bin/launch-blackfire\n\n' >> /etc/supervisor/supervisord.conf
RUN echo '[program:cron]\ncommand=cron -f\nautorestart=false \n\n' >> /etc/supervisor/supervisord.conf

# Setup XDebug.
RUN echo "xdebug.max_nesting_level = 300" >> /etc/php5/apache2/conf.d/20-xdebug.ini
RUN echo "xdebug.max_nesting_level = 300" >> /etc/php5/cli/conf.d/20-xdebug.ini

# Install Composer.
RUN curl -sS https://getcomposer.org/installer | php
RUN mv composer.phar /usr/local/bin/composer

# Install Drush 8.
RUN composer global require drush/drush:8.*
RUN composer global update
# Unfortunately, adding the composer vendor dir to the PATH doesn't seem to work. So:
RUN ln -s /root/.composer/vendor/bin/drush /usr/local/bin/drush

# Install Drupal Console. There are no stable releases yet, so set the minimum
# stability to dev.
RUN curl https://drupalconsole.com/installer -L -o drupal.phar && \
	mv drupal.phar /usr/local/bin/drupal && \
	chmod +x /usr/local/bin/drupal
#RUN drupal init

# Install Drupal.
RUN rm -rf /var/www
RUN cd /var && \
	drush dl drupal-$DRUPAL_VERSION && \
	mv /var/drupal* /var/www
RUN mkdir -p /var/www/sites/default/files && \
	chmod a+w /var/www/sites/default -R && \
	mkdir /var/www/sites/all/modules/contrib -p && \
	mkdir /var/www/sites/all/modules/custom && \
	mkdir /var/www/sites/all/themes/contrib -p && \
	mkdir /var/www/sites/all/themes/custom && \
	cp /var/www/sites/default/default.settings.php /var/www/sites/default/settings.php && \
	cp /var/www/sites/default/default.services.yml /var/www/sites/default/services.yml && \
	chmod 0664 /var/www/sites/default/settings.php && \
	chmod 0664 /var/www/sites/default/services.yml
#RUN chown -R www-data:www-data /var/www/

RUN cd /var/www && \
    composer require drupal/console:~1.0 && \
    drupal init && \
    su postgres -c "/usr/lib/postgresql/$PG_VERSION/bin/pg_ctl start -w" && \
    su postgres -c "psql -c \"CREATE USER drupal WITH PASSWORD 'drupal';\"" && \
    su postgres -c "psql -c \"CREATE DATABASE drupal WITH ENCODING 'UTF8' TEMPLATE template0;\"" && \
    drush si -y standard --db-url=pgsql://postgres:postgres@127.0.0.1:5432/drupal --account-pass=admin && \
	drush dl admin_menu devel && \
	# In order to enable Simpletest, we need to download PHPUnit.
	composer install --dev && \
	# Admin Menu is broken. See https://www.drupal.org/node/2563867 for more info.
	# As long as it is not fixed, only enable simpletest and devel.
	# drush en -y admin_menu simpletest devel
	drush en -y simpletest devel && \
	drush en -y bartik
#RUN	drush cset system.theme default 'bartik' -y
# Allow Kernel and Browser tests to be run via PHPUnit.
RUN sed -i 's/name="SIMPLETEST_DB" value=""/name="SIMPLETEST_DB" value="sqlite:\/\/localhost\/tmp\/db.sqlite"/' /var/www/core/phpunit.xml.dist

EXPOSE 80 22 443 5432
CMD exec supervisord -n
