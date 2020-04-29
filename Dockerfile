FROM ubuntu:20.04

################
### Preparing OS
################

ENV DEBIAN_FRONTEND noninteractive

# Install dependencies
RUN apt-get update && apt-get upgrade -y && apt-get clean -y
RUN  apt-get install --fix-missing -y && apt-get install -y \
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
        nano \
        wget

# Refresh Java CA certs
RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure

# Add the elasticsearch apt key
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -


####################
### ELK installation
####################

ENV ES_MAJOR_VERSION=7.x
ENV ES_VERSION=7.6.2

# Add the elasticsearch apt repo
RUN echo "deb https://artifacts.elastic.co/packages/${ES_MAJOR_VERSION}/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-${ES_MAJOR_VERSION}.list


# Install Elasticsearch
RUN apt-get update && apt-get install -y elasticsearch=${ES_VERSION}

# Install Kibana
RUN apt-get update && apt-get install -y kibana=${ES_VERSION}



#######################
### Install RoR Plugins
#######################
WORKDIR /usr/share/kibana
RUN bin/kibana-plugin --allow-root install "https://api.beshu.tech/download/trial?esVersion=${ES_VERSION}"

WORKDIR /usr/share/elasticsearch
RUN  bin/elasticsearch-plugin install -b "https://api.beshu.tech/download/es?esVersion=${ES_VERSION}"

# Configure Kibana
RUN echo \
"server.host: 0.0.0.0\n"\
"logging.json: false\n"\
"elasticsearch.username: kibana\n"\
"elasticsearch.password: kibana\n"\
"xpack.security.enabled: false\n"\
"readonlyrest_kbn.cookiePass: '12345678901234567890123456789012'\n"\
"readonlyrest_kbn.logLevel: 'debug'\n"\
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


# RoR configuration
RUN echo \
"readonlyrest:\n"\
"  prompt_for_basic_auth: false\n"\
"  audit_collector: true\n"\
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
"stdout_logfile=/dev/stdout\n"\
"stdout_logfile_maxbytes=0\n"\
"stderr_logfile=/var/log/supervisor/elasticsearch.err.log\n"\
> /etc/supervisor/conf.d/elasticsearch.conf


RUN echo \
"[program:kibana]\n"\
"user=kibana\n"\
"command=/usr/share/kibana/bin/kibana -p /var/run/kibana/kibana.pid\n"\
"autostart=true\n"\
"autorestart=true\n"\
"#environment=ES_HEAP_SIZE=2g\n"\
"stdout_logfile=/dev/stdout\n"\
"stdout_logfile_maxbytes=0\n"\
"stderr_logfile=/var/log/supervisor/kibana.err.log\n"\
> /etc/supervisor/conf.d/kibana.conf


RUN mkdir /var/run/elasticsearch &&  chown -R elasticsearch /var/run/elasticsearch

# Open Elasticsearch and Kibana ports
EXPOSE 9200 5601

# Run Supervisor
CMD supervisord -n -c /etc/supervisor/supervisord.conf
