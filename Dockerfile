FROM ubuntu:18.04

ENV ES_MAJOR_VERSION=6.x
ENV ES_VERSION=6.7.1
ENV ROR_VERSION=1.17.6
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

# Install the ingest-geoip plugin for elasticsearch
#RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch ingest-geoip

# Install the ingest-user-agent plugin for elasticsearch
#RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch ingest-user-agent

# Install Kibana
RUN apt-get update && apt-get install -y kibana=${ES_VERSION}

# Install filebeat
RUN apt-get install -y filebeat=${ES_VERSION}

# Install rsyslog
RUN apt-get install -y rsyslog

# Enable filebeat modules
RUN filebeat modules list | sed -n '1,/Disabled:/!p' | xargs filebeat modules enable

# Configure Elasticsearch
COPY config/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml

# Configure Kibana
COPY config/kibana/kibana.yml /etc/kibana/kibana.yml

# Configure Filebeat
COPY config/filebeat/filebeat.yml /etc/filebeat/filebeat.yml

# Copy the RoR packages
COPY pkg/ /pkg

# Copy the RoR configuration
COPY config/elasticsearch/readonlyrest.yml /etc/elasticsearch/readonlyrest.yml

# Install RoR Plugins
RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install -b file:///pkg/readonlyrest-${ROR_VERSION}_es${ES_VERSION}.zip
RUN /usr/share/kibana/bin/kibana-plugin install --quiet --no-optimize file:///pkg/readonlyrest_kbn_enterprise-${ROR_VERSION}_es${ES_VERSION}.zip

# Speed up the optimisation
RUN touch /usr/share/kibana/optimize/bundles/readonlyrest_kbn.style.css

# Copy the supervisord initscripts
COPY supervisord/ /etc/supervisor/conf.d/

# Open Elasticsearch and Kibana ports
EXPOSE 9200 5601

# Run Supervisor
CMD supervisord -n -c /etc/supervisor/supervisord.conf
