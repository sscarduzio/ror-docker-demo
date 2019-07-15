FROM ubuntu:19.04

ENV ES_MAJOR_VERSION=7.x
ENV ES_VERSION=7.2.0
ENV ROR_VERSION=1.18.2
ENV DEBIAN_FRONTEND noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
        apt-transport-https \
        apt-utils \
        ca-certificates \
        curl \
        gnupg \
        less \
        net-tools \
        openjdk-8-jre-headless \
        supervisor \
        vim \
        wget

# Refresh Java CA certs
RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure

# Add the elasticsearch apt key
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -

# Add the elasticsearch apt repo
RUN echo "deb https://artifacts.elastic.co/packages/${ES_MAJOR_VERSION}/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-${ES_MAJOR_VERSION}.list

# Install Elasticsearch
RUN apt-get update && apt-get install -y elasticsearch=${ES_VERSION}

# Install Kibana
RUN apt-get update && apt-get install -y kibana=${ES_VERSION}

# Install filebeat
RUN apt-get install -y filebeat=${ES_VERSION}

# Install rsyslog
RUN apt-get install -y rsyslog

# Enable filebeat modules
RUN filebeat modules list | sed -n '1,/Disabled:/!p' | xargs filebeat modules enable


# Install RoR Plugins

RUN echo "ror version is: ${ROR_VERSION}"
RUN /usr/share/kibana/bin/kibana-plugin  --allow-root install "https://m0ppfybs81.execute-api.eu-west-1.amazonaws.com/dev/download/trial?esVersion=${ES_VERSION}&pluginVersion=${ROR_VERSION}"
RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install -b "https://m0ppfybs81.execute-api.eu-west-1.amazonaws.com/dev/download/es?esVersion=${ES_VERSION}&pluginVersion=${ROR_VERSION}"

# Configure Kibana
RUN echo \
"server.host: 0.0.0.0\n"\
"elasticsearch.username: kibana\n"\
"elasticsearch.password: kibana\n"\
"xpack.security.enabled: false\n"\
"readonlyrest_kbn.cookiePass: '12345678901234567890123456789012'\n"\
> /etc/kibana/kibana.yml

RUN /usr/share/kibana/bin/kibana --allow-root --optimize 

# Speed up the optimisation
RUN touch /usr/share/kibana/optimize/bundles/readonlyrest_kbn.style.css

# Configure Elasticsearch
RUN echo \
"node.name: n1_it\n"\
"cluster.initial_master_nodes: n1_it\n"\
"cluster.name: es-all-in-one\n"\
"path.data: /var/lib/elasticsearch\n"\
"path.logs: /var/log/elasticsearch\n"\
"network.host: _local_,_site_\n"\
"xpack.security.enabled: false\n"\
> /etc/elasticsearch/elasticsearch.yml

# Configure Filebeat
RUN echo \
"filebeat.inputs:\n"\
"- type: log\n"\
"  enabled: false\n"\
"  paths:\n"\
"    - /var/log/*.log\n"\
"filebeat.config.modules:\n"\
"  path: \${path.config}/modules.d/*.yml\n"\
"  reload.enabled: false\n"\
"setup.template.settings:\n"\
"  index.number_of_shards: 3\n"\
"setup.kibana:\n"\
"  host: localhost:5601\n"\
"  username: kibana\n"\
"  password: kibana\n"\
"output.elasticsearch:\n"\
"  hosts: ['localhost:9200']\n"\
"  username: kibana\n"\
"  password: kibana\n"\
"processors:\n"\
"  - add_host_metadata: ~\n"\
"  - add_cloud_metadata: ~\n"\
> /etc/filebeat/filebeat.yml

# RoR configuration
RUN echo \
"readonlyrest:\n"\
"  prompt_for_basic_auth: false\n"\
"  access_control_rules:\n"\
"   - name: KIBANA_SERVER\n"\
"     auth_key: kibana:kibana\n"\
"     verbosity: error\n"\
"\n"\
"   - name: PERSONAL_GRP\n"\
"     groups: [ Personal ]\n"\
"     kibana_access: rw\n"\
"     kibana_hide_apps: [readonlyrest_kbn, timelion]\n"\
"     kibana_index: '.kibana_@{user}'\n"\
"     verbosity: error\n"\
"\n"\
"   - name: ADMIN_GRP\n"\
"     groups: [Administrators]\n"\
"     kibana_access: admin\n"\
"     verbosity: error\n"\
"\n"\
"   - name: Infosec\n"\
"     groups: [ Infosec ]\n"\
"     kibana_access: rw\n"\
"     kibana_hide_apps: [ readonlyrest_kbn, timelion]\n"\
"     kibana_index: .kibana_infosec\n"\
"     verbosity: error\n"\
"\n"\
"  # USERS TO GROUPS ############\n"\
"  users:\n"\
"  - username: admin\n"\
"    auth_key: admin:passwd\n"\
"    groups: [Administrators, Infosec]\n"\
"\n"\
"  - username: user1\n"\
"    auth_key: user1:passwd\n"\
"    groups: [Administrators, Personal, Infosec]\n"\
 > /etc/elasticsearch/readonlyrest.yml

# Copy the supervisord initscripts
RUN echo \
"[program:elasticsearch]\n"\
"user=elasticsearch\n"\
"command=/usr/share/elasticsearch/bin/elasticsearch -p /var/run/elasticsearch/elasticsearch.pid\n"\
"autostart=true\n"\
"autorestart=true\n"\
"environment=ES_HEAP_SIZE=2g\n"\
"stdout_logfile=/var/log/supervisor/elasticsearch.out.log\n"\
"stderr_logfile=/var/log/supervisor/elasticsearch.err.log\n"\
> /etc/supervisor/conf.d/elasticsearch.conf


RUN echo \
"[program:kibana]\n"\
"user=kibana\n"\
"command=/usr/share/kibana/bin/kibana -p /var/run/kibana/kibana.pid\n"\
"autostart=true\n"\
"autorestart=true\n"\
"#environment=ES_HEAP_SIZE=2g\n"\
"stdout_logfile=/var/log/supervisor/kibana.out.log\n"\
"stderr_logfile=/var/log/supervisor/kibana.err.log\n"\
> /etc/supervisor/conf.d/kibana.conf


RUN echo \
"[program:filebeat]\n"\
"user=root\n"\
"command=/usr/share/filebeat/bin/filebeat\n"\
"	-c /etc/filebeat/filebeat.yml\n"\
"	-path.home /usr/share/filebeat\n"\
"	-path.config /etc/filebeat\n"\
"	-path.data /var/lib/filebeat\n"\
"	-path.logs /var/log/filebeat\n"\
"autostart=true\n"\
"autorestart=false\n"\
"stdout_logfile=/var/log/supervisor/filebeat.out.log\n"\
"stderr_logfile=/var/log/supervisor/filebeat.err.log\n"\
> /etc/supervisor/conf.d/filebeat.conf

RUN echo \
"[program:rsyslog]\n"\
"user=root\n"\
"command=/usr/sbin/rsyslogd -n\n"\
"autostart=true\n"\
"autorestart=true\n"\
"stdout_logfile=/var/log/supervisor/rsyslog.out.log\n"\
"stderr_logfile=/var/log/supervisor/rsyslog.err.log\n"\
> /etc/supervisor/conf.d/rsyslog.conf


RUN mkdir /var/run/elasticsearch &&  chown -R elasticsearch /var/run/elasticsearch

# Open Elasticsearch and Kibana ports
EXPOSE 9200 5601

# Run Supervisor
CMD supervisord -n -c /etc/supervisor/supervisord.conf
